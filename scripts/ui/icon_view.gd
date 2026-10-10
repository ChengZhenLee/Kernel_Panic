extends Control
## A Control that shows one animated vector icon.

const IconArt = preload("res://scripts/icon_art.gd")

var icon_id := "core"
var color := Color.WHITE
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) * 0.42
	IconArt.draw_icon(self, icon_id, size / 2.0, s, color, t)
