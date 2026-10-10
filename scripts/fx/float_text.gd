extends Node2D
## Pop-up text: damage numbers, "+HP", combo callouts.

var text := ""
var color := Color.WHITE
var font_size := 24
var life := 0.7
var t := 0.0
var vel := Vector2(0, -70)


func _ready() -> void:
	z_index = 60
	vel.x = randf_range(-35.0, 35.0)


func _process(delta: float) -> void:
	t += delta
	position += vel * delta
	vel.y += 120.0 * delta
	if t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := t / life
	var pop := 1.0 + 0.8 * maxf(0.0, 1.0 - t * 9.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
	var font: Font = Global.FONT_BODY
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var a := 1.0 - k * k
	draw_string_outline(font, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, a))
	draw_string(font, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, a))
