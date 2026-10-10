extends Control
const FD = preload("res://scripts/fx/fd.gd")
## Radar: a window around the player showing nearby walls, plus arrows at the edge pointing to points of interest
## (the boss, caches, elites). Everything fades in as it comes into range. Works on the open Internet too.

const RANGE := 1300.0       # world pixels from the player to the edge of the radar

var arena
var player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var c := size / 2.0
	var half := minf(size.x, size.y) / 2.0 - 4.0
	var k := half / RANGE
	var ppos: Vector2 = player.global_position
	var col := Global.C_CYAN
	FD.circle(self, c, half, Color(0.02, 0.04, 0.08, 0.6))
	if arena != null and is_instance_valid(arena):
		var wcol: Color = arena.color
		for w in arena.active_walls():
			var wr: Rect2 = w
			var a: Vector2 = (wr.position - ppos) * k
			var b: Vector2 = (wr.end - ppos) * k
			if b.x < -half or a.x > half or b.y < -half or a.y > half:
				continue
			# clamp the wall to the radar square, then keep what falls inside the circle
			var ra := Vector2(clampf(a.x, -half * 0.8, half * 0.8), clampf(a.y, -half * 0.8, half * 0.8))
			var rb := Vector2(clampf(b.x, -half * 0.8, half * 0.8), clampf(b.y, -half * 0.8, half * 0.8))
			draw_rect(Rect2(c + ra, rb - ra), Color(wcol, 0.85))
	draw_arc(c, half, 0.0, TAU, 48, Color(col, 0.55), 2.0)
	FD.circle(self, c, 4.0, col)
	var pois := _points()
	for p in pois:
		var off: Vector2 = (p[0] - ppos)
		var colr: Color = p[1]
		var d := off.length()
		if d < RANGE * 0.93:
			FD.circle(self, c + off * k, 3.5, colr)
		else:
			var dir := off / maxf(d, 1.0)
			var tip := c + dir * (half - 2.0)
			var base := c + dir * (half - 14.0)
			var side := dir.orthogonal() * 6.0
			draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), colr)


## [world position, colour] for the boss, caches and elites.
func _points() -> Array:
	var out := []
	var game = Global.game
	if game == null:
		return out
	if is_instance_valid(game.current_boss):
		out.append([game.current_boss.global_position, Global.C_RED])
	for p in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(p) and p.kind == "cache":
			out.append([p.global_position, Global.C_GOLD])
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.elite and not e.is_boss:
			out.append([e.global_position, Color(1.0, 0.55, 0.15)])
	return out
