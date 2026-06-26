extends Control
# Login / sign-up screen. Port of frontend/app/login.tsx.
# Calls AuthManager; on success GameManager swaps in the dashboard.

const BG_TOP := Color("0b1020")
const BG_BOTTOM := Color("1b2a6b")
const ACCENT := Color("ffd24a")

var _mode: String = "signin" # "signin" | "signup"

var _signin_tab: Button
var _signup_tab: Button
var _username_field: VBoxContainer
var _username_edit: LineEdit
var _email_edit: LineEdit
var _password_edit: LineEdit
var _error_label: Label
var _submit_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Globals.instance and Globals.instance.ui_theme:
		theme = Globals.instance.ui_theme

	_build_background()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_constant_override("separation", 20)
	center.add_child(card)

	var title := Label.new()
	title.text = "TAKO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.modulate = ACCENT
	card.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MathQuest AI"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.9, 0.95, 1.0)
	card.add_child(subtitle)

	# Tab bar
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(tabs)
	_signin_tab = _make_tab("Sign In")
	_signin_tab.pressed.connect(func() -> void: _set_mode("signin"))
	tabs.add_child(_signin_tab)
	_signup_tab = _make_tab("Sign Up")
	_signup_tab.pressed.connect(func() -> void: _set_mode("signup"))
	tabs.add_child(_signup_tab)

	# Username (signup only)
	_username_field = _make_field("Username", false)
	_username_edit = _username_field.get_node("Edit")
	card.add_child(_username_field)

	# Email
	var email_field := _make_field("Email", false)
	_email_edit = email_field.get_node("Edit")
	_email_edit.keep_editing_on_text_submit = true
	card.add_child(email_field)

	# Password
	var password_field := _make_field("Password", true)
	_password_edit = password_field.get_node("Edit")
	card.add_child(password_field)

	_error_label = Label.new()
	_error_label.modulate = Color("ff6b6b")
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	card.add_child(_error_label)

	_submit_btn = _make_button("Sign In", ACCENT, Color("201600"))
	_submit_btn.pressed.connect(_on_submit)
	card.add_child(_submit_btn)

	var back_btn := _make_button("Back", Color(1, 1, 1, 0.12), Color("ffffff"))
	back_btn.pressed.connect(func() -> void: GameManager.show_landing())
	card.add_child(back_btn)

	_set_mode("signin")

# ---------------------------------------------------------------------------

func _set_mode(mode: String) -> void:
	_mode = mode
	var is_signup := mode == "signup"
	_username_field.visible = is_signup
	_submit_btn.text = "Create Account" if is_signup else "Sign In"
	_error_label.visible = false
	_signin_tab.button_pressed = not is_signup
	_signup_tab.button_pressed = is_signup

func _on_submit() -> void:
	_set_busy(true)
	_error_label.visible = false

	var res: Dictionary
	if _mode == "signup":
		res = await AuthManager.sign_up(_email_edit.text, _password_edit.text, _username_edit.text)
	else:
		res = await AuthManager.sign_in_with_password(_email_edit.text, _password_edit.text)

	# AuthManager may have triggered a screen swap on success; bail if freed.
	if not is_instance_valid(self):
		return

	_set_busy(false)

	if not res.get("success", false):
		_show_error(res.get("error", "Something went wrong."))
		return

	if res.get("needs_confirmation", false):
		_show_error("Account created. Please confirm your email, then sign in.")
		_set_mode("signin")
	# On a real success AuthManager emitted SIGNED_IN -> dashboard is shown.

func _show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = true

func _set_busy(busy: bool) -> void:
	_submit_btn.disabled = busy
	_submit_btn.text = "Please wait..." if busy else ("Create Account" if _mode == "signup" else "Sign In")

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, BG_TOP)
	grad.set_color(1, BG_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _make_field(label_text: String, secret: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = label_text
	label.modulate = Color(0.85, 0.9, 1.0)
	box.add_child(label)
	var edit := LineEdit.new()
	edit.name = "Edit"
	edit.custom_minimum_size = Vector2(0, 64)
	edit.secret = secret
	edit.placeholder_text = label_text
	box.add_child(edit)
	return box

func _make_tab(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(220, 56)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(1, 1, 1, 0.08)
	off.set_corner_radius_all(14)
	off.set_content_margin_all(10)
	var on := off.duplicate()
	on.bg_color = ACCENT
	btn.add_theme_stylebox_override("normal", off)
	btn.add_theme_stylebox_override("hover", off)
	btn.add_theme_stylebox_override("pressed", on)
	btn.add_theme_stylebox_override("hover_pressed", on)
	btn.add_theme_color_override("font_color", Color("ffffff"))
	btn.add_theme_color_override("font_pressed_color", Color("201600"))
	btn.add_theme_color_override("font_hover_pressed_color", Color("201600"))
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
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_font_size_override("font_size", 28)
	return btn
