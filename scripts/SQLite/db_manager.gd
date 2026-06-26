extends Node
# Autoload: DatabaseManager
# Handles local offline-first SQLite database operations and prepares data for Supabase sync.

const DB_PATH := "user://tako.db"
const LOCAL_USERNAME := "Player"

var db: SQLite = null
var is_initialized := false

func _ready() -> void:
	GameLogger.info("DatabaseManager Autoload loaded.")
	open_database()

# ---------------------------------------------------------------------------
# Core Database Connections & Initialization
# ---------------------------------------------------------------------------

func open_database() -> void:
	if is_initialized:
		return
	
	db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.NORMAL
	db.foreign_keys = true
	
	var err = db.open_db()
	if not err:
		GameLogger.error("DatabaseManager: Failed to open SQLite database.")
		return
		
	GameLogger.info("DatabaseManager: Successfully opened SQLite database.")
	initialize_tables()
	is_initialized = true

func initialize_tables() -> void:
	# 1. profiles table
	var profiles_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"username": {"data_type": "text", "not_null": true},
		"preferred_language": {"data_type": "text", "default": "'en'"},
		"created_at": {"data_type": "text", "default": "CURRENT_TIMESTAMP"},
		"is_dirty": {"data_type": "int", "default": 0},
		"updated_at": {"data_type": "text", "default": "CURRENT_TIMESTAMP"}
	}
	db.create_table("profiles", profiles_schema)
	
	# 2. progress table
	var progress_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"user_id": {"data_type": "text", "not_null": true},
		"subject": {"data_type": "text", "not_null": true},
		"grade_level": {"data_type": "int", "not_null": true},
		"progression_pct": {"data_type": "real", "default": 0.0},
		"points": {"data_type": "int", "default": 0},
		"updated_at": {"data_type": "text", "default": "CURRENT_TIMESTAMP"},
		"is_dirty": {"data_type": "int", "default": 1}
	}
	db.create_table("progress", progress_schema)
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_progress_user_subject_grade ON progress (user_id, subject, grade_level);")
	
	# 3. question_attempts table
	var question_attempts_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"user_id": {"data_type": "text", "not_null": true},
		"subject": {"data_type": "text", "not_null": true},
		"grade_level": {"data_type": "int", "not_null": true},
		"question_id": {"data_type": "text", "not_null": true},
		"is_correct": {"data_type": "int", "not_null": true},
		"misconception_category": {"data_type": "text"},
		"attempted_at": {"data_type": "text", "default": "CURRENT_TIMESTAMP"},
		"is_dirty": {"data_type": "int", "default": 1}
	}
	db.create_table("question_attempts", question_attempts_schema)

	# 4. subjects table
	var subjects_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"display_name": {"data_type": "text", "not_null": true},
		"is_active": {"data_type": "int", "default": 0}
	}
	db.create_table("subjects", subjects_schema)

	# 5. player_state table (RPG Save State)
	var player_state_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"user_id": {"data_type": "text", "not_null": true},
		"player_name": {"data_type": "text", "default": "''"},
		"selected_character": {"data_type": "text", "default": "'playerm'"},
		"last_level": {"data_type": "text", "default": "''"},
		"last_position_x": {"data_type": "real", "default": 0.0},
		"last_position_y": {"data_type": "real", "default": 0.0},
		"music_volume": {"data_type": "real", "default": 0.5},
		"sfx_volume": {"data_type": "real", "default": 0.5},
		"has_played": {"data_type": "int", "default": 0},
		"updated_at": {"data_type": "text", "default": "CURRENT_TIMESTAMP"},
		"is_dirty": {"data_type": "int", "default": 1}
	}
	db.create_table("player_state", player_state_schema)
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_player_state_user ON player_state (user_id);")
	
	# 6. triggered_dialogues table (RPG Save State)
	var triggered_dialogues_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"user_id": {"data_type": "text", "not_null": true},
		"dialogue_id": {"data_type": "text", "not_null": true},
		"is_dirty": {"data_type": "int", "default": 1}
	}
	db.create_table("triggered_dialogues", triggered_dialogues_schema)
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_triggered_dialogues_user_dialogue ON triggered_dialogues (user_id, dialogue_id);")

	# 7. defeated_enemies table (RPG Save State)
	var defeated_enemies_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"user_id": {"data_type": "text", "not_null": true},
		"enemy_id": {"data_type": "text", "not_null": true},
		"is_dirty": {"data_type": "int", "default": 1}
	}
	db.create_table("defeated_enemies", defeated_enemies_schema)
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_defeated_enemies_user_enemy ON defeated_enemies (user_id, enemy_id);")

	# 8. achievements table (RPG Save State)
	var achievements_schema := {
		"id": {"data_type": "text", "primary_key": true, "not_null": true},
		"user_id": {"data_type": "text", "not_null": true},
		"achievement_id": {"data_type": "text", "not_null": true},
		"unlocked_at": {"data_type": "text", "default": "CURRENT_TIMESTAMP"},
		"is_dirty": {"data_type": "int", "default": 1}
	}
	db.create_table("achievements", achievements_schema)
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_achievements_user_achievement ON achievements (user_id, achievement_id);")

	_migrate_rpg_tables_to_uuid()

	# Seed subjects lookup if empty
	db.select_rows("subjects", "", ["id"])
	if db.query_result.is_empty():
		db.insert_rows("subjects", [
			{"id": "math", "display_name": "Mathematics", "is_active": 1},
			{"id": "science", "display_name": "Science", "is_active": 0},
			{"id": "languages", "display_name": "Languages", "is_active": 0},
			{"id": "history", "display_name": "Philippine History", "is_active": 0}
		])

	GameLogger.info("DatabaseManager: SQLite schemas verified/created successfully.")

func _migrate_rpg_tables_to_uuid() -> void:
	_migrate_table_id_to_uuid(
		"triggered_dialogues",
		["user_id", "dialogue_id", "is_dirty"],
		"CREATE TABLE triggered_dialogues (id TEXT PRIMARY KEY NOT NULL, user_id TEXT NOT NULL, dialogue_id TEXT NOT NULL, is_dirty INT DEFAULT 1);",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_triggered_dialogues_user_dialogue ON triggered_dialogues (user_id, dialogue_id);"
	)
	_migrate_table_id_to_uuid(
		"defeated_enemies",
		["user_id", "enemy_id", "is_dirty"],
		"CREATE TABLE defeated_enemies (id TEXT PRIMARY KEY NOT NULL, user_id TEXT NOT NULL, enemy_id TEXT NOT NULL, is_dirty INT DEFAULT 1);",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_defeated_enemies_user_enemy ON defeated_enemies (user_id, enemy_id);"
	)
	_migrate_table_id_to_uuid(
		"achievements",
		["user_id", "achievement_id", "unlocked_at", "is_dirty"],
		"CREATE TABLE achievements (id TEXT PRIMARY KEY NOT NULL, user_id TEXT NOT NULL, achievement_id TEXT NOT NULL, unlocked_at TEXT DEFAULT CURRENT_TIMESTAMP, is_dirty INT DEFAULT 1);",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_achievements_user_achievement ON achievements (user_id, achievement_id);"
	)

func _migrate_table_id_to_uuid(table_name: String, columns: Array, create_sql: String, index_sql: String) -> void:
	db.query("PRAGMA table_info(%s);" % table_name)
	var id_type := ""
	for column in db.query_result:
		if str(column.get("name", "")) == "id":
			id_type = str(column.get("type", "")).to_lower()
			break

	if id_type == "text":
		return

	db.select_rows(table_name, "", ["*"])
	var existing_rows: Array = db.query_result.duplicate(true)
	db.query("DROP TABLE %s;" % table_name)
	db.query(create_sql)
	for existing in existing_rows:
		var migrated := {"id": generate_uuid()}
		for column_name in columns:
			migrated[column_name] = existing.get(column_name)
		db.insert_row(table_name, migrated)
	db.query(index_sql)
	GameLogger.info("DatabaseManager: Migrated '%s' IDs to UUID text." % table_name)

# ---------------------------------------------------------------------------
# Profiles Operations
# ---------------------------------------------------------------------------

func save_profile(user_id: String, username: String, preferred_lang: String = "en") -> void:
	var now = _get_utc_timestamp()
	var row := {
		"id": user_id,
		"username": username,
		"preferred_language": preferred_lang,
		"is_dirty": 1,
		"updated_at": now
	}
	
	var select_cond := "id = '%s'" % user_id
	db.select_rows("profiles", select_cond, ["id"])
	if db.query_result.is_empty():
		db.insert_row("profiles", row)
	else:
		db.update_rows("profiles", select_cond, {
			"username": username,
			"preferred_language": preferred_lang,
			"is_dirty": 1,
			"updated_at": now
		})
	GameLogger.info("DatabaseManager: Profile saved for ID: %s" % user_id)

func get_profile(user_id: String) -> Dictionary:
	db.select_rows("profiles", "id = '%s'" % user_id, ["*"])
	if not db.query_result.is_empty():
		return db.query_result[0]
	return {}

# ---------------------------------------------------------------------------
# Progress Operations
# ---------------------------------------------------------------------------

func save_progress(user_id: String, subject: String, grade_level: int, pct: float, points: int) -> void:
	var now = _get_utc_timestamp()
	var select_cond := "user_id = '%s' AND subject = '%s' AND grade_level = %d" % [user_id, subject, grade_level]
	
	db.select_rows("progress", select_cond, ["id"])
	if db.query_result.is_empty():
		var row := {
			"id": generate_uuid(),
			"user_id": user_id,
			"subject": subject,
			"grade_level": grade_level,
			"progression_pct": pct,
			"points": points,
			"updated_at": now,
			"is_dirty": 1
		}
		db.insert_row("progress", row)
	else:
		db.update_rows("progress", select_cond, {
			"progression_pct": pct,
			"points": points,
			"updated_at": now,
			"is_dirty": 1
		})
	GameLogger.info("DatabaseManager: Progress saved for %s/Grade %d" % [subject, grade_level])

func get_progress(user_id: String, subject: String, grade_level: int) -> Dictionary:
	var select_cond := "user_id = '%s' AND subject = '%s' AND grade_level = %d" % [user_id, subject, grade_level]
	db.select_rows("progress", select_cond, ["*"])
	if not db.query_result.is_empty():
		return db.query_result[0]
	return {}

# ---------------------------------------------------------------------------
# Question Attempt Logging
# ---------------------------------------------------------------------------

func add_question_attempt(user_id: String, subject: String, grade_level: int, question_id: String, is_correct: bool, misconception_cat: String = "") -> void:
	var row := {
		"id": generate_uuid(),
		"user_id": user_id,
		"subject": subject,
		"grade_level": grade_level,
		"question_id": question_id,
		"is_correct": 1 if is_correct else 0,
		"misconception_category": misconception_cat if not misconception_cat.is_empty() else null,
		"attempted_at": _get_utc_timestamp(),
		"is_dirty": 1
	}
	db.insert_row("question_attempts", row)
	GameLogger.info("DatabaseManager: Attempt logged for question: %s" % question_id)

func get_question_attempts(user_id: String) -> Array:
	db.select_rows("question_attempts", "user_id = '%s'" % user_id, ["*"])
	return db.query_result

# ---------------------------------------------------------------------------
# Player State Operations
# ---------------------------------------------------------------------------

func get_or_create_local_user_id() -> String:
	if not is_initialized:
		open_database()

	db.select_rows("player_state", "", ["user_id"])
	if not db.query_result.is_empty():
		return str(db.query_result[0]["user_id"])

	db.select_rows("profiles", "", ["id"])
	if not db.query_result.is_empty():
		return str(db.query_result[0]["id"])

	var local_user_id := generate_uuid()
	save_profile(local_user_id, LOCAL_USERNAME)
	return local_user_id

# Consolidates ALL locally-owned rows onto a single user id. Used when an
# offline/guest profile signs in online so every row matches the authenticated
# user id and therefore passes Supabase row-level security. Any pre-existing
# guest/local id (or leftover split data) is re-keyed onto new_id. Rows that
# would collide with an existing destination row are skipped (UPDATE OR IGNORE)
# and the leftover source rows removed.
func consolidate_local_data(new_id: String) -> void:
	new_id = new_id.strip_edges()
	if new_id.is_empty():
		return
	if not is_initialized:
		open_database()

	var user_tables := ["progress", "question_attempts", "player_state", "triggered_dialogues", "defeated_enemies", "achievements"]
	for t in user_tables:
		db.query("UPDATE OR IGNORE %s SET user_id = '%s', is_dirty = 1 WHERE user_id != '%s';" % [t, new_id, new_id])
		db.query("DELETE FROM %s WHERE user_id != '%s';" % [t, new_id])

	# profiles is keyed by id (not user_id)
	db.query("UPDATE OR IGNORE profiles SET id = '%s', is_dirty = 1 WHERE id != '%s';" % [new_id, new_id])
	db.query("DELETE FROM profiles WHERE id != '%s';" % new_id)

	GameLogger.info("DatabaseManager: Consolidated all local data onto %s." % new_id)

func save_player_state(
		user_id: String,
		username: String,
		character: String,
		level_name: String,
		position: Vector2,
		music_volume: float,
		sfx_volume: float,
		has_played: bool) -> void:
	if user_id.is_empty():
		return

	var now := _get_utc_timestamp()
	var select_cond := "user_id = '%s'" % user_id
	var character_value := character if not character.is_empty() else "playerm"
	var row := {
		"user_id": user_id,
		"player_name": username,
		"selected_character": character_value,
		"last_level": level_name,
		"last_position_x": position.x,
		"last_position_y": position.y,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"has_played": 1 if has_played else 0,
		"updated_at": now,
		"is_dirty": 1
	}

	db.select_rows("player_state", select_cond, ["id"])
	if db.query_result.is_empty():
		row["id"] = generate_uuid()
		db.insert_row("player_state", row)
	else:
		db.update_rows("player_state", select_cond, row)

	if not username.is_empty():
		save_profile(user_id, username)

func get_player_state(user_id: String) -> Dictionary:
	if user_id.is_empty():
		return {}

	db.select_rows("player_state", "user_id = '%s'" % user_id, ["*"])
	if not db.query_result.is_empty():
		return db.query_result[0]
	return {}

func clear_player_data(user_id: String) -> void:
	if user_id.is_empty() or not is_initialized:
		return

	db.query("DELETE FROM triggered_dialogues WHERE user_id = '%s';" % user_id)
	db.query("DELETE FROM defeated_enemies WHERE user_id = '%s';" % user_id)
	db.query("DELETE FROM achievements WHERE user_id = '%s';" % user_id)
	db.query("DELETE FROM player_state WHERE user_id = '%s';" % user_id)
	GameLogger.warning("DatabaseManager: Cleared RPG player data for user: %s" % user_id)

# ---------------------------------------------------------------------------
# RPG State Operations
# ---------------------------------------------------------------------------

func mark_dialogue_triggered(user_id: String, dialogue_id: String) -> void:
	var select_cond := "user_id = '%s' AND dialogue_id = '%s'" % [user_id, dialogue_id]
	db.select_rows("triggered_dialogues", select_cond, ["id"])
	if db.query_result.is_empty():
		db.insert_row("triggered_dialogues", {
			"id": generate_uuid(),
			"user_id": user_id,
			"dialogue_id": dialogue_id,
			"is_dirty": 1
		})

func get_triggered_dialogues(user_id: String) -> Array[String]:
	db.select_rows("triggered_dialogues", "user_id = '%s'" % user_id, ["dialogue_id"])
	var dialogues: Array[String] = []
	for row in db.query_result:
		dialogues.append(row["dialogue_id"])
	return dialogues

func mark_enemy_defeated(user_id: String, enemy_id: String) -> void:
	var select_cond := "user_id = '%s' AND enemy_id = '%s'" % [user_id, enemy_id]
	db.select_rows("defeated_enemies", select_cond, ["id"])
	if db.query_result.is_empty():
		db.insert_row("defeated_enemies", {
			"id": generate_uuid(),
			"user_id": user_id,
			"enemy_id": enemy_id,
			"is_dirty": 1
		})

func get_defeated_enemies(user_id: String) -> Array[String]:
	db.select_rows("defeated_enemies", "user_id = '%s'" % user_id, ["enemy_id"])
	var enemies: Array[String] = []
	for row in db.query_result:
		enemies.append(row["enemy_id"])
	return enemies

func unlock_achievement(user_id: String, achievement_id: String) -> void:
	var select_cond := "user_id = '%s' AND achievement_id = '%s'" % [user_id, achievement_id]
	db.select_rows("achievements", select_cond, ["id"])
	if db.query_result.is_empty():
		db.insert_row("achievements", {
			"id": generate_uuid(),
			"user_id": user_id,
			"achievement_id": achievement_id,
			"unlocked_at": _get_utc_timestamp(),
			"is_dirty": 1
		})

func get_unlocked_achievements(user_id: String) -> Array[String]:
	db.select_rows("achievements", "user_id = '%s'" % user_id, ["achievement_id"])
	var list: Array[String] = []
	for row in db.query_result:
		list.append(row["achievement_id"])
	return list

# ---------------------------------------------------------------------------
# Synced & Dirty Metadata Sync Workers
# ---------------------------------------------------------------------------

func get_dirty_records() -> Dictionary:
	var dirty_data := {
		"profiles": [],
		"progress": [],
		"question_attempts": [],
		"player_state": [],
		"triggered_dialogues": [],
		"defeated_enemies": [],
		"achievements": []
	}
	
	db.select_rows("profiles", "is_dirty = 1", ["*"])
	dirty_data["profiles"] = db.query_result.duplicate()
	
	db.select_rows("progress", "is_dirty = 1", ["*"])
	dirty_data["progress"] = db.query_result.duplicate()
	
	db.select_rows("question_attempts", "is_dirty = 1", ["*"])
	dirty_data["question_attempts"] = db.query_result.duplicate()

	db.select_rows("player_state", "is_dirty = 1", ["*"])
	dirty_data["player_state"] = db.query_result.duplicate()
	
	db.select_rows("triggered_dialogues", "is_dirty = 1", ["*"])
	dirty_data["triggered_dialogues"] = db.query_result.duplicate()

	db.select_rows("defeated_enemies", "is_dirty = 1", ["*"])
	dirty_data["defeated_enemies"] = db.query_result.duplicate()

	db.select_rows("achievements", "is_dirty = 1", ["*"])
	dirty_data["achievements"] = db.query_result.duplicate()
	
	return dirty_data

func mark_clean(table_name: String, ids: Array) -> void:
	if ids.is_empty():
		return
	
	# SQLite requires SQL formatting for in-list arguments
	var placeholders := []
	for id in ids:
		if id is String:
			placeholders.append("'%s'" % id)
		else:
			placeholders.append(str(id))
			
	var cond := "id IN (%s)" % ", ".join(placeholders)
	db.update_rows(table_name, cond, {"is_dirty": 0})
	GameLogger.info("DatabaseManager: Marked %d rows in '%s' as clean." % [ids.size(), table_name])

# ---------------------------------------------------------------------------
# Data Wipes & Utilities
# ---------------------------------------------------------------------------

func clear_all_data() -> void:
	if not is_initialized:
		return
	db.query("DELETE FROM question_attempts;")
	db.query("DELETE FROM progress;")
	db.query("DELETE FROM player_state;")
	db.query("DELETE FROM triggered_dialogues;")
	db.query("DELETE FROM defeated_enemies;")
	db.query("DELETE FROM achievements;")
	db.query("DELETE FROM profiles;")
	GameLogger.warning("DatabaseManager: Local SQLite database wiped.")

static func generate_uuid() -> String:
	# Random UUIDv4 generator
	var chars := "0123456789abcdef"
	var uuid := ""
	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4"
		elif i == 19:
			var r = randi() % 4 + 8
			uuid += chars[r]
		else:
			var r = randi() % 16
			uuid += chars[r]
	return uuid

func _get_utc_timestamp() -> String:
	# ISO-8601 formatted UTC date-time string
	return Time.get_datetime_string_from_system(true) + "Z"
