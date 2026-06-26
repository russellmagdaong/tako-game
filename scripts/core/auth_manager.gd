extends Node
# Autoload: AuthManager
# Single source of truth for authentication in the consolidated Godot app.
#
# - Guest mode is ALWAYS available and fully offline: it reuses the local SQLite
#   user id (no network, no Supabase). This is decision (A) from the port plan.
# - Email/password sign in & sign up use Supabase GoTrue REST (HTTPRequest),
#   consistent with SupabaseSyncManager. They require Supabase to be configured
#   and reachable; otherwise the user is told to play as guest.
#
# Other systems should listen to `auth_state_changed` and read `get_session()`.

signal auth_state_changed(event: String, session: Dictionary)

const SESSION_PATH := "user://auth_session.json"
const REQUEST_TIMEOUT := 15.0

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var email: String = ""
var is_guest: bool = false
var expires_at: int = 0 # unix seconds; 0 = non-expiring (guest)

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)

	_load_session()
	# A restored online session needs its token handed to the sync manager.
	# Deferred so SupabaseSyncManager (registered after us) is ready.
	if has_session() and not is_guest:
		call_deferred("_apply_session_to_sync")

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

func has_session() -> bool:
	return not user_id.is_empty()

func get_session() -> Dictionary:
	if not has_session():
		return {}
	return {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"user_id": user_id,
		"email": email,
		"is_guest": is_guest,
	}

# ---------------------------------------------------------------------------
# Guest (always offline-capable)
# ---------------------------------------------------------------------------

func sign_in_anonymously() -> Dictionary:
	var uid := DatabaseManager.get_or_create_local_user_id()
	user_id = uid
	access_token = ""
	refresh_token = ""
	email = ""
	is_guest = true
	expires_at = 0
	PlayerDataManager.user_id = uid
	# Guests are anonymous and ephemeral: don't carry over a previously set
	# username, and don't persist the session across app restarts.
	PlayerDataManager.set_player_name("")
	GameLogger.info("AuthManager: Guest session started (%s)." % uid)
	auth_state_changed.emit("SIGNED_IN", get_session())
	return {"success": true, "error": ""}

# ---------------------------------------------------------------------------
# Email / password (online via Supabase GoTrue)
# ---------------------------------------------------------------------------

func sign_in_with_password(p_email: String, p_password: String) -> Dictionary:
	p_email = p_email.strip_edges()
	if p_email.is_empty() or p_password.is_empty():
		return {"success": false, "error": "Please enter your email and password."}

	var base := _supabase_url()
	var anon := _anon_key()
	if base.is_empty() or anon.is_empty():
		# No backend configured: continue offline with a local account.
		return _local_account(p_email, "")

	var url := "%s/auth/v1/token?grant_type=password" % base
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: %s" % anon])
	var body := JSON.stringify({"email": p_email, "password": p_password})
	var res := await _post(url, headers, body)
	if not res["ok"]:
		if int(res["code"]) == 0:
			# Server unreachable: continue offline with a local account.
			return _local_account(p_email, "")
		return {"success": false, "error": _extract_error(res, "Sign-in failed. Check your credentials.")}

	_apply_auth_response(res["data"], p_email)
	return {"success": true, "error": ""}

func sign_up(p_email: String, p_password: String, p_username: String) -> Dictionary:
	p_email = p_email.strip_edges()
	p_username = p_username.strip_edges()
	if p_email.is_empty() or p_password.is_empty():
		return {"success": false, "error": "Please enter your email and password."}
	if p_password.length() < 6:
		return {"success": false, "error": "Password must be at least 6 characters."}

	var base := _supabase_url()
	var anon := _anon_key()
	if base.is_empty() or anon.is_empty():
		# No backend configured: create the account locally (offline-first).
		return _local_account(p_email, p_username)

	var url := "%s/auth/v1/signup" % base
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: %s" % anon])
	var payload := {"email": p_email, "password": p_password}
	if not p_username.is_empty():
		payload["data"] = {"username": p_username}
	var body := JSON.stringify(payload)
	var res := await _post(url, headers, body)
	if not res["ok"]:
		if int(res["code"]) == 0:
			# Server unreachable: create the account locally.
			return _local_account(p_email, p_username)
		return {"success": false, "error": _extract_error(res, "Sign-up failed.")}

	var data = res["data"]
	# When email confirmation is disabled GoTrue returns a full session.
	if data is Dictionary and data.has("access_token"):
		_apply_auth_response(data, p_email)
		if not p_username.is_empty():
			_persist_username(p_username)
		return {"success": true, "error": ""}

	# Otherwise the account exists but needs confirmation / a separate sign-in.
	return {"success": true, "error": "", "needs_confirmation": true}

# ---------------------------------------------------------------------------
# Sign out
# ---------------------------------------------------------------------------

func sign_out() -> void:
	var base := _supabase_url()
	if not is_guest and not access_token.is_empty() and not base.is_empty():
		# Best-effort server logout; ignore the result.
		var url := "%s/auth/v1/logout" % base
		var headers := PackedStringArray([
			"Content-Type: application/json",
			"apikey: %s" % _anon_key(),
			"Authorization: Bearer %s" % access_token,
		])
		_http.request(url, headers, HTTPClient.METHOD_POST, "{}")

	access_token = ""
	refresh_token = ""
	user_id = ""
	email = ""
	is_guest = false
	expires_at = 0
	_delete_session()
	GameLogger.info("AuthManager: Signed out.")
	auth_state_changed.emit("SIGNED_OUT", {})

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

# Offline-first fallback: establish a persistent local account when Supabase is
# not configured or unreachable. The account reuses the device's local user id
# so progress is retained, and (unlike guest) it survives app restarts.
func _local_account(p_email: String, p_username: String) -> Dictionary:
	var uid := DatabaseManager.get_or_create_local_user_id()
	user_id = uid
	email = p_email
	is_guest = false
	access_token = ""
	refresh_token = ""
	expires_at = 0
	PlayerDataManager.user_id = uid
	if not p_username.strip_edges().is_empty():
		_persist_username(p_username)
	_save_session()
	GameLogger.info("AuthManager: Local account session for %s." % p_email)
	auth_state_changed.emit("SIGNED_IN", get_session())
	return {"success": true, "error": ""}

func _apply_auth_response(data, p_email: String) -> void:
	if not (data is Dictionary):
		return
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	var expires_in := int(data.get("expires_in", 0))
	expires_at = int(Time.get_unix_time_from_system()) + expires_in if expires_in > 0 else 0
	is_guest = false

	var user = data.get("user", {})
	if user is Dictionary and user.has("id"):
		user_id = str(user["id"])
		email = str(user.get("email", p_email))
	else:
		email = p_email

	PlayerDataManager.user_id = user_id
	_save_session()
	_apply_session_to_sync()
	GameLogger.info("AuthManager: Signed in as %s." % email)
	auth_state_changed.emit("SIGNED_IN", get_session())

func _apply_session_to_sync() -> void:
	if SupabaseSyncManager == null:
		return
	var base := _supabase_url()
	var anon := _anon_key()
	if base.is_empty() or anon.is_empty():
		return
	SupabaseSyncManager.configure(base, anon, access_token)

func _persist_username(p_username: String) -> void:
	if user_id.is_empty():
		return
	if not DatabaseManager.is_initialized:
		DatabaseManager.open_database()
	DatabaseManager.save_profile(user_id, p_username, Globals.preferred_language)
	PlayerDataManager.player_name = p_username

func _post(url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		return {"ok": false, "code": 0, "data": null, "raw": "Network request could not start."}

	var r: Array = await _http.request_completed
	var result: int = r[0]
	var code: int = r[1]
	var bytes: PackedByteArray = r[3]
	var text := bytes.get_string_from_utf8()
	var parsed = null
	if not text.is_empty():
		var json := JSON.new()
		if json.parse(text) == OK:
			parsed = json.data
	var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	return {"ok": ok, "code": code, "data": parsed, "raw": text}

func _extract_error(res: Dictionary, fallback: String) -> String:
	var data = res.get("data")
	if data is Dictionary:
		for key in ["error_description", "msg", "message", "error"]:
			if data.has(key) and not str(data[key]).is_empty():
				return str(data[key])
	if int(res.get("code", 0)) == 0:
		return "Could not reach the server. Check your connection or play as guest."
	return fallback

func _supabase_url() -> String:
	if SupabaseSyncManager != null:
		return SupabaseSyncManager.supabase_url
	return ""

func _anon_key() -> String:
	if SupabaseSyncManager != null:
		return SupabaseSyncManager.supabase_anon_key
	return ""

# ---- Session persistence ----

func _save_session() -> void:
	var data := {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"user_id": user_id,
		"email": email,
		"is_guest": is_guest,
		"expires_at": expires_at,
	}
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return
	var data: Dictionary = json.data
	# Guests are ephemeral and must never auto-restore across app restarts.
	if bool(data.get("is_guest", false)):
		_delete_session()
		return
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	user_id = str(data.get("user_id", ""))
	email = str(data.get("email", ""))
	is_guest = false
	expires_at = int(data.get("expires_at", 0))
	if has_session():
		PlayerDataManager.user_id = user_id
		GameLogger.info("AuthManager: Restored account session.")

func _delete_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)
