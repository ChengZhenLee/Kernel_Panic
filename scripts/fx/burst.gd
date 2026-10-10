extends Node2D
## A burst of pixel particles (enemy deaths, pickups, explosions): whole-pixel squares on the world grid, no soft glow.

const Pix = preload("res://scripts/fx/pix.gd")

var parts := []  # [pos, vel, life, max_life, size, color]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(count: int, color: Color, speed := 220.0, size := 4.0, life := 0.5) -> void:
	for i in count:
		var vel := Vector2.RIGHT.rotated(randf() * TAU) * speed * randf_range(0.3, 1.0)
		var l := life * randf_range(0.6, 1.0)
		var c := color if randf() > 0.2 else Color.WHITE
		parts.append([Vector2.ZERO, vel, l, l, size * randf_range(0.6, 1.3), c])


func _process(delta: float) -> void:
	var any_alive := false
	var drag := pow(0.03, delta)
	for p in parts:
		if p[2] <= 0.0:
			continue
		p[2] -= delta
		p[0] += p[1] * delta
		p[1] *= drag
		any_alive = true
	if not any_alive:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var o := global_position   # Pix.dot() inlined: one position read for the whole burst instead of one per mark
	for p in parts:
		if p[2] <= 0.0:
			continue
		var k: float = p[2] / p[3]
		var s := maxf(2.0, roundf(p[4] * (0.4 + 0.6 * k) / 2.0) * 2.0)   # shrinks in 2 px steps
		var c: Color = p[5]
		var sz := Vector2(s, s)
		var h := sz * 0.5
		if k > 0.55 and p[1].length() > 40.0:   # a one-pixel-step trail while it is still moving fast
			draw_rect(Rect2((o + (p[0] - p[1].normalized() * s - h)).round() - o, sz), Color(c, 0.5))
		draw_rect(Rect2((o + (p[0] - h)).round() - o, sz), Color(c, 1.0 if k > 0.25 else 0.6))
