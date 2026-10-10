extends Control
const FD = preload("res://scripts/fx/fd.gd")
## Floating virtual joystick: touch anywhere (outside buttons) to place it, drag to move.
## On desktop it also works with a mouse drag, so you can try the mobile controls on PC.

var RADIUS := 90.0   # scaled by the UI size setting

var active := false
var touch_index := -1
var base := Vector2.ZERO
var knob := Vector2.ZERO
var blockers: Array[Control] = []   # buttons the joystick must not steal touches from
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RADIUS = 90.0 * Global.get_ui_scale()


func _blocked(pos: Vector2) -> bool:
	if get_tree().paused:
		return true
	for b in blockers:
		if b.is_visible_in_tree() and (b.get_global_transform() * Rect2(Vector2.ZERO, b.size)).grow(10.0).has_point(pos):
			return true
	return false


func release() -> void:
	active = false
	touch_index = -1
	Global.joystick_vec = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		if active:
			release()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not active and not _blocked(event.position):
			_start(event.position)
			touch_index = event.index
		elif not event.pressed and event.index == touch_index:
			release()
	elif event is InputEventScreenDrag:
		if active and event.index == touch_index:
			_move(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not active and not _blocked(event.position):
			_start(event.position)
			touch_index = -2
		elif not event.pressed and touch_index == -2:
			release()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if active and touch_index == -2:
			_move(event.position)


func _start(pos: Vector2) -> void:
	active = true
	base = pos
	knob = pos
	Global.joystick_vec = Vector2.ZERO


func _move(pos: Vector2) -> void:
	var off := pos - base
	if off.length() > RADIUS * 1.6:  # drag the base along so the stick never "runs out"
		base = pos - off.normalized() * RADIUS * 1.6
		off = pos - base
	knob = base + off.limit_length(RADIUS)
	var v := off / RADIUS
	Global.joystick_vec = v.limit_length(1.0) if v.length() > 0.12 else Vector2.ZERO


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if not active:
		if Global.is_touch and not get_tree().paused:
			var p := Vector2(size.x - 150 if Global.swap_controls else 150, size.y - 150)
			var a := 0.18 + 0.08 * sin(t * 2.0)
			draw_arc(p, RADIUS, 0.0, TAU, 48, Color(Global.C_CYAN, a), 3.0)
			FD.circle(self, p, 34.0, Color(Global.C_CYAN, a * 0.6))
		return
	var col := Global.C_CYAN
	FD.circle(self, base, RADIUS, Color(col, 0.08))
	draw_arc(base, RADIUS, 0.0, TAU, 48, Color(col, 0.55), 3.0)
	draw_line(base, knob, Color(col, 0.35), 6.0)
	FD.circle(self, knob, 38.0, Color(col, 0.3))
	draw_arc(knob, 38.0, 0.0, TAU, 32, Color(0.85, 1.0, 1.0, 0.9), 3.0)
