extends Node
# Autoload: PlayerDataManager
# Keeps the in-memory player save facade stable while persisting through SQLite.

signal progress_reset

const LEGACY_SAVE_FILE := "player_data.json"

const ACHIEVEMENTS: Array = [
	{
		"id": "billiards_complete",
		"title": "First Strike",
		"description": "Cleared the first level. The numbers feared you.",
	},
	{
		"id": "level0_complete",
		"title": "Solid Foundation",
		"description": "Proved you know your basics. Every great mathematician started here.",
	},
	{
		"id": "final_boss_complete",
		"title": "Calculated",
		"description": "The final boss is defeated. Every equation balanced, every answer exact.",
	},
]

var user_id: String = ""
var has_played: bool = false
var player_name: String = ""
var selected_character: String = "playerm"
var achievements: Array[String] = []
var badges: Array[String]:
	get:
		return achievements
var last_level_name: String = ""
var last_position: Vector2 = Vector2.ZERO
var triggered_dialogues: Array[String] = []
var defeated_enemies: Array[String] = []

func load_data() -> void:
	if not _ensure_database_ready():
		has_played = false
		return

	var active_user_id := _ensure_user_id()
	var data := DatabaseManager.get_player_state(active_user_id)
	if data.is_empty():
		has_played = false
		_sync_collections_from_database()
		return

	has_played = int(data.get("has_played", 0)) == 1
	player_name = str(data.get("player_name", ""))
	selected_character = str(data.get("selected_character", "playerm"))
	if selected_character.is_empty():
		selected_character = "playerm"
	Globals.selected_character = selected_character
	last_level_name = str(data.get("last_level", ""))
	last_position = Vector2(
		float(data.get("last_position_x", 0.0)),
		float(data.get("last_position_y", 0.0))
	)
	_sync_collections_from_database()
	apply_audio_settings(data)

func save_character(character: String) -> void:
	selected_character = character if not character.is_empty() else "playerm"
	Globals.selected_character = selected_character
	has_played = true
	_save_to_database()

func set_player_name(p_name: String) -> void:
	player_name = p_name.strip_edges()
	_save_to_database()
	if _ensure_database_ready():
		DatabaseManager.save_profile(_ensure_user_id(), player_name, Globals.preferred_language)

func save_progress(level_name: String, position: Vector2 = Vector2.ZERO) -> void:
	last_level_name = level_name
	last_position = position
	has_played = true
	_save_to_database()

func mark_dialogue_triggered(trigger_id: String) -> void:
	if trigger_id.is_empty():
		return
	if not trigger_id in triggered_dialogues:
		triggered_dialogues.append(trigger_id)
	Globals.triggered_dialogues[trigger_id] = true
	if _ensure_database_ready():
		DatabaseManager.mark_dialogue_triggered(_ensure_user_id(), trigger_id)

func mark_enemy_defeated(enemy_id: String) -> void:
	if enemy_id.is_empty():
		return
	if not enemy_id in defeated_enemies:
		defeated_enemies.append(enemy_id)
	Globals.defeated_enemies[enemy_id] = true
	if _ensure_database_ready():
		DatabaseManager.mark_enemy_defeated(_ensure_user_id(), enemy_id)

func unlock_achievement(id: String) -> void:
	if id.is_empty():
		return
	if id not in achievements:
		achievements.append(id)
		if _ensure_database_ready():
			DatabaseManager.unlock_achievement(_ensure_user_id(), id)

func reset_to_defaults() -> void:
	var active_user_id := _ensure_user_id()
	has_played = false
	player_name = ""
	selected_character = "playerm"
	Globals.selected_character = selected_character
	achievements = []
	last_level_name = ""
	last_position = Vector2.ZERO
	triggered_dialogues = []
	defeated_enemies = []
	Globals.triggered_dialogues.clear()
	Globals.defeated_enemies.clear()
	if _ensure_database_ready():
		DatabaseManager.clear_player_data(active_user_id)
		_save_to_database()
	_remove_legacy_json()
	progress_reset.emit()

func set_from_server(
		p_has_played: bool,
		p_player_name: String,
		p_character: String,
		p_achievements: Array[String],
		p_last_level: String = "",
		p_last_position: Vector2 = Vector2.ZERO,
		p_triggered_dialogues: Array[String] = [],
		p_defeated_enemies: Array[String] = []) -> void:
	has_played = p_has_played
	player_name = p_player_name
	selected_character = p_character if p_character != "" else "playerm"
	Globals.selected_character = selected_character
	achievements = p_achievements.duplicate()
	last_level_name = p_last_level
	last_position = p_last_position
	triggered_dialogues = p_triggered_dialogues.duplicate()
	defeated_enemies = p_defeated_enemies.duplicate()
	_rebuild_global_sets()
	_replace_database_player_data()

func apply_audio_settings(data: Dictionary) -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if music_bus >= 0 and data.has("music_volume"):
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(float(data["music_volume"])))
	if sfx_bus >= 0 and data.has("sfx_volume"):
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(float(data["sfx_volume"])))

func _save_to_database() -> void:
	if not _ensure_database_ready():
		return

	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	DatabaseManager.save_player_state(
		_ensure_user_id(),
		player_name,
		selected_character,
		last_level_name,
		last_position,
		db_to_linear(AudioServer.get_bus_volume_db(music_bus)) if music_bus >= 0 else 0.5,
		db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) if sfx_bus >= 0 else 0.5,
		has_played
	)

func _replace_database_player_data() -> void:
	if not _ensure_database_ready():
		return

	var active_user_id := _ensure_user_id()
	DatabaseManager.clear_player_data(active_user_id)
	_save_to_database()
	for id in achievements:
		DatabaseManager.unlock_achievement(active_user_id, id)
	for trigger_id in triggered_dialogues:
		DatabaseManager.mark_dialogue_triggered(active_user_id, trigger_id)
	for enemy_id in defeated_enemies:
		DatabaseManager.mark_enemy_defeated(active_user_id, enemy_id)

func _sync_collections_from_database() -> void:
	var active_user_id := _ensure_user_id()
	achievements = DatabaseManager.get_unlocked_achievements(active_user_id)
	triggered_dialogues = DatabaseManager.get_triggered_dialogues(active_user_id)
	defeated_enemies = DatabaseManager.get_defeated_enemies(active_user_id)
	_rebuild_global_sets()

func _rebuild_global_sets() -> void:
	Globals.triggered_dialogues.clear()
	for trigger_id in triggered_dialogues:
		Globals.triggered_dialogues[trigger_id] = true

	Globals.defeated_enemies.clear()
	for enemy_id in defeated_enemies:
		Globals.defeated_enemies[enemy_id] = true

func _ensure_database_ready() -> bool:
	if not DatabaseManager.is_initialized:
		DatabaseManager.open_database()
	return DatabaseManager.is_initialized

func _ensure_user_id() -> String:
	if user_id.is_empty():
		user_id = DatabaseManager.get_or_create_local_user_id()
	return user_id

func _remove_legacy_json() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(LEGACY_SAVE_FILE)
