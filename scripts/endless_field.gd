extends Node2D
## THE INTERNET's floor: infinite, with walls scattered in chunks. Each chunk's walls come from a hash of its coordinates, so
## the same place always has the same walls and nothing needs storing. Same interface as arena.gd, but there is no boundary
## and no flow-field grid (threats feel their way around a wall instead).

const MapsData = preload("res://scripts/maps_data.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const TILE := 128.0           # wall art tile (= MapsData.TILE); every wall sits on this grid
const EDGE_W := 10.0
const STYLES := [0, 1, 2, 3, 4, 5, 6, 7, 8]   # wall styles in play: the 8 devices (1 = phone app icons) plus the firewall bricks (8)
const EDGES := [["#c8e8f2", "#1d3a48"], ["#ffffff", "#0a0e24"], ["#b8bed6", "#1a1a28"], ["#aab4c8", "#181e2c"],
	["#d8dce2", "#14141a"], ["#d0daee", "#0c2048"], ["#f0e8cc", "#5a5440"], ["#ffffff", "#5a46c0"], ["#ffd0a0", "#3a0e0a"]]
const CHUNK := 2400.0
const SAFE_RADIUS := 1000.0   # no walls this close to where you start
const DRAW_RANGE := 1300.0

var bounded := false
var color := Color(0.4, 0.95, 0.85)
var start := Vector2.ZERO
var seed_value := 0
var cache := {}   # Vector2i -> Array of Rect2
var player
var style_tex := {}   # tier -> {"tex", "v"} or {"icons"}


func setup(pal: Color) -> void:
	color = pal
	seed_value = randi()
	for tier in STYLES:
		if tier == 1:
			var icons := []
			for i in 24:
				var t: Texture2D = PixelArt.load_tex("tiles/icon_1_%d.png" % i)
				if t == null:
					break
				icons.append(t)
			if not icons.is_empty():
				style_tex[1] = {"icons": icons}
			continue
		var tex: Texture2D = PixelArt.load_tex("tiles/wall_%d.png" % tier)
		if tex != null:
			var d := {"tex": tex}
			var tv: Texture2D = PixelArt.load_tex("tiles/wall_%d_v.png" % tier)
			if tv != null:
				d["v"] = tv
			style_tex[tier] = d


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
		var wr := MapsData.snap_rect(Rect2(pos, size))   # on the art grid, like the device maps
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


## No edge here, so nothing to clamp (arena.gd keeps you inside its map).
func clamp_to_bounds(p: Vector2, _r: float) -> Vector2:
	return p


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
	var visible := []
	for w in walls_near(player.global_position, DRAW_RANGE):
		if view.intersects(w):
			visible.append(w)
	if style_tex.size() == STYLES.size():
		_draw_art_walls(visible)
		return
	for w in visible:
		var wr: Rect2 = w
		draw_rect(wr, Color(0.03, 0.05, 0.09))
		draw_rect(wr, Color(color, 0.8), false, 5.0)
		draw_rect(wr.grow(-14.0), Color(color, 0.12))


## THE INTERNET is a melting pot: every wall takes one of the device wall styles (phone app icons included), picked by its position.
## Cell-union drawing like arena.gd: one tile per grid cell (first wall to claim a cell wins, so overlaps never double-draw),
## bevel only on edges that face open floor, in the style's own edge colours.
func _wall_style(rect: Rect2) -> int:
	return absi(hash(Vector2i(roundi(rect.position.x / TILE), roundi(rect.position.y / TILE)))) % STYLES.size()


func _draw_art_walls(list: Array) -> void:
	var cells := {}    # Vector2i -> style index
	var vert := {}     # Vector2i -> true when the cell belongs to a tall wall
	for r in list:
		var rect: Rect2 = r
		var st := _wall_style(rect)
		var tall := rect.size.y > rect.size.x
		for cx in range(roundi(rect.position.x / TILE), roundi(rect.end.x / TILE)):
			for cy in range(roundi(rect.position.y / TILE), roundi(rect.end.y / TILE)):
				var k := Vector2i(cx, cy)
				if not cells.has(k):
					cells[k] = st
					if tall:
						vert[k] = true
	for k in cells:
		var tier: int = STYLES[cells[k]]
		var box := Rect2(Vector2(k) * TILE, Vector2(TILE, TILE))
		var set: Dictionary = style_tex[tier]
		if set.has("icons"):
			var icons: Array = set["icons"]
			draw_rect(box, Color("#14183a"))
			var ib := box.grow(-6.0)
			draw_rect(Rect2(ib.position + Vector2(10.0, 14.0), ib.size), Color(0.0, 0.0, 0.0, 0.4))
			draw_texture_rect(icons[absi(hash(k)) % icons.size()], ib, false)
		else:
			var tex: Texture2D = set["v"] if (vert.has(k) and set.has("v")) else set["tex"]
			draw_texture_rect(tex, box, false)
	for k in cells:
		var o := Vector2(k) * TILE
		var tier: int = STYLES[cells[k]]
		if tier == 1:   # app icons carry no bevel (the white edge would sit on top of them)
			continue
		var lt := Color(EDGES[tier][0])
		var dk := Color(EDGES[tier][1])
		if not cells.has(k + Vector2i(0, -1)):
			draw_rect(Rect2(o, Vector2(TILE, EDGE_W)), lt)
		if not cells.has(k + Vector2i(-1, 0)):
			draw_rect(Rect2(o, Vector2(EDGE_W, TILE)), lt)
		if not cells.has(k + Vector2i(0, 1)):
			draw_rect(Rect2(o + Vector2(0.0, TILE - EDGE_W), Vector2(TILE, EDGE_W)), dk)
		if not cells.has(k + Vector2i(1, 0)):
			draw_rect(Rect2(o + Vector2(TILE - EDGE_W, 0.0), Vector2(EDGE_W, TILE)), dk)
