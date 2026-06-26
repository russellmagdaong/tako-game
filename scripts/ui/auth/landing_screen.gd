extends Control

var _guest_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Globals.instance and Globals.instance.ui_theme:
		theme = Globals.instance.ui_theme

	_guest_btn = get_node("%GuestButton")
	get_node("%SignInButton").pressed.connect(func() -> void: GameManager.show_login())
	_guest_btn.pressed.connect(_on_guest_pressed)

func _on_guest_pressed() -> void:
	_guest_btn.disabled = true
	var res := AuthManager.sign_in_anonymously()
	if not res.get("success", false) and is_instance_valid(self):
		_guest_btn.disabled = false
