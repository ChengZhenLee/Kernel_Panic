extends Control
## A Control that shows one animated vector icon, or an animated class sprite when sprite is set.

const IconArt = preload("res://scripts/icon_art.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")

var icon_id := "core"
var color := Color.WHITE
var sprite: Texture2D = null   # a class avatar strip (PixelArt.draw_class); wins over icon_id when set
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if sprite != null:
		PixelArt.draw_class(self, sprite, size / 2.0, minf(size.x, size.y), t)
		return
	var s := minf(size.x, size.y) * 0.42
	IconArt.draw_icon(self, icon_id, size / 2.0, s, color, t)
