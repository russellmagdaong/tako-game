extends Control

var _answer_input: LineEdit
var _status_label: Label
var _submit_btn: Button
var _calc_overlay: Control

var _current_question: String = ""
var _expected_answer: String = ""
var _attempt_count: int = 0
var _skill_type: String = ""
var _awaiting_ai: bool = false
var _feedback_overlay: Control
var _feedback_toggle_btn: Button
var _feedback_shown: bool = false

const PLAYER_SPRITE_HEIGHT = 150.0
const ENEMY_SPRITE_HEIGHT = 200.0

func _ready() -> void:
	if Globals.instance != null and Globals.instance.ui_theme != null:
		theme = Globals.instance.ui_theme

	_answer_input = get_node("%AnswerInput")
	_status_label = get_node("%StatusLabel")
	_submit_btn   = get_node("%SubmitButton")

	_calc_overlay = get_node("%CalcOverlay")
	get_node("%CalcToggle").pressed.connect(_on_calc_toggle_pressed)
	_feedback_overlay = get_node("%FeedbackOverlay")
	_feedback_overlay.visible = false
	_feedback_toggle_btn = get_node("%FeedbackToggle")
	_feedback_toggle_btn.visible = false
	_feedback_toggle_btn.pressed.connect(_on_feedback_toggle_pressed)

	_submit_btn.disabled = true
	_submit_btn.pressed.connect(_on_submit_pressed)
	_answer_input.text_submitted.connect(_on_answer_submitted)

	_setup_sprites()

	var enemy = SceneManager.battle_enemy
	_skill_type = _skill_name(enemy.get("skill_type") if enemy != null else 0)

	ApiClient.question_generated.connect(_on_question_generated)
	ApiClient.feedback_generated.connect(_on_feedback_generated)
	ApiClient.request_failed.connect(_on_request_failed)

	_build_calc_pad()

	set_problem_text("Generating question..." if Globals.preferred_language == "en" else "Bumubuo ng tanong...")
	_set_output_text("")
	ApiClient.generate_question(_skill_type, Globals.preferred_language)

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
		_set_output_text("Type your answer first." if Globals.preferred_language == "en" else "I-type muna ang iyong sagot.")
		return

	_attempt_count += 1
	_submit_btn.disabled = true

	var check_result := MathManager.verify_player_answer(player_answer)
	if check_result["is_correct"]:
		_set_output_text("Correct!" if Globals.preferred_language == "en" else "Tama!")
		if DatabaseManager.is_initialized and not PlayerDataManager.user_id.is_empty():
			var enemy = SceneManager.battle_enemy
			var enemy_id = enemy.enemy_id if enemy != null else "enemy"
			DatabaseManager.add_question_attempt(PlayerDataManager.user_id, "math", MathManager.active_template.grade, enemy_id, true)
		await get_tree().create_timer(2.0).timeout
		SceneManager.end_battle()
	else:
		_awaiting_ai = true
		_set_output_text("Checking..." if Globals.preferred_language == "en" else "Sinusuri...")
		if DatabaseManager.is_initialized and not PlayerDataManager.user_id.is_empty():
			var enemy = SceneManager.battle_enemy
			var enemy_id = enemy.enemy_id if enemy != null else "enemy"
			DatabaseManager.add_question_attempt(
				PlayerDataManager.user_id,
				"math",
				MathManager.active_template.grade,
				enemy_id,
				false,
				check_result["misconception"]
			)
		ApiClient.generate_feedback(
			_current_question,
			MathManager.active_expected_answer,
			player_answer,
			check_result["misconception"],
			Globals.preferred_language,
			_attempt_count
		)

func _is_correct_answer(player: String, expected: String) -> bool:
	if player.strip_edges().to_lower() == expected.strip_edges().to_lower():
		return true
	var p_val := player.strip_edges().to_float()
	var e_val := expected.strip_edges().to_float()
	if player.strip_edges().is_valid_float() and expected.strip_edges().is_valid_float():
		return absf(p_val - e_val) < 0.0001
	return false

# ---------------------------------------------------------------------------
# Calculator overlay
# ---------------------------------------------------------------------------

func _on_calc_toggle_pressed() -> void:
	_calc_overlay.visible = not _calc_overlay.visible
	get_node("%CalcToggle").text = "Calc ▼" if _calc_overlay.visible else "Calc ▲"

func _on_feedback_toggle_pressed() -> void:
	_feedback_overlay.visible = not _feedback_overlay.visible
	_feedback_toggle_btn.text = "Help ▼" if _feedback_overlay.visible else "Help ▲"

# ---------------------------------------------------------------------------
# AI responses
# ---------------------------------------------------------------------------

func _on_question_generated(data: Dictionary) -> void:
	var question: String = data.get("question", "")
	var answer: String   = data.get("answer",   "")

	if question.is_empty():
		if Globals.preferred_language == "tl":
			set_problem_text("(Hindi makabuo ng tanong. Subukang muli.)")
			_set_output_text("")
		else:
			set_problem_text("(Could not generate a question. Please try again.)")
			_set_output_text("")
		return

	_current_question = question
	_expected_answer  = answer
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
			set_problem_text("(Could not generate a question. Please try again.)")
			_set_output_text("")
		"feedback_generate":
			_submit_btn.disabled = false
			_set_output_text("Incorrect. Try again!")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _skill_name(index: int) -> String:
	var keys := Enums.SkillType.keys()
	return keys[index] if index >= 0 and index < keys.size() else "BasicArithmetic"

# ---------------------------------------------------------------------------
# Visual setup (unchanged from original)
# ---------------------------------------------------------------------------


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
	bg.texture = _load_battle_texture("bg", "11")
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
	_status_label.text = text
	if not text.is_empty() and not _feedback_shown:
		_feedback_shown = true
		_feedback_overlay.visible = true
		_feedback_toggle_btn.visible = true
		_feedback_toggle_btn.text = "Help ▼"

const _CALC_LAYOUT: Array = [
	["sin", "cos", "tan", "^",  "π"],
	["7",   "8",   "9",   "÷",  "⌫"],
	["4",   "5",   "6",   "*",  "AC"],
	["1",   "2",   "3",   "-",  "("],
	["0",   ".",   "x",   "+",  ")"],
]

func _build_calc_pad() -> void:
	var grid := get_node("%CalcGrid")
	for row in _CALC_LAYOUT:
		for symbol: String in row:
			var btn := Button.new()
			btn.text = symbol
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size   = Vector2(0, 52)
			btn.pressed.connect(_on_calc_pressed.bind(symbol))
			grid.add_child(btn)

func _on_calc_pressed(symbol: String) -> void:
	match symbol:
		"⌫":
			if not _answer_input.text.is_empty():
				_answer_input.text = _answer_input.text.left(_answer_input.text.length() - 1)
		"AC":
			_answer_input.text = ""
		"÷":
			_answer_input.text += "/"
		"sin", "cos", "tan":
			_answer_input.text += symbol + "("
		_:
			_answer_input.text += symbol
	_answer_input.caret_column = _answer_input.text.length()

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
