extends Node
# Autoload: SupabaseSyncManager
# Pushes local dirty SQLite rows to Supabase's PostgREST API.

signal sync_started
signal sync_finished(success: bool)
signal sync_failed(message: String)

const SUPABASE_URL_SETTING := "tako/supabase/url"
const SUPABASE_ANON_KEY_SETTING := "tako/supabase/anon_key"
const SUPABASE_ACCESS_TOKEN_SETTING := "tako/supabase/access_token"
const CONNECTIVITY_URL_SETTING := "tako/supabase/connectivity_url"
const LOCAL_CONFIG_PATH := "user://supabase_config.json"
const GOOGLE_CONNECTIVITY_URL := "https://www.google.com/generate_204"

const SYNC_TABLES: Array[String] = [
	"profiles",
	"progress",
	"question_attempts",
	"player_state",
	"triggered_dialogues",
	"defeated_enemies",
	"achievements",
]

const TABLE_CONFIG := {
	"profiles": {
		"path": "profiles",
		"on_conflict": "id",
		"columns": ["id", "username", "preferred_language", "created_at"],
	},
	"progress": {
		"path": "progress",
		"on_conflict": "user_id,subject,grade_level",
		"columns": ["id", "user_id", "subject", "grade_level", "progression_pct", "points", "updated_at"],
	},
	"question_attempts": {
		"path": "question_attempts",
		"on_conflict": "id",
		"columns": ["id", "user_id", "subject", "grade_level", "question_id", "is_correct", "misconception_category", "attempted_at"],
		"boolean_columns": ["is_correct"],
	},
	"player_state": {
		"path": "player_state",
		"on_conflict": "user_id",
		"columns": ["id", "user_id", "player_name", "selected_character", "last_level", "last_position_x", "last_position_y", "music_volume", "sfx_volume", "has_played", "updated_at"],
		"boolean_columns": ["has_played"],
	},
	"triggered_dialogues": {
		"path": "triggered_dialogues",
		"on_conflict": "user_id,dialogue_id",
		"columns": ["id", "user_id", "dialogue_id"],
	},
	"defeated_enemies": {
		"path": "defeated_enemies",
		"on_conflict": "user_id,enemy_id",
		"columns": ["id", "user_id", "enemy_id"],
	},
	"achievements": {
		"path": "achievements",
		"on_conflict": "user_id,achievement_id",
		"columns": ["id", "user_id", "achievement_id", "unlocked_at"],
	},
}

@export var enabled: bool = true
@export var sync_interval_seconds: float = 30.0
@export var request_timeout_seconds: float = 10.0

var supabase_url: String = ""
var supabase_anon_key: String = ""
var supabase_access_token: String = ""
var connectivity_url: String = ""

var _connectivity_http: HTTPRequest
var _sync_http: HTTPRequest
var _timer: Timer
var _is_syncing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()

	_connectivity_http = HTTPRequest.new()
	_connectivity_http.process_mode = Node.PROCESS_MODE_ALWAYS
	_connectivity_http.timeout = request_timeout_seconds
	add_child(_connectivity_http)

	_sync_http = HTTPRequest.new()
	_sync_http.process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_http.timeout = request_timeout_seconds
	add_child(_sync_http)

	_timer = Timer.new()
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.wait_time = max(sync_interval_seconds, 5.0)
	_timer.timeout.connect(func(): sync_now())
	add_child(_timer)

	if enabled and _is_configured():
		_timer.start()
		call_deferred("sync_now")
	elif enabled:
		GameLogger.info("SupabaseSyncManager: Not configured; set %s and %s to enable sync." % [SUPABASE_URL_SETTING, SUPABASE_ANON_KEY_SETTING])

	call_deferred("_check_deep_link")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_check_deep_link()

func configure(url: String, anon_key: String, access_token: String = "") -> void:
	supabase_url = url.strip_edges().trim_suffix("/")
	supabase_anon_key = anon_key.strip_edges()
	supabase_access_token = access_token.strip_edges()
	if enabled and _is_configured() and _timer != null and _timer.is_stopped():
		_timer.start()
		sync_now()

func sync_now() -> bool:
	if _is_syncing:
		return false
	if not enabled:
		return false
	if not _is_configured():
		return false

	_is_syncing = true
	sync_started.emit()

	if not DatabaseManager.is_initialized:
		DatabaseManager.open_database()

	var online := await _has_connectivity()
	if not online:
		_is_syncing = false
		sync_finished.emit(false)
		return false

	var success := await _sync_dirty_records()
	_is_syncing = false
	sync_finished.emit(success)
	return success

func _sync_dirty_records() -> bool:
	var dirty_records := DatabaseManager.get_dirty_records()
	var all_ok := true

	for table_name in SYNC_TABLES:
		var records: Array = dirty_records.get(table_name, [])
		if records.is_empty():
			continue

		var payload := _prepare_payload(table_name, records)
		if payload.is_empty():
			continue

		var ok := await _upsert_table(table_name, payload)
		if ok:
			DatabaseManager.mark_clean(table_name, _extract_ids(records))
		else:
			all_ok = false

	return all_ok

func _has_connectivity() -> bool:
	var target_url := connectivity_url
	var headers := PackedStringArray()
	if _is_configured():
		headers = _auth_headers(false)
		if target_url.is_empty():
			target_url = supabase_url + "/rest/v1/subjects?select=id&limit=1"
	if target_url.is_empty():
		target_url = GOOGLE_CONNECTIVITY_URL

	var err := _connectivity_http.request(target_url, headers, HTTPClient.METHOD_HEAD)
	if err != OK:
		GameLogger.warning("SupabaseSyncManager: Connectivity request failed to start: %d" % err)
		return false

	var response: Array = await _connectivity_http.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	var connected := result == HTTPRequest.RESULT_SUCCESS and response_code > 0 and response_code < 500
	if not connected:
		GameLogger.info("SupabaseSyncManager: Offline or connectivity check failed, code=%d result=%d." % [response_code, result])
	return connected

func _upsert_table(table_name: String, rows: Array) -> bool:
	var config: Dictionary = TABLE_CONFIG[table_name]
	var url := "%s/rest/v1/%s?on_conflict=%s" % [
		supabase_url,
		str(config["path"]),
		str(config["on_conflict"]),
	]
	var body := JSON.stringify(rows)
	var err := _sync_http.request(url, _auth_headers(true), HTTPClient.METHOD_POST, body)
	if err != OK:
		GameLogger.error("SupabaseSyncManager: Failed to start upsert for %s: %d" % [table_name, err])
		return false

	var response: Array = await _sync_http.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		GameLogger.info("SupabaseSyncManager: Synced %d row(s) for %s." % [rows.size(), table_name])
		return true

	var body_bytes: PackedByteArray = response[3]
	var error_body := body_bytes.get_string_from_utf8()
	GameLogger.error("SupabaseSyncManager: Upsert failed for %s. result=%d code=%d body=%s" % [table_name, result, response_code, error_body])
	sync_failed.emit("Upsert failed for %s with HTTP %d" % [table_name, response_code])
	return false

func _prepare_payload(table_name: String, records: Array) -> Array:
	var config: Dictionary = TABLE_CONFIG[table_name]
	var columns: Array = config.get("columns", [])
	var boolean_columns: Array = config.get("boolean_columns", [])
	var payload: Array = []

	for record in records:
		var row := {}
		for column in columns:
			if not record.has(column):
				continue
			var value = record[column]
			if boolean_columns.has(column):
				value = _to_bool(value)
			row[column] = value
		if not row.is_empty():
			payload.append(row)

	return payload

func _extract_ids(records: Array) -> Array:
	var ids: Array = []
	for record in records:
		if record.has("id"):
			ids.append(record["id"])
	return ids

func _auth_headers(include_prefer: bool) -> PackedStringArray:
	var bearer := supabase_access_token if not supabase_access_token.is_empty() else supabase_anon_key
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: %s" % supabase_anon_key,
		"Authorization: Bearer %s" % bearer,
	])
	if include_prefer:
		headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	return headers

func _load_config() -> void:
	supabase_url = _get_config_value(SUPABASE_URL_SETTING, "SUPABASE_URL").trim_suffix("/")
	supabase_anon_key = _get_config_value(SUPABASE_ANON_KEY_SETTING, "SUPABASE_ANON_KEY")
	supabase_access_token = _get_config_value(SUPABASE_ACCESS_TOKEN_SETTING, "SUPABASE_ACCESS_TOKEN")
	connectivity_url = _get_config_value(CONNECTIVITY_URL_SETTING, "SYNC_CONNECTIVITY_URL")
	_load_local_config()

func _load_local_config() -> void:
	if not FileAccess.file_exists(LOCAL_CONFIG_PATH):
		return

	var file := FileAccess.open(LOCAL_CONFIG_PATH, FileAccess.ModeFlags.READ)
	if file == null:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		GameLogger.warning("SupabaseSyncManager: Failed to parse local Supabase config.")
		return

	var config: Dictionary = json.data
	if supabase_url.is_empty():
		supabase_url = str(config.get("supabase_url", "")).strip_edges().trim_suffix("/")
	if supabase_anon_key.is_empty():
		supabase_anon_key = str(config.get("supabase_anon_key", "")).strip_edges()
	if supabase_access_token.is_empty():
		supabase_access_token = str(config.get("supabase_access_token", "")).strip_edges()
	if connectivity_url.is_empty():
		connectivity_url = str(config.get("connectivity_url", "")).strip_edges()

	var u_id = str(config.get("user_id", "")).strip_edges()
	if not u_id.is_empty():
		PlayerDataManager.user_id = u_id
	var g_key = str(config.get("gemini_api_key", "")).strip_edges()
	if not g_key.is_empty():
		ApiClient.gemini_api_key = g_key
		if not Engine.has_singleton(ApiClient.gemini_nano_plugin_name):
			ApiClient.active_provider = ApiClient.AiProvider.GEMINI_1_5_FLASH
	var g_level = config.get("grade_level", 7)
	Globals.grade_level = int(g_level)

func _check_deep_link() -> void:
	if OS.get_name() != "Android":
		return
	
	var godot_singleton = Engine.get_singleton("Godot")
	if not godot_singleton:
		return
		
	var activity = godot_singleton.getAppActivity()
	if not activity:
		return
		
	var intent = activity.getIntent()
	if not intent:
		return
		
	var data_uri: String = intent.getDataString()
	if data_uri.is_empty():
		return
		
	GameLogger.info("SupabaseSyncManager: Found launch intent URI: %s" % data_uri)
	_parse_and_apply_deep_link(data_uri)
	intent.setData(null)

func _parse_and_apply_deep_link(uri: String) -> void:
	if not uri.contains("?"):
		return
		
	var query_part = uri.split("?", true, 1)[1]
	var params_list = query_part.split("&")
	
	var params := {}
	for param in params_list:
		if not param.contains("="):
			continue
		var parts = param.split("=", true, 1)
		params[parts[0]] = parts[1]
		
	var u_id = params.get("user_id", "")
	var token = params.get("access_token", "")
	var gemini_key = params.get("gemini_key", "")
	var grade_level_str = params.get("grade_level", "")
	
	if not u_id.is_empty():
		PlayerDataManager.user_id = u_id
		GameLogger.info("SupabaseSyncManager: Configured user_id from deep link: %s" % u_id)
		
	if not token.is_empty():
		supabase_access_token = token
		GameLogger.info("SupabaseSyncManager: Configured access_token from deep link.")
		
	if not gemini_key.is_empty():
		ApiClient.gemini_api_key = gemini_key
		if not Engine.has_singleton(ApiClient.gemini_nano_plugin_name):
			ApiClient.active_provider = ApiClient.AiProvider.GEMINI_1_5_FLASH
			GameLogger.info("SupabaseSyncManager: Configured gemini_api_key and switched provider to GEMINI_1_5_FLASH.")
		else:
			GameLogger.info("SupabaseSyncManager: Configured gemini_api_key from deep link, keeping GEMINI_NANO.")
		
	if not grade_level_str.is_empty():
		Globals.grade_level = grade_level_str.to_int()
		GameLogger.info("SupabaseSyncManager: Configured grade_level from deep link: %s" % grade_level_str)
		
	_save_local_config(u_id, token, gemini_key, grade_level_str)
	sync_now()

func _save_local_config(p_user_id: String, p_token: String, p_gemini_key: String, p_grade_level: String = "") -> void:
	var config := {}
	if FileAccess.file_exists(LOCAL_CONFIG_PATH):
		var file := FileAccess.open(LOCAL_CONFIG_PATH, FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				config = json.data
	
	config["supabase_url"] = supabase_url
	config["supabase_anon_key"] = supabase_anon_key
	if not p_token.is_empty():
		config["supabase_access_token"] = p_token
	if not p_user_id.is_empty():
		config["user_id"] = p_user_id
	if not p_gemini_key.is_empty():
		config["gemini_api_key"] = p_gemini_key
	if not p_grade_level.is_empty():
		config["grade_level"] = p_grade_level.to_int()

	var write_file := FileAccess.open(LOCAL_CONFIG_PATH, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(JSON.stringify(config))
		GameLogger.info("SupabaseSyncManager: Saved credentials to local user config.")

func _get_config_value(setting_name: String, env_name: String) -> String:
	var value := str(ProjectSettings.get_setting(setting_name, ""))
	if value.is_empty():
		value = OS.get_environment(env_name)
	return value.strip_edges()

func _is_configured() -> bool:
	return not supabase_url.is_empty() and not supabase_anon_key.is_empty()

func _to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	if (value is int) or (value is float):
		return value != 0
	return str(value).to_lower() in ["true", "1", "yes"]
