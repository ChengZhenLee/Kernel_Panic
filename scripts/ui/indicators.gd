extends Control
const FD = preload("res://scripts/fx/fd.gd")
## Arrows on the screen edge pointing at off-screen elites and bosses.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if Global.game == null:
		return
	var xf := get_viewport().get_canvas_transform()
	var rect := Rect2(Vector2.ZERO, size).grow(-36.0)
	var center := size / 2.0
	for e in Global.game.enemy_layer.get_children():
		if not (e.elite or e.is_boss):
			continue
		if e.is_boss and e.get("hold") == true:   # a boss that is holding still (the sleeping office intern) gets no marker until it is activated
			continue
		var sp: Vector2 = xf * e.global_position
		if rect.grow(30.0).has_point(sp):
			continue
		var dir := (sp - center).normalized()
		# clamp to the rectangle edge
		var tx := (rect.size.x / 2.0) / maxf(absf(dir.x), 0.001)
		var ty := (rect.size.y / 2.0) / maxf(absf(dir.y), 0.001)
		var p := center + dir * minf(tx, ty)
		var col: Color = e.color if e.is_boss else Global.C_GOLD
		var s := 22.0 if e.is_boss else 15.0
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
		FD.circle(self, p, s * 1.4, Color(col, 0.15 * pulse))
		draw_colored_polygon(PackedVector2Array([p + dir * s, p + dir.orthogonal() * s * 0.6 - dir * s * 0.4, p - dir.orthogonal() * s * 0.6 - dir * s * 0.4]), Color(col, pulse))
		if e.is_boss:
			draw_string(Global.FONT_BODY, p - dir * 34.0 - Vector2(20, -6), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
