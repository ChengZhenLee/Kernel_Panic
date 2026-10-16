extends Node2D
## A fixed arena with walls (maps_data.gd). Handles wall drawing, circle-vs-wall collision, a coarse grid used for
## line of sight and a flow field so enemies path around walls. Not used on THE INTERNET (open endless floor).

const MapsData = preload("res://scripts/maps_data.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const CELL := 120.0
const PAD := 14.0            # walls are treated as this much thicker for pathing
const FLOW_INTERVAL := 0.4

var bounded := true
var bounds := Rect2()
var start := Vector2.ZERO
var walls: Array = []        # static Rect2s
var phase_a: Array = []
var phase_b: Array = []
var phase_on := 0            # 0: set A is solid, 1: set B is solid (only when phase sets exist)
var phase_t := 0.0
var color := Color.WHITE
var wall_tex: Texture2D = null   # art/tiles/wall_<tier>.png: one 128 px tile per grid cell of wall
var wall_tex_v: Texture2D = null # optional wall_<tier>_v.png: the same tile turned for vertical walls
var icon_index := {}               # wall position -> icon art index, to give chosen blocks their own icon
var skip_icons: Array = []        # wall rects whose icon is drawn by someone else (the corrupted app)
var icon_tex: Array = []         # art/tiles/icon_<tier>_<i>.png: walls made of whole icons (the phone's app icons), one per block
var edge_light := Color.WHITE    # bevel on the exposed top / left edges of a wall
var edge_dark := Color.BLACK     # and on the bottom / right edges
const ICON_INSET := 8.0           # app icons are drawn this far inside their hitbox (secret_rooms.gd uses the same)
const TILE := 128.0              # = MapsData.TILE
const EDGE_W := 10.0
## wall bevel colours per device: [light, dark], matching each wall's art
const EDGES := [["#c8e8f2", "#1d3a48"], ["#ffffff", "#0a0e24"], ["#b8bed6", "#1a1a28"], ["#aab4c8", "#181e2c"],
	["#d8dce2", "#14141a"], ["#d0daee", "#0c2048"], ["#f0e8cc", "#5a5440"], ["#ffffff", "#5a46c0"]]

var cols := 0
var rows := 0
var blocked := PackedByteArray()   # cell touches a wall
var near := PackedByteArray()      # cell is within ~one cell of a wall (collision tests only run here)
var dist := PackedInt32Array()     # flow field: path cost to the player (-1 = unreachable)
var open_cells: Array = []
var flow_timer := 0.0
var flow_goal := Vector2i(-9999, -9999)
var player


## room = true builds the device's boss room instead, centred on origin (far from the main arena).
func setup(tier: int, pal: Color, room := false, origin := Vector2.ZERO, layout := {}) -> void:
	var d: Dictionary = layout if not layout.is_empty() else (MapsData.room(tier) if room else MapsData.layout(tier))
	var size: Vector2 = d["size"]
	bounds = Rect2(-size / 2.0 + origin, size)
	start = Vector2(d["start"]) + origin
	walls = _shift(d["walls"], origin)
	phase_a = _shift(d.get("phase_a", []), origin)
	phase_b = _shift(d.get("phase_b", []), origin)
	color = pal
	_load_wall_art(tier % 8)
	cols = int(ceil(size.x / CELL))
	rows = int(ceil(size.y / CELL))
	_rebuild_grid()


func _shift(list: Array, origin: Vector2) -> Array:
	var out := []
	for w in list:
		var wr: Rect2 = w
		out.append(Rect2(wr.position + origin, wr.size))
	return out


## Switches the arena on or off (the inactive one neither draws nor path-finds).
func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	if on:
		flow_goal = Vector2i(-9999, -9999)
		flow_timer = 0.0


func has_phase() -> bool:
	return not phase_a.is_empty()


func active_walls() -> Array:
	if not has_phase():
		return walls
	return walls + (phase_a if phase_on == 0 else phase_b)


func _cell_rect(cx: int, cy: int) -> Rect2:
	return Rect2(bounds.position + Vector2(cx, cy) * CELL, Vector2(CELL, CELL))


func _idx(cx: int, cy: int) -> int:
	return cy * cols + cx


func cell_of(p: Vector2) -> Vector2i:
	var q := (p - bounds.position) / CELL
	return Vector2i(clampi(int(floor(q.x)), 0, cols - 1), clampi(int(floor(q.y)), 0, rows - 1))


func _rebuild_grid() -> void:
	blocked.resize(cols * rows)
	near.resize(cols * rows)
	blocked.fill(0)
	near.fill(0)
	var all: Array = walls + phase_a + phase_b
	for w in all:
		var wr: Rect2 = w
		var a := cell_of(wr.position - Vector2(CELL * 2, CELL * 2))
		var b := cell_of(wr.end + Vector2(CELL * 2, CELL * 2))
		for cy in range(a.y, b.y + 1):
			for cx in range(a.x, b.x + 1):
				near[_idx(cx, cy)] = 1
	_rebuild_blocked()
	if not has_phase():
		_seal_pockets()
	open_cells.clear()
	for cy in rows:
		for cx in cols:
			if blocked[_idx(cx, cy)] == 0:
				open_cells.append(Vector2i(cx, cy))
	flow_goal = Vector2i(-9999, -9999)


## Marks open pockets that cannot be reached from the start as blocked, so nothing ever spawns in them.
func _seal_pockets() -> void:
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var s := cell_of(start)
	var queue: Array = [s]
	seen[_idx(s.x, s.y)] = 1
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			var ni := _idx(n.x, n.y)
			if seen[ni] == 0 and blocked[ni] == 0:
				seen[ni] = 1
				queue.append(n)
	for i in cols * rows:
		if seen[i] == 0:
			blocked[i] = 1


## Blocked cells use the currently solid walls only.
func _rebuild_blocked() -> void:
	blocked.fill(0)
	for w in active_walls():
		var wr: Rect2 = (w as Rect2).grow(PAD)
		var a := cell_of(wr.position)
		var b := cell_of(wr.end)
		for cy in range(a.y, b.y + 1):
			for cx in range(a.x, b.x + 1):
				if _cell_rect(cx, cy).intersects(wr):
					blocked[_idx(cx, cy)] = 1
	# the outer ring of cells is blocked too (bounds clamp keeps bodies off it)
	for cx in cols:
		blocked[_idx(cx, 0)] = 1
		blocked[_idx(cx, rows - 1)] = 1
	for cy in rows:
		blocked[_idx(0, cy)] = 1
		blocked[_idx(cols - 1, cy)] = 1


func _process(delta: float) -> void:
	queue_redraw()
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	if has_phase():
		phase_t += delta
		if phase_t >= MapsData.PHASE_TIME:
			phase_t = 0.0
			phase_on = 1 - phase_on
			_rebuild_blocked()
			flow_goal = Vector2i(-9999, -9999)
	flow_timer -= delta
	if flow_timer <= 0.0:
		flow_timer = FLOW_INTERVAL
		_rebuild_flow(player.global_position)


# ---------- collision ----------

## Pushes a circle out of walls and keeps it inside the arena.
## Keeps a body inside the arena edge (walls are ignored; a phased Ghost uses this alone).
func clamp_to_bounds(p: Vector2, r: float) -> Vector2:
	return Vector2(clampf(p.x, bounds.position.x + r, bounds.end.x - r), clampf(p.y, bounds.position.y + r, bounds.end.y - r))


func push_out(p: Vector2, r: float) -> Vector2:
	p = clamp_to_bounds(p, r)
	var c := cell_of(p)
	if near[_idx(c.x, c.y)] == 0:
		return p
	for w in active_walls():
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
		else:   # centre is inside the wall: leave through the nearest face
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


## True if a point (a bullet) is inside a wall or outside the arena.
func point_blocked(p: Vector2) -> bool:
	if not bounds.has_point(p):
		return true
	var c := cell_of(p)
	if near[_idx(c.x, c.y)] == 0:
		return false
	for w in active_walls():
		if (w as Rect2).has_point(p):
			return true
	return false


## Moves from a to b in small steps and stops at the first wall (used by dashes).
func clip_move(a: Vector2, b: Vector2, r: float) -> Vector2:
	var n := int(ceil(a.distance_to(b) / 24.0))
	var last := a
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		if push_out(p, r).distance_to(p) > 0.5:
			return last
		last = p
	return b


# ---------- line of sight, spawning ----------

## Exact line of sight against the solid wall rectangles (not the coarse path grid, which marks whole cells beside a wall as
## blocked and made weapons stop firing whenever the player hugged a wall).
func has_los(a: Vector2, b: Vector2) -> bool:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	for w in active_walls():
		var wr: Rect2 = w
		if wr.end.x < lo.x or wr.position.x > hi.x or wr.end.y < lo.y or wr.position.y > hi.y:
			continue
		if _segment_hits_rect(a, b, wr):
			return false
	return true


## Coarse, padded line of sight for movement: threats only walk straight at you when the whole path is clear of the wall padding.
func has_los_path(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / 28.0))
	for i in range(1, n):
		var c := cell_of(a.lerp(b, float(i) / n))
		if blocked[_idx(c.x, c.y)] != 0:
			return false
	return true


func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var da: float = d[axis]
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		var pa: float = a[axis]
		if absf(da) < 0.0001:
			if pa < lo or pa > hi:
				return false
		else:
			var ta := (lo - pa) / da
			var tb := (hi - pa) / da
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true


func is_open(p: Vector2) -> bool:
	if not bounds.has_point(p):
		return false
	var c := cell_of(p)
	return blocked[_idx(c.x, c.y)] == 0


## A random open point between rmin and rmax from center (falls back to any open cell far enough away).
func random_open_point(center: Vector2, rmin: float, rmax: float) -> Vector2:
	for i in 14:
		var p := center + Vector2.from_angle(randf() * TAU) * randf_range(rmin, rmax)
		if is_open(p):
			return p
	for i in 40:
		var cell: Vector2i = open_cells.pick_random()
		var q := bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
		if q.distance_to(center) >= rmin * 0.7:
			return q
	return nearest_open(center)


## The closest open spot to p (searches outward cell by cell).
func nearest_open(p: Vector2) -> Vector2:
	if is_open(p):
		return p
	var c := cell_of(p)
	for ring in range(1, 40):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var cx := c.x + dx
				var cy := c.y + dy
				if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
					continue
				if blocked[_idx(cx, cy)] == 0:
					return bounds.position + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * CELL + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	return start


# ---------- flow field ----------

func _rebuild_flow(goal_pos: Vector2) -> void:
	var g := cell_of(goal_pos)
	if g == flow_goal:
		return
	flow_goal = g
	var n := cols * rows
	if dist.size() != n:
		dist.resize(n)
	dist.fill(-1)
	# the player's own cell may be flagged blocked (standing next to a wall): start from the nearest open cell
	var start_cell := g
	if blocked[_idx(g.x, g.y)] != 0:
		var best := 1 << 30
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var cx := g.x + dx
				var cy := g.y + dy
				if cx < 0 or cy < 0 or cx >= cols or cy >= rows or blocked[_idx(cx, cy)] != 0:
					continue
				if dx * dx + dy * dy < best:
					best = dx * dx + dy * dy
					start_cell = Vector2i(cx, cy)
	# Dial's algorithm with circular buckets (max step cost is 14, so 15 buckets suffice); cells are flat indices.
	# This runs over every cell of a big arena each time the player changes cell, so it avoids dictionaries and Vector2i.
	var buckets: Array = []
	for i in 15:
		buckets.append(PackedInt32Array())
	var start_i := _idx(start_cell.x, start_cell.y)
	dist[start_i] = 0
	buckets[0].append(start_i)
	var pending := 1
	var cost := 0
	var w := cols
	while pending > 0:
		var list: PackedInt32Array = buckets[cost % 15]
		buckets[cost % 15] = PackedInt32Array()
		pending -= list.size()
		for ci in list:
			if dist[ci] != cost:
				continue
			var cx := ci % w
			var cy := ci / w
			for dy in range(-1, 2):
				var ny := cy + dy
				if ny < 0 or ny >= rows:
					continue
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := cx + dx
					if nx < 0 or nx >= w:
						continue
					var ni := ny * w + nx
					if blocked[ni] != 0:
						continue
					var nc := cost + 10
					if dx != 0 and dy != 0:
						if blocked[cy * w + nx] != 0 or blocked[ny * w + cx] != 0:
							continue   # no cutting corners
						nc = cost + 14
					var dn: int = dist[ni]
					if dn == -1 or nc < dn:
						dist[ni] = nc
						buckets[nc % 15].append(ni)
						pending += 1
		cost += 1


## Direction an enemy at p should walk to reach the player around walls (zero if unknown).
func flow_dir(p: Vector2) -> Vector2:
	if dist.size() != cols * rows:
		return Vector2.ZERO   # not built yet
	var c := cell_of(p)
	var here: int = dist[_idx(c.x, c.y)]
	var best_cost := here if here >= 0 else (1 << 30)
	var best := Vector2i(-1, -1)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := c.x + dx
			var ny := c.y + dy
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var nd: int = dist[_idx(nx, ny)]
			if nd >= 0 and nd < best_cost:
				best_cost = nd
				best = Vector2i(nx, ny)
	if best.x < 0:
		return Vector2.ZERO
	var target := bounds.position + (Vector2(best) + Vector2(0.5, 0.5)) * CELL
	return (target - p).normalized()


# ---------- drawing ----------

func _load_wall_art(tier: int) -> void:
	wall_tex = PixelArt.load_tex("tiles/wall_%d.png" % tier)
	wall_tex_v = PixelArt.load_tex("tiles/wall_%d_v.png" % tier)
	icon_tex = []
	for i in 24:
		var t: Texture2D = PixelArt.load_tex("tiles/icon_%d_%d.png" % [tier, i])
		if t == null:
			break
		icon_tex.append(t)
	edge_light = Color(EDGES[tier][0])
	edge_dark = Color(EDGES[tier][1])


func _has_wall_art() -> bool:
	return wall_tex != null or not icon_tex.is_empty()


func _draw() -> void:
	var void_col := Color(0.01, 0.015, 0.03)
	var big := 4000.0
	draw_rect(Rect2(bounds.position.x - big, bounds.position.y - big, big, bounds.size.y + big * 2.0), void_col)
	draw_rect(Rect2(bounds.end.x, bounds.position.y - big, big, bounds.size.y + big * 2.0), void_col)
	draw_rect(Rect2(bounds.position.x, bounds.position.y - big, bounds.size.x, big), void_col)
	draw_rect(Rect2(bounds.position.x, bounds.end.y, bounds.size.x, big), void_col)
	draw_rect(bounds, Color(color, 0.7), false, 5.0)
	if _has_wall_art():
		_draw_art_walls(walls)   # one merged pass: wall blocks that touch or overlap draw as one shape
	else:
		for w in walls:
			_draw_wall(w, 1.0)
	if has_phase():
		var left := MapsData.PHASE_TIME - phase_t
		var warn := 0.5 + 0.5 * sin(phase_t * 16.0) if left < 1.2 else 0.0
		for set_i in 2:
			var list: Array = phase_a if set_i == 0 else phase_b
			var solid := phase_on == set_i
			if solid and _has_wall_art():
				_draw_art_walls(list)
			else:
				for w in list:
					_draw_wall(w, 1.0 if solid else 0.0, warn if phase_on != set_i else 0.0)


## Wall art on the tile grid. Tiles: every grid cell of every wall gets the device's wall tile (turned for vertical walls when the device
## has a _v tile), and the bevel is drawn only along edges that face open floor, so overlapping walls never show a seam or a double outline.
## Icons: each wall block is made of whole icons (the phone's app icons).
func _draw_art_walls(list: Array) -> void:
	if not icon_tex.is_empty():
		_draw_icon_walls(list)
		return
	var cells := {}
	for r in list:
		var rect: Rect2 = r
		var vertical := rect.size.y > rect.size.x
		for cx in range(roundi(rect.position.x / TILE), roundi(rect.end.x / TILE)):
			for cy in range(roundi(rect.position.y / TILE), roundi(rect.end.y / TILE)):
				cells[Vector2i(cx, cy)] = vertical
	for k in cells:
		var tex: Texture2D = wall_tex_v if (cells[k] and wall_tex_v != null) else wall_tex
		var nv := maxi(1, tex.get_width() / 128)   # a strip of tiles (the clock app): each wall block shows a different one
		if nv > 1:
			draw_texture_rect_region(tex, Rect2(Vector2(k) * TILE, Vector2(TILE, TILE)), Rect2(posmod(k.x * 5 + k.y * 7, nv) * 128, 0, 128, 128))
		else:
			draw_texture_rect(tex, Rect2(Vector2(k) * TILE, Vector2(TILE, TILE)), false)
	for k in cells:
		var o := Vector2(k) * TILE
		if not cells.has(k + Vector2i(0, -1)):
			draw_rect(Rect2(o, Vector2(TILE, EDGE_W)), edge_light)
		if not cells.has(k + Vector2i(-1, 0)):
			draw_rect(Rect2(o, Vector2(EDGE_W, TILE)), edge_light)
		if not cells.has(k + Vector2i(0, 1)):
			draw_rect(Rect2(o + Vector2(0.0, TILE - EDGE_W), Vector2(TILE, EDGE_W)), edge_dark)
		if not cells.has(k + Vector2i(1, 0)):
			draw_rect(Rect2(o + Vector2(TILE - EDGE_W, 0.0), Vector2(EDGE_W, TILE)), edge_dark)


## A block that is square is one icon; a longer one is a row of square icons. Each icon has a soft shadow and a different glyph.
func _draw_icon_walls(list: Array) -> void:
	for r in list:
		var rect: Rect2 = r
		var side := minf(rect.size.x, rect.size.y)
		var count := maxi(1, floori(maxf(rect.size.x, rect.size.y) / side + 0.01))   # whole icons only: they never stick out of the hitbox
		var lead := (maxf(rect.size.x, rect.size.y) - side * count) * 0.5   # a leftover is split to both ends
		for i in count:
			var pos := rect.position + (Vector2(lead + side * i, 0.0) if rect.size.x >= rect.size.y else Vector2(0.0, lead + side * i))
			var cell := Vector2i(roundi(pos.x / TILE), roundi(pos.y / TILE))
			var tex: Texture2D = icon_tex[int(icon_index[rect.position]) % icon_tex.size()] if icon_index.has(rect.position) else icon_tex[absi(hash(cell)) % icon_tex.size()]
			var box := Rect2(pos, Vector2(side, side)).grow(-ICON_INSET)   # centred in its hitbox, same inset on every side
			if skip_icons.has(rect):
				continue
			# a soft shadow in the icon's own rounded shape (a plain square shadow showed as black corners around the icon)
			draw_texture_rect(tex, Rect2(box.position + Vector2(6.0, 9.0), box.size), false, Color(0.0, 0.0, 0.0, 0.35))
			draw_texture_rect(tex, box, false)


## The icon texture of one app block (for the opening animation).
func icon_for_block(rect: Rect2) -> Texture2D:
	if icon_tex.is_empty():
		return null
	if icon_index.has(rect.position):
		return icon_tex[int(icon_index[rect.position]) % icon_tex.size()]
	var cell := Vector2i(roundi(rect.position.x / TILE), roundi(rect.position.y / TILE))
	return icon_tex[absi(hash(cell)) % icon_tex.size()]


## amount 1 = solid wall, 0 = faint ghost outline (inactive phase wall); warn flashes a wall about to close.
func _draw_wall(w: Rect2, amount: float, warn := 0.0) -> void:
	if amount > 0.5:
		draw_rect(w, Color(0.03, 0.05, 0.09))
		draw_rect(w, Color(color, 0.8), false, 5.0)
		draw_rect(w.grow(-14.0), Color(color, 0.12))
	else:
		draw_rect(w, Color(color, 0.05 + 0.4 * warn))
		draw_rect(w, Color(color, 0.18 + 0.7 * warn), false, 2.0)
