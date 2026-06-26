extends Control

@export var accent: Color = Color("ffd24a")
@export var card_bg: Color = Color(1, 1, 1, 0.08)

const CHARACTERS := ["playerm", "playerf"]
const CHARACTER_LABELS := {"playerm": "Boy", "playerf": "Girl"}

var _greeting: Label
var _panels := {}
var _tab_buttons := {}
var _active_tab := "home"

var _profile_name: Label
var _profile_grade: Label
var _stat_monsters: Label
var _stat_questions: Label
var _stat_accuracy: Label
var _stat_streak: Label
var _progress_bar: ProgressBar
var _progress_label: Label

var _username_edit: LineEdit
var _character_btn: Button
var _character_index: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Globals.instance and Globals.instance.ui_theme:
		theme = Globals.instance.ui_theme

	_character_index = maxi(0, CHARACTERS.find(PlayerDataManager.selected_character))

	_greeting = get_node("%GreetingLabel")

	var content := get_node("%ContentArea")
	_panels["home"]     = _build_home_panel()
	_panels["world"]    = _build_world_panel()
	_panels["settings"] = _build_settings_panel()
	for key in _panels:
		content.add_child(_panels[key])

	_tab_buttons["home"]     = get_node("%HomeTab")
	_tab_buttons["world"]    = get_node("%WorldTab")
	_tab_buttons["settings"] = get_node("%SettingsTab")

	_tab_buttons["home"].pressed.connect(_select_tab.bind("home"))
	_tab_buttons["world"].pressed.connect(_select_tab.bind("world"))
	_tab_buttons["settings"].pressed.connect(_select_tab.bind("settings"))

	_select_tab("home")

# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

func _build_home_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 22)
	scroll.add_child(vb)

	var profile := _make_card()
	var pbody: VBoxContainer = profile.get_node("Content")
	_profile_name = Label.new()
	_profile_name.add_theme_font_size_override("font_size", 30)
	pbody.add_child(_profile_name)
	_profile_grade = Label.new()
	_profile_grade.modulate = accent
	pbody.add_child(_profile_grade)
	vb.add_child(profile)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	_stat_monsters  = _add_stat_card(grid, "Monsters Defeated")
	_stat_questions = _add_stat_card(grid, "Questions Done")
	_stat_accuracy  = _add_stat_card(grid, "Accuracy")
	_stat_streak    = _add_stat_card(grid, "Best Streak")
	vb.add_child(grid)

	var prog := _make_card()
	var prog_body: VBoxContainer = prog.get_node("Content")
	var plabel := Label.new()
	plabel.text = "Overall Progress"
	prog_body.add_child(plabel)
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 26)
	prog_body.add_child(_progress_bar)
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_body.add_child(_progress_label)
	vb.add_child(prog)

	var cont := _make_button("Continue Adventure", accent, Color("201600"))
	cont.pressed.connect(func() -> void: GameManager.start_game_from_dashboard())
	vb.add_child(cont)

	return scroll

func _build_world_panel() -> Control:
	var center := CenterContainer.new()
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(720, 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 26)
	center.add_child(vb)

	var logo := Label.new()
	logo.text = "TAKO"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 80)
	logo.modulate = accent
	vb.add_child(logo)

	var desc := Label.new()
	desc.text = "Explore story-driven grade halls, answer questions, and get AI-guided explanations in English or Filipino."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(640, 0)
	desc.modulate = Color(0.96, 0.97, 1.0)
	vb.add_child(desc)

	var start := _make_button("> Start Adventure", Color("f3cf55"), Color("201600"))
	start.pressed.connect(func() -> void: GameManager.start_game_from_dashboard())
	vb.add_child(start)

	return center

func _build_settings_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	scroll.add_child(vb)

	vb.add_child(_section_label("PROFILE"))

	var uname := _make_card()
	var urow := HBoxContainer.new()
	urow.add_theme_constant_override("separation", 12)
	uname.get_node("Content").add_child(urow)
	_username_edit = LineEdit.new()
	_username_edit.custom_minimum_size = Vector2(0, 60)
	_username_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_username_edit.placeholder_text = "Username"
	urow.add_child(_username_edit)
	var save_btn := _make_small_button("Save")
	save_btn.pressed.connect(_on_save_username)
	urow.add_child(save_btn)
	vb.add_child(uname)

	var char_row := _make_cycle_row("Character", _character_label_text())
	_character_btn = char_row[1]
	_character_btn.pressed.connect(_on_cycle_character)
	vb.add_child(char_row[0])

	vb.add_child(_section_label("PREFERENCES"))
	vb.add_child(_make_sound_toggle("Music", "Music"))
	vb.add_child(_make_sound_toggle("Sound Effects", "SFX"))
	vb.add_child(_make_language_toggle())

	vb.add_child(_section_label("APP"))
	var logout := _make_button("Log Out", Color("eb6049"), Color("ffffff"))
	logout.pressed.connect(func() -> void: AuthManager.sign_out())
	vb.add_child(logout)

	return scroll

# ---------------------------------------------------------------------------
# Tab selection
# ---------------------------------------------------------------------------

func _select_tab(tab_name: String) -> void:
	_active_tab = tab_name
	for key in _panels:
		_panels[key].visible = key == tab_name
	for key in _tab_buttons:
		_tab_buttons[key].button_pressed = key == tab_name
	if tab_name == "home":
		_refresh_home()
	elif tab_name == "settings":
		_refresh_settings()

# ---------------------------------------------------------------------------
# Data refresh
# ---------------------------------------------------------------------------

func _refresh_home() -> void:
	var pname := PlayerDataManager.player_name
	var display_name := pname if not pname.is_empty() else "Trainer"
	_greeting.text = "Hey, %s!" % display_name
	_profile_name.text = display_name
	_profile_grade.text = "Grade %d" % clampi(Globals.grade_level, 7, 10)

	var uid := _user_id()
	var monsters := PlayerDataManager.defeated_enemies.size()
	var attempts: Array = []
	if not uid.is_empty():
		attempts = DatabaseManager.get_question_attempts(uid)

	var total := attempts.size()
	var correct := 0
	for a in attempts:
		if int(a.get("is_correct", 0)) == 1:
			correct += 1
	var accuracy := 0
	if total > 0:
		accuracy = int(round(float(correct) / float(total) * 100.0))
	var streak := _compute_best_streak(attempts)

	_stat_monsters.text  = str(monsters)
	_stat_questions.text = str(total)
	_stat_accuracy.text  = "%d%%" % accuracy
	_stat_streak.text    = str(streak)

	var total_ach := PlayerDataManager.ACHIEVEMENTS.size()
	var pct := 0.0
	if total_ach > 0:
		pct = float(PlayerDataManager.achievements.size()) / float(total_ach) * 100.0
	_progress_bar.value  = pct
	_progress_label.text = "%d%%" % int(round(pct))

func _refresh_settings() -> void:
	if _username_edit != null:
		_username_edit.text = PlayerDataManager.player_name

func _compute_best_streak(attempts: Array) -> int:
	if attempts.is_empty():
		return 0
	var sorted := attempts.duplicate()
	sorted.sort_custom(func(a, b): return str(a.get("attempted_at", "")) < str(b.get("attempted_at", "")))
	var best := 0
	var current := 0
	for a in sorted:
		if int(a.get("is_correct", 0)) == 1:
			current += 1
			best = maxi(best, current)
		else:
			current = 0
	return best

# ---------------------------------------------------------------------------
# Settings actions
# ---------------------------------------------------------------------------

func _on_save_username() -> void:
	PlayerDataManager.set_player_name(_username_edit.text)
	_refresh_home()

func _on_cycle_character() -> void:
	_character_index = (_character_index + 1) % CHARACTERS.size()
	PlayerDataManager.save_character(CHARACTERS[_character_index])
	_character_btn.text = _character_label_text()

func _character_label_text() -> String:
	return CHARACTER_LABELS.get(CHARACTERS[_character_index], CHARACTERS[_character_index])

func _user_id() -> String:
	if not PlayerDataManager.user_id.is_empty():
		return PlayerDataManager.user_id
	return DatabaseManager.get_or_create_local_user_id()

# ---------------------------------------------------------------------------
# UI helpers (panel content builders)
# ---------------------------------------------------------------------------

func _make_card() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = card_bg
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.name = "Content"
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	return panel

func _add_stat_card(grid: GridContainer, label_text: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = card_bg
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var value := Label.new()
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 40)
	value.modulate = accent
	vb.add_child(value)
	var caption := Label.new()
	caption.text = label_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.modulate = Color(0.85, 0.9, 1.0)
	vb.add_child(caption)
	grid.add_child(panel)
	return value

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.7, 0.78, 0.92)
	label.add_theme_font_size_override("font_size", 22)
	return label

func _make_cycle_row(title: String, value_text: String) -> Array:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = card_bg
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var btn := _make_small_button(value_text)
	row.add_child(btn)
	return [panel, btn]

func _make_sound_toggle(title: String, bus_name: String) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = card_bg
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var toggle := CheckButton.new()
	var bus_idx := AudioServer.get_bus_index(bus_name)
	toggle.button_pressed = bus_idx < 0 or not AudioServer.is_bus_mute(bus_idx)
	toggle.toggled.connect(func(pressed: bool) -> void:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, not pressed))
	row.add_child(toggle)
	return panel

func _make_language_toggle() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = card_bg
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var label := Label.new()
	label.text = "Language"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var btn := _make_small_button(_language_text())
	btn.pressed.connect(func() -> void:
		Globals.preferred_language = "tl" if Globals.preferred_language == "en" else "en"
		btn.text = _language_text())
	row.add_child(btn)
	return panel

func _language_text() -> String:
	return "Filipino" if Globals.preferred_language == "tl" else "English"

func _make_small_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(160, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color("201600"))
	btn.add_theme_color_override("font_hover_color", Color("201600"))
	btn.add_theme_color_override("font_pressed_color", Color("201600"))
	return btn

func _make_button(text: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 76)
	btn.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(16)
	normal.set_content_margin_all(14)
	normal.border_color = Color("ff7d00")
	normal.set_border_width_all(2)
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.12)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_font_size_override("font_size", 28)
	return btn
