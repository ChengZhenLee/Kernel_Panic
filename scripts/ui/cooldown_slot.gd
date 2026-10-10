extends Control
const FD = preload("res://scripts/fx/fd.gd")
## One slot in the HUD's top-left item cooldown row: the item's icon with a dark sweep for the
## time left (item.cd_frac(): 0 = ready, 1 = just used) and a red glow while it is active.

const IconArt = preload("res://scripts/icon_art.gd")

var item: Node
var icon_id := "core"
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(item):
		return
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var frac: float = item.cd_frac()
	var active: bool = item.has_method("is_active") and item.is_active()
	var col := Global.C_RED if active else (Global.C_GREEN if frac <= 0.0 else Color(0.6, 0.7, 0.75))
	FD.circle(self, c, r, Color(0.02, 0.04, 0.08, 0.85))
	IconArt.draw_icon(self, icon_id, c, r * 0.62, col, t)
	if frac > 0.0 and not active:
		# a thick arc reads as a pie sweep and never degenerates like a tiny polygon would
		draw_arc(c, r * 0.5, -PI / 2.0, -PI / 2.0 + TAU * frac, 24, Color(0, 0, 0, 0.55), r)
	draw_arc(c, r - 1.0, 0.0, TAU, 32, Color(col, 0.9 if frac <= 0.0 or active else 0.4), 2.0)
