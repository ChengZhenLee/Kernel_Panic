extends Node2D
## Expanding shockwave ring, drawn in the pixel style of the weapon / ability FX: hard-edged whole-pixel squares, radius and
## thickness stepped in whole pixels, no antialiased arcs.
const Pix = preload("res://scripts/fx/pix.gd")

var color := Color.WHITE
var max_radius := 120.0
var life := 0.4
var width := 6.0
var t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	var r := roundf(max_radius * (1.0 - pow(1.0 - k, 3.0)) / 4.0) * 4.0   # grows in 4 px steps
	var a := 1.0 - k
	var s := maxf(2.0, roundf(width * a / 2.0) * 2.0)                  # thickness shrinks in 2 px steps
	Pix.ring_auto(self, Vector2.ZERO, r + s, Color(color, a * 0.3), s)    # outer pixel halo
	Pix.ring_auto(self, Vector2.ZERO, r, Color(color, a), s)
	if width >= 8.0 and a > 0.3:   # big rings get a white-hot inner edge
		Pix.ring_auto(self, Vector2.ZERO, maxf(1.0, r - s), Color(Color.WHITE, a * 0.7), 2.0)
