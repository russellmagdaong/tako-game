extends CanvasLayer
# Virtual on-screen controls for touch/mobile play.
# Attach to a CanvasLayer. Shows only on Android/mobile; hidden on desktop.
#
# Left half of screen: analog joystick → injects move_up/down/left/right actions.
# Right side: Interact button → injects the interact action.

const MAX_RADIUS   := 70.0
const DEAD_ZONE    := 14.0
const KNOB_RADIUS  := 28.0
const BASE_RADIUS  := 70.0
const BTN_SIZE     := 80.0

var _joystick_base: Control
var _joystick_knob: Control
var _interact_btn: Button

var _touch_id: int = -1
var _touch_origin: Vector2 = Vector2.ZERO
var _active_directions: Array[String] = []

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = OS.has_feature("mobile") or OS.has_feature("android")
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Joystick base (hidden until touch)
	_joystick_base = _make_circle(BASE_RADIUS * 2, Color(1, 1, 1, 0.15))
	_joystick_base.visible = false
	root.add_child(_joystick_base)

	# Joystick knob
	_joystick_knob = _make_circle(KNOB_RADIUS * 2, Color(1, 1, 1, 0.45))
	_joystick_knob.visible = false
	root.add_child(_joystick_knob)

	# Interact button — bottom-right corner
	_interact_btn = Button.new()
	_interact_btn.text = "E"
	_interact_btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	_interact_btn.anchor_right  = 1.0
	_interact_btn.anchor_bottom = 1.0
	_interact_btn.anchor_left   = 1.0
	_interact_btn.anchor_top    = 1.0
	_interact_btn.offset_left   = -(BTN_SIZE + 24.0)
	_interact_btn.offset_top    = -(BTN_SIZE + 24.0)
	_interact_btn.offset_right  = -24.0
	_interact_btn.offset_bottom = -24.0
	_interact_btn.button_down.connect(_on_interact_down)
	_interact_btn.button_up.connect(_on_interact_up)
	root.add_child(_interact_btn)

func _make_circle(diameter: float, color: Color) -> Control:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(diameter, diameter)
	c.size = Vector2(diameter, diameter)
	return c

func _on_interact_down() -> void:
	Input.action_press("interact")

func _on_interact_up() -> void:
	Input.action_release("interact")

func _input(event: InputEvent) -> void:
	if not visible or SceneManager.is_battling:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_update_direction(event.position)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var half_w := get_viewport().get_visible_rect().size.x / 2.0
	if event.pressed and _touch_id == -1 and event.position.x < half_w:
		_touch_id = event.index
		_touch_origin = event.position
		_joystick_base.position = _touch_origin - _joystick_base.size / 2
		_joystick_knob.position = _touch_origin - _joystick_knob.size / 2
		_joystick_base.visible = true
		_joystick_knob.visible = true
	elif not event.pressed and event.index == _touch_id:
		_touch_id = -1
		_joystick_base.visible = false
		_joystick_knob.visible = false
		_release_all()

func _update_direction(pos: Vector2) -> void:
	var delta := pos - _touch_origin
	var dist  := delta.length()
	var clamped := _touch_origin + delta.normalized() * minf(dist, MAX_RADIUS)
	_joystick_knob.position = clamped - _joystick_knob.size / 2

	if dist < DEAD_ZONE:
		_release_all()
		return

	var dir := delta.normalized()
	var new_dirs: Array[String] = []
	if absf(dir.x) >= absf(dir.y):
		new_dirs.append("move_right" if dir.x > 0 else "move_left")
	else:
		new_dirs.append("move_down" if dir.y > 0 else "move_up")

	for d in _active_directions:
		if not new_dirs.has(d):
			Input.action_release(d)
	for d in new_dirs:
		if not _active_directions.has(d):
			Input.action_press(d)
	_active_directions = new_dirs

func _release_all() -> void:
	for d in _active_directions:
		Input.action_release(d)
	_active_directions.clear()
