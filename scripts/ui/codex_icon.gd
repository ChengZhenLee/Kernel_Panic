extends Control
const FD = preload("res://scripts/fx/fd.gd")
## Codex icon: a polygon in the entry's colour (or a ring for elite modifiers). Unseen entries are drawn as a black silhouette with "?".

var sides := 3
var color := Color.WHITE
var seen := true


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.4
	var fill := color if seen else Color(0.02, 0.02, 0.03)
	var edge := color.lightened(0.3) if seen else Color(0.3, 0.33, 0.4)
	if sides == 0:
		FD.circle(self, c, r, Color(fill, 0.25) if seen else fill)
		draw_arc(c, r, 0.0, TAU, 32, edge, 4.0)
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a) * (r + 7.0), edge, 3.0)
	else:
		var pts := PackedVector2Array()
		for i in sides:
			pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / sides) * r)
		draw_colored_polygon(pts, Color(fill, 0.85) if seen else fill)
		pts.append(pts[0])
		draw_polyline(pts, edge, 3.0)
		if seen:
			FD.circle(self, c + Vector2(-r * 0.3, -r * 0.1), 3.0, Color.BLACK)
			FD.circle(self, c + Vector2(r * 0.3, -r * 0.1), 3.0, Color.BLACK)
	if not seen:
		var font: Font = Global.FONT_TITLE
		draw_string(font, c + Vector2(-8, 9), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.5, 0.55, 0.65))
