extends Control
# Landing screen. Port of frontend/app/index.tsx.
# Two actions: open the login screen, or start an offline guest session.
# Built programmatically so it is robust to scene-format drift.

@export var bg_top: Color = Color("081027")
@export var bg_bottom: Color = Color("0b789f")
@export var accent: Color = Color("ffd24a")

var _guest_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Globals.instance and Globals.instance.ui_theme:
		theme = Globals.instance.ui_theme

	_build_background()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(620, 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 34)
	center.add_child(vb)

	vb.add_child(_make_logo())

	var sign_btn := _make_button("Sign In / Sign Up", accent, Color("201600"))
	sign_btn.pressed.connect(func() -> void: GameManager.show_login())
	vb.add_child(sign_btn)

	_guest_btn = _make_button("Play as Guest", Color(1, 1, 1, 0.12), Color("ffffff"))
	_guest_btn.pressed.connect(_on_guest_pressed)
	vb.add_child(_guest_btn)

func _on_guest_pressed() -> void:
	_guest_btn.disabled = true
	# Guest is fully local/offline; this returns immediately and emits SIGNED_IN,
	# which GameManager handles by swapping in the dashboard (freeing this screen).
	var res := AuthManager.sign_in_anonymously()
	if not res.get("success", false) and is_instance_valid(self):
		_guest_btn.disabled = false

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, bg_top)
	grad.set_color(1, bg_bottom)
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

func _make_logo() -> Control:
	var tex = load("res://assets/logo/Logo.png")
	if tex != null:
		var logo := TextureRect.new()
		logo.texture = tex
		logo.custom_minimum_size = Vector2(0, 220)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return logo
	# Fallback text logo
	var label := Label.new()
	label.text = "TAKO"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 96)
	label.modulate = accent
	return label

func _make_button(text: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 88)
	btn.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(18)
	normal.set_content_margin_all(16)
	normal.border_color = Color("ff7d00")
	normal.set_border_width_all(3)
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
	btn.add_theme_font_size_override("font_size", 30)
	return btn
