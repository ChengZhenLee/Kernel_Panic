extends Node2D
## THE INTERNET's floor: infinite, with walls scattered in chunks. Each chunk's walls come from a hash of its coordinates, so
## the same place always has the same walls and nothing needs storing. Same interface as arena.gd, but there is no boundary
## and no flow-field grid (threats feel their way around a wall instead).

const CHUNK := 2400.0
const SAFE_RADIUS := 1000.0   # no walls this close to where you start
const DRAW_RANGE := 1300.0

var bounded := false
var color := Color(0.4, 0.95, 0.85)
var start := Vector2.ZERO
var seed_value := 0
var cache := {}   # Vector2i -> Array of Rect2
var player


func setup(pal: Color) -> void:
	color = pal
	seed_value = randi()


func _chunk_walls(c: Vector2i) -> Array:
	if cache.has(c):
		return cache[c]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(c.x * 7919 + seed_value, c.y * 104729 - seed_value))
	var list := []
	var origin := Vector2(c) * CHUNK
	for i in rng.randi_range(1, 6):
		var shape := rng.randi() % 3
		var size: Vector2
		if shape == 0:
			size = Vector2(rng.randf_range(650.0, 1400.0), rng.randf_range(100.0, 160.0))
		elif shape == 1:
			size = Vector2(rng.randf_range(100.0, 160.0), rng.randf_range(650.0, 1400.0))
		else:
			size = Vector2(rng.randf_range(270.0, 575.0), rng.randf_range(270.0, 575.0))
		var pos := origin + Vector2(rng.randf_range(160.0, CHUNK - 160.0 - size.x), rng.randf_range(160.0, CHUNK - 160.0 - size.y))
		var wr := Rect2(pos, size)
		if wr.grow(SAFE_RADIUS).has_point(start):
			continue
		list.append(wr)
	cache[c] = list
	return list


func _chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


## Walls within r of p.
func walls_near(p: Vector2, r: float) -> Array:
	var a := _chunk_of(p - Vector2(r, r))
	var b := _chunk_of(p + Vector2(r, r))
	var out := []
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			out.append_array(_chunk_walls(Vector2i(cx, cy)))
	return out


func active_walls() -> Array:
	if player == null or not is_instance_valid(player):
		return []
	return walls_near(player.global_position, 1400.0)


func _process(_delta: float) -> void:
	queue_redraw()
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func push_out(p: Vector2, r: float) -> Vector2:
	for w in walls_near(p, r):
		var wr: Rect2 = w
		if p.x < wr.position.x - r or p.x > wr.end.x + r or p.y < wr.position.y - r or p.y > wr.end.y + r:
			continue
		var cp := Vector2(clampf(p.x, wr.position.x, wr.end.x), clampf(p.y, wr.position.y, wr.end.y))
		var off := p - cp
		var d := off.length()
		if d >= r:
			continue
		if d > 0.001:
			p = cp + off / d * r
		else:
			var left := p.x - wr.position.x
			var right := wr.end.x - p.x
			var up := p.y - wr.position.y
			var down := wr.end.y - p.y
			var m := minf(minf(left, right), minf(up, down))
			if m == left:
				p.x = wr.position.x - r
			elif m == right:
				p.x = wr.end.x + r
			elif m == up:
				p.y = wr.position.y - r
			else:
				p.y = wr.end.y + r
	return p


func point_blocked(p: Vector2) -> bool:
	for w in _chunk_walls(_chunk_of(p)):
		if (w as Rect2).has_point(p):
			return true
	return false


func clip_move(a: Vector2, b: Vector2, r: float) -> Vector2:
	var steps := maxi(1, int(a.distance_to(b) / 16.0))
	var last := a
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if push_out(p, r).distance_to(p) > 0.5:
			return last
		last = p
	return b


func has_los(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, int(a.distance_to(b) / 40.0))
	for i in range(1, steps):
		if point_blocked(a.lerp(b, float(i) / steps)):
			return false
	return true


func has_los_path(a: Vector2, b: Vector2) -> bool:
	return has_los(a, b)


func is_open(p: Vector2) -> bool:
	return not point_blocked(p) and push_out(p, 24.0).distance_to(p) < 0.5


func random_open_point(center: Vector2, rmin: float, rmax: float) -> Vector2:
	for i in 14:
		var p := center + Vector2.from_angle(randf() * TAU) * randf_range(rmin, rmax)
		if is_open(p):
			return p
	return nearest_open(center + Vector2.from_angle(randf() * TAU) * rmax)


func nearest_open(p: Vector2) -> Vector2:
	if is_open(p):
		return p
	var ring := 40.0
	while ring < 1200.0:
		for i in 12:
			var q := p + Vector2.from_angle(TAU * i / 12.0) * ring
			if is_open(q):
				return q
		ring += 40.0
	return p


## Called when a threat has no line of sight: steer toward the player, swerving to the first side that is clear.
func flow_dir(p: Vector2) -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	var dir: Vector2 = (player.global_position - p).normalized()
	for off in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var d: Vector2 = dir.rotated(off)
		if is_open(p + d * 70.0):
			return d
	return Vector2.ZERO


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var view := Rect2(player.global_position - Vector2(DRAW_RANGE, DRAW_RANGE), Vector2(DRAW_RANGE, DRAW_RANGE) * 2.0)
	for w in walls_near(player.global_position, DRAW_RANGE):
		var wr: Rect2 = w
		if not view.intersects(wr):
			continue
		draw_rect(wr, Color(0.03, 0.05, 0.09))
		draw_rect(wr, Color(color, 0.8), false, 5.0)
		draw_rect(wr.grow(-14.0), Color(color, 0.12))
