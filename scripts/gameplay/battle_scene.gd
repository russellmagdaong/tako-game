extends Control

var _answer_input: LineEdit
var _output_text: Label
var _submit_btn: Button
var _hints_popup: Panel
var _unlocked_hints: Array[String] = []

var _current_question: String = ""
var _expected_answer: String = ""
var _current_hint: String = ""
var _attempt_count: int = 0
var _skill_type: String = ""
var _awaiting_ai: bool = false

const PLAYER_SPRITE_HEIGHT = 150.0
const ENEMY_SPRITE_HEIGHT = 200.0
const BATTLE_TUTORIAL_ID: String = "battle_tutorial"

func _ready() -> void:
	if Globals.instance != null and Globals.instance.ui_theme != null:
		theme = Globals.instance.ui_theme

	_answer_input = get_node("%AnswerInput")
	_output_text  = get_node("%OutputText")
	_submit_btn   = get_node("%SubmitButton")

	_submit_btn.disabled = true
	_submit_btn.pressed.connect(_on_submit_pressed)
	_answer_input.text_submitted.connect(_on_answer_submitted)

	var hint_btn = _answer_input.get_parent().get_node("TitleRow/HintButton")
	if hint_btn:
		hint_btn.hint_requested.connect(_on_hint_pressed)

	_hints_popup = get_node("HintsPopup")
	_hints_popup.close_requested.connect(_on_hints_popup_close_requested)
	_hints_popup.request_hint_requested.connect(_on_request_hint_requested)
	_hints_popup.hide()

	_setup_sprites()
	call_deferred("_apply_zoom")

	var enemy = SceneManager.battle_enemy
	_skill_type = _skill_name(enemy.get("skill_type") if enemy != null else 0)

	ApiClient.question_generated.connect(_on_question_generated)
	ApiClient.feedback_generated.connect(_on_feedback_generated)
	ApiClient.request_failed.connect(_on_request_failed)

	set_problem_text("Generating question...")
	_set_output_text("")
	ApiClient.generate_question(_skill_type)

	call_deferred("_maybe_show_battle_tutorial")

func _exit_tree() -> void:
	if ApiClient.question_generated.is_connected(_on_question_generated):
		ApiClient.question_generated.disconnect(_on_question_generated)
	if ApiClient.feedback_generated.is_connected(_on_feedback_generated):
		ApiClient.feedback_generated.disconnect(_on_feedback_generated)
	if ApiClient.request_failed.is_connected(_on_request_failed):
		ApiClient.request_failed.disconnect(_on_request_failed)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_submit_pressed() -> void:
	_submit_answer()

func _on_answer_submitted(_text: String) -> void:
	_submit_answer()

func _submit_answer() -> void:
	if _awaiting_ai or _submit_btn.disabled:
		return
	var player_answer := _answer_input.text.strip_edges()
	if player_answer.is_empty():
		_set_output_text("Type your answer first.")
		return

	_attempt_count += 1
	_submit_btn.disabled = true

	if _is_correct_answer(player_answer, _expected_answer):
		_set_output_text("Correct!")
		await get_tree().create_timer(2.0).timeout
		SceneManager.end_battle()
	else:
		_awaiting_ai = true
		_set_output_text("Checking...")
		ApiClient.generate_feedback(_current_question, _expected_answer, player_answer)

func _is_correct_answer(player: String, expected: String) -> bool:
	if player.strip_edges().to_lower() == expected.strip_edges().to_lower():
		return true
	var p_val := player.strip_edges().to_float()
	var e_val := expected.strip_edges().to_float()
	if player.strip_edges().is_valid_float() and expected.strip_edges().is_valid_float():
		return absf(p_val - e_val) < 0.0001
	return false

# ---------------------------------------------------------------------------
# Hint handling
# ---------------------------------------------------------------------------

func _on_hint_pressed() -> void:
	if _hints_popup.visible:
		_hints_popup.hide()
		return
	if _unlocked_hints.is_empty() and not _current_hint.is_empty():
		_hints_popup.clear_hints()
		_unlocked_hints.append(_current_hint)
		_hints_popup.add_hint(_current_hint)
	elif _unlocked_hints.is_empty():
		_hints_popup.show_no_hints_message()
	_hints_popup.show()

func _on_hints_popup_close_requested() -> void:
	_hints_popup.hide()

func _on_request_hint_requested() -> void:
	_hints_popup.hide()
	if _current_hint.is_empty():
		return
	if not _unlocked_hints.has(_current_hint):
		_unlocked_hints.append(_current_hint)
		_hints_popup.clear_hints()
		_hints_popup.add_hint(_current_hint)
	await _show_dialogue("Guide", _current_hint)

# ---------------------------------------------------------------------------
# AI responses
# ---------------------------------------------------------------------------

func _on_question_generated(data: Dictionary) -> void:
	var question: String = data.get("question", "")
	var answer: String   = data.get("answer",   "")
	var hint: String     = data.get("hint",      "")

	if question.is_empty() or answer.is_empty():
		set_problem_text("(Could not generate question — is Ollama running?)")
		_set_output_text("Make sure Ollama is installed and running locally.")
		return

	_current_question = question
	_expected_answer  = answer
	_current_hint     = hint
	set_problem_text(question)
	_submit_btn.disabled = false
	_answer_input.grab_focus()

func _on_feedback_generated(data: Dictionary) -> void:
	_awaiting_ai = false
	_submit_btn.disabled = false
	var feedback: String = data.get("feedback", "Incorrect. Try again!")
	_set_output_text(feedback)

func _on_request_failed(tag: String, code: int) -> void:
	_awaiting_ai = false
	match tag:
		"question_generate":
			set_problem_text("(AI unavailable — check that Ollama is running)")
			_set_output_text("Could not reach Ollama. (Error %d)" % code)
		"feedback_generate":
			_submit_btn.disabled = false
			_set_output_text("Incorrect. Try again!")

# ---------------------------------------------------------------------------
# Tutorial
# ---------------------------------------------------------------------------

func _maybe_show_battle_tutorial() -> void:
	if PlayerDataManager.triggered_dialogues.has(BATTLE_TUTORIAL_ID):
		return
	PlayerDataManager.mark_dialogue_triggered(BATTLE_TUTORIAL_ID)
	var lines: Array = [
		["Guide", "Welcome to your first math battle!"],
		["Guide", "A math question will appear in the panel on the right. Read it carefully."],
		["Guide", "Type your answer in the input field, then press Submit (or hit Enter)."],
		["Guide", "If you need a nudge, tap the Hint button. Good luck!"],
	]
	var entries: Array[DialogueEntry] = []
	for line in lines:
		var e := DialogueEntry.new()
		e.speaker_name = line[0]
		e.text = line[1]
		entries.append(e)
	await DialogueManager.show(entries)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _show_dialogue(speaker: String, text: String) -> void:
	var e := DialogueEntry.new()
	e.speaker_name = speaker
	e.text = text
	await DialogueManager.show([e])

static func _skill_name(index: int) -> String:
	var keys := Enums.SkillType.keys()
	return keys[index] if index >= 0 and index < keys.size() else "BasicArithmetic"

# ---------------------------------------------------------------------------
# Visual setup (unchanged from original)
# ---------------------------------------------------------------------------

func _apply_zoom() -> void:
	var hgap = get_node("MarginContainer/ContentSplit/LeftVBox/VisualPanel/VisualHBox/HGap")
	if hgap:
		hgap.custom_minimum_size.x = 16.0
	var bg           = get_node("%BattleBG")
	var visual_hbox  = get_node("MarginContainer/ContentSplit/LeftVBox/VisualPanel/VisualHBox")
	var zoom_scale   = Vector2(2.0, 2.0)
	if bg:
		bg.pivot_offset = bg.size / 2.0
		bg.scale = zoom_scale
	if visual_hbox:
		visual_hbox.pivot_offset = visual_hbox.size / 2.0
		visual_hbox.scale = zoom_scale
		visual_hbox.position.y += 10.0

func _setup_sprites() -> void:
	var enemy_display  = get_node("%EnemyDisplay")
	var player_display = get_node("%PlayerDisplay")
	var character: String = Globals.instance.selected_character if Globals.instance != null else "playerm"
	var enemy = SceneManager.battle_enemy
	var is_final_boss: bool = enemy.is_final_boss if enemy != null else false
	if is_final_boss:
		enemy_display.custom_minimum_size = Vector2(0, ENEMY_SPRITE_HEIGHT)
	enemy_display.texture = _load_battle_texture("player", character)
	var bg = get_node("%BattleBG")
	if enemy != null and is_final_boss:
		bg.texture = _load_battle_texture("bg", "boss")
	else:
		var enemy_id: String = enemy.enemy_id if enemy != null else ""
		var bg_tex := _load_battle_texture("bg", enemy_id)
		bg.texture = bg_tex if bg_tex != null else _load_battle_texture("bg", "default")
	if enemy != null:
		if is_final_boss:
			var boss_char = "playerf" if character == "playerm" else "playerm"
			player_display.texture = _flip_horizontal(_load_battle_texture("player", boss_char))
		else:
			var et := _load_battle_texture("enemy", enemy.enemy_id)
			player_display.texture = et if et != null else _load_battle_texture("enemy", "default")

func _flip_horizontal(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var img = source.get_image()
	img.flip_x()
	return ImageTexture.create_from_image(img)

func _load_battle_texture(folder: String, texture_name: String) -> Texture2D:
	if texture_name.is_empty():
		return null
	var path := "res://assets/battle/%s/%s.png" % [folder, texture_name]
	return load(path) if ResourceLoader.exists(path) else null

func _set_output_text(text: String) -> void:
	_output_text.text = text
	call_deferred("_adjust_output_font_size")

func _adjust_output_font_size() -> void:
	var scroll := get_node("MarginContainer/ContentSplit/LeftVBox/OutputPanel/OutputMargin/OutputVBox/OutputScroll") as Control
	var available := scroll.size.y
	var width := _output_text.size.x
	if width <= 0 or available <= 0:
		return
	var font = _output_text.get_theme_font("font")
	for f_size in range(24, 7, -1):
		_output_text.add_theme_font_size_override("font_size", f_size)
		var text_size = font.get_multiline_string_size(_output_text.text, HORIZONTAL_ALIGNMENT_LEFT, width, f_size)
		if text_size.y <= available:
			return

func set_problem_text(text: String) -> void:
	var label = get_node("%ProblemText")
	label.text = text
	call_deferred("_adjust_problem_font_size", label)

func _adjust_problem_font_size(label: Label) -> void:
	var panel = get_node("MarginContainer/ContentSplit/RightVBox/ProblemPanel")
	var available = panel.size.y - 24.0
	var width = label.size.x
	if width <= 0:
		return
	var font = label.get_theme_font("font")
	for f_size in range(64, 7, -1):
		label.add_theme_font_size_override("font_size", f_size)
		var text_size = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, f_size)
		if text_size.y <= available:
			return
