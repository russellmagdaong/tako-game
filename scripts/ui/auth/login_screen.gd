extends Control

var _mode: String = "signin"

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

	_signin_tab    = get_node("%SigninTab")
	_signup_tab    = get_node("%SignupTab")
	_username_field = get_node("%UsernameField")
	_username_edit = get_node("%UsernameEdit")
	_email_edit    = get_node("%EmailEdit")
	_password_edit = get_node("%PasswordEdit")
	_error_label   = get_node("%ErrorLabel")
	_submit_btn    = get_node("%SubmitButton")

	_signin_tab.pressed.connect(func() -> void: _set_mode("signin"))
	_signup_tab.pressed.connect(func() -> void: _set_mode("signup"))
	_submit_btn.pressed.connect(_on_submit)
	get_node("CenterContainer/Card/BackButton").pressed.connect(
		func() -> void: GameManager.show_landing()
	)

	_set_mode("signin")

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

	if not is_instance_valid(self):
		return

	_set_busy(false)

	if not res.get("success", false):
		_show_error(res.get("error", "Something went wrong."))
		return

	if res.get("needs_confirmation", false):
		_show_error("Account created. Please confirm your email, then sign in.")
		_set_mode("signin")

func _show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = true

func _set_busy(busy: bool) -> void:
	_submit_btn.disabled = busy
	_submit_btn.text = "Please wait..." if busy else ("Create Account" if _mode == "signup" else "Sign In")
