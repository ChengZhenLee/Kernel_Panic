extends Control
const FD = preload("res://scripts/fx/fd.gd")
## The class ability button (bottom right): the ability's icon, the cooldown as its outer ring, and its name below the ring.
## Mouse click, touch (emulated as mouse) and the Space / Q keys all use it.

signal activated

const IconArt = preload("res://scripts/icon_art.gd")

var icon_id := "core"
var color := Color.WHITE
var label := ""
var frac := 0.0       # 0 = ready, 1 = just used
var active := false   # the ability is currently running
var t := 0.0
var charges := 0
var sweet := -1.0      # sweet-spot ring progress 0..1 (-1 = closed)
var sweet_hot := false # the ring is inside the sweet spot: tap now for a SUPER cast


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# touches are handled in _input (an emulated mouse event only follows the first finger, so the joystick finger would block this button)
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()
		accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and is_visible_in_tree() and not get_tree().paused:
		if (get_global_transform() * Rect2(Vector2.ZERO, size)).has_point(event.position):
			activated.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 2.0
	var ready := frac <= 0.0
	var col := Global.C_GOLD if active else (color if ready else Color(0.6, 0.65, 0.72))
	FD.circle(self, c, r, Color(0.02, 0.04, 0.08, 0.88))
	IconArt.draw_icon(self, icon_id, c, r * 0.5, col, t, false)
	# the bounding circle is the cooldown: a dim track that fills clockwise with the recharge, fully lit when ready
	if ready or active:
		draw_arc(c, r - 1.0, 0.0, TAU, 40, Color(col, 0.95), 4.0)
	else:
		draw_arc(c, r - 1.0, 0.0, TAU, 40, Color(col, 0.25), 4.0)
		draw_arc(c, r - 1.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - frac), 40, Color(Global.C_CYAN, 0.95), 4.0)
	if sweet >= 0.0:
		var band := Color(Global.C_GOLD, 0.5 if sweet_hot else 0.28)
		draw_arc(c, r * 0.64, 0.0, TAU, 40, band, r * 0.18)
		var rr := r * (1.0 - 0.45 * sweet)
		draw_arc(c, rr, 0.0, TAU, 40, Global.C_GOLD if sweet_hot else Color(1, 1, 1, 0.85), 4.0 if sweet_hot else 2.0)
	var font: Font = Global.FONT_TITLE
	if charges > 0:
		FD.circle(self, c + Vector2(r * 0.72, -r * 0.72), 15.0, Color(0.02, 0.04, 0.08, 0.95))
		draw_arc(c + Vector2(r * 0.72, -r * 0.72), 15.0, 0.0, TAU, 20, Global.C_GOLD, 2.0)
		var cw := 30.0
		draw_string(font, c + Vector2(r * 0.72 - cw / 2.0, -r * 0.72 + 6.0), str(charges), HORIZONTAL_ALIGNMENT_CENTER, cw, 16, Global.C_GOLD)
	# the name sits under the circle (outside the control's rect, in the gap above the screen edge) so it never crosses the ring
	var fs := 13
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := c + Vector2(-w / 2.0, r + 4.0 + font.get_ascent(fs))
	draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.02, 0.04, 0.08, 0.9))
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.95))
