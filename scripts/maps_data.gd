extends RefCounted
## Fixed arena layouts, one per device (tier % 8). Coordinates are in pixels around (0,0).
## Each layout: "size" (arena width, height), "start" (player spawn), "walls" (solid Rect2s), and optionally "phase_a" / "phase_b":
## two wall sets that take turns being solid every PHASE_TIME seconds (Quantum Core). Keep every corridor at least ~300 px wide.

const T := 48.0           # wall thickness
const PHASE_TIME := 7.0

const NAMES := ["THE SHELVES", "THE APP GRID", "THE KEYBOARD", "THE RACK MAZE", "THE SERVER HALLS", "THE DISH", "THE REEL ROOMS", "THE PHASE LATTICE"]


const WALL_SCALE := 2.5    # wall thickness and pillar/block size grow by this factor so the player feels small next to the bigger maps
const MAP_SCALE := 3.4     # arenas are spread out by this factor (4x the area of the old 1.7 scale at 2x per side) so they feel open like Vampire Survivors (walls keep their thickness)


const TILE := 128.0   # wall art tiles are 128 px; every wall edge sits on this grid so tiles never cut off or overlap


static func layout(tier: int) -> Dictionary:
	return _snap(_spread(_layout(tier)))


## Moves every wall edge onto the TILE grid (minimum one tile thick) so the wall art fits exactly. The layouts above stay in free units;
## the art grid applies only here, so layouts can change later and the art stays valid.
static func _snap(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	for key in ["walls", "phase_a", "phase_b"]:
		if not d.has(key):
			continue
		var list := []
		for r in d[key]:
			list.append(snap_rect(r))
		out[key] = list
	return out


## One wall moved onto the TILE grid: a thin wall (under 1.5 tiles) is exactly one tile thick, centred where it was; a thick block snaps both edges.
static func snap_rect(rect: Rect2) -> Rect2:
	var x0 := roundf(rect.position.x / TILE) * TILE
	var x1 := roundf(rect.end.x / TILE) * TILE
	if rect.size.x < TILE * 1.5:
		x0 = roundf((rect.get_center().x - TILE / 2.0) / TILE) * TILE
		x1 = x0 + TILE
	var y0 := roundf(rect.position.y / TILE) * TILE
	var y1 := roundf(rect.end.y / TILE) * TILE
	if rect.size.y < TILE * 1.5:
		y0 = roundf((rect.get_center().y - TILE / 2.0) / TILE) * TILE
		y1 = y0 + TILE
	if x1 - x0 < TILE:
		x1 = x0 + TILE
	if y1 - y0 < TILE:
		y1 = y0 + TILE
	return Rect2(x0, y0, x1 - x0, y1 - y0)


## Scales an arena up: positions and long wall dimensions grow, wall thickness and pillars by WALL_SCALE.
static func _spread(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	out["size"] = d["size"] * MAP_SCALE
	out["start"] = d["start"] * MAP_SCALE
	for key in ["walls", "phase_a", "phase_b"]:
		if not d.has(key):
			continue
		var list := []
		for r in d[key]:
			var rect: Rect2 = r
			var sz := rect.size
			var lo := minf(sz.x, sz.y)
			var hi := maxf(sz.x, sz.y)
			var nsz := sz * WALL_SCALE   # blocks and pillars grow both ways, thin walls get thicker
			if hi > lo * 3.0:   # a long wall also grows along its length
				if sz.x > sz.y:
					nsz.x = sz.x * MAP_SCALE
				else:
					nsz.y = sz.y * MAP_SCALE
			var center := (rect.position + sz / 2.0) * MAP_SCALE
			list.append(Rect2(center - nsz / 2.0, nsz))
		out[key] = list
	return out


static func _layout(tier: int) -> Dictionary:
	match tier % 8:
		0:
			return _fridge()
		1:
			return _phone()
		2:
			return _laptop()
		3:
			return _server()
		4:
			return _datacenter()
		5:
			return _satellite()
		6:
			return _mainframe()
	return _quantum()


## Boss rooms: a sealed side arena (about 1900 x 1300) with a little cover, one per device. The player enters on the left.
static func room(tier: int) -> Dictionary:
	return _snap(_boss_room(tier))


static func _boss_room(tier: int) -> Dictionary:
	var size := Vector2(1900, 1300)
	var start := Vector2(-600, 0)
	match tier % 8:
		0:   # two shelf posts
			return {"size": size, "start": start, "walls": [Rect2(-350, -300, T, 600), Rect2(302, -300, T, 600)]}
		1:   # four app pillars
			return {"size": size, "start": start, "walls": [Rect2(-460, -310, 120, 120), Rect2(340, -310, 120, 120), Rect2(-460, 190, 120, 120), Rect2(340, 190, 120, 120)]}
		2:   # key blocks
			return {"size": size, "start": start, "walls": [Rect2(-500, -60, 220, 120), Rect2(-110, -60, 220, 120), Rect2(280, -60, 220, 120)]}
		3:   # two racks
			return {"size": size, "start": start, "walls": [Rect2(-420, -520, 64, 700), Rect2(356, -180, 64, 700)]}
		4:   # two aisle rows
			return {"size": size, "start": start, "walls": [Rect2(-600, -330, 1200, T), Rect2(-600, 282, 1200, T)]}
		5:   # the dish
			return {"size": size, "start": start, "walls": [Rect2(-140, -140, 280, 280)]}
		6:   # plus-shaped cover
			return {"size": size, "start": start, "walls": [Rect2(-520, -24, 360, T), Rect2(160, -24, 360, T), Rect2(-24, -420, T, 260), Rect2(-24, 160, T, 260)]}
	return {"size": size, "start": start, "walls": [Rect2(-60, -60, 120, 120)],
		"phase_a": [Rect2(-460, -420, 60, 520), Rect2(400, -100, 60, 520)],
		"phase_b": [Rect2(-460, -100, 60, 520), Rect2(400, -420, 60, 520)]}


## Secret side rooms (A1 to A8), sealed arenas like the boss rooms. The player enters on the left.
static func secret_room(id: String) -> Dictionary:
	match id:
		"freezer":   # frozen shelves: two ice pillars and a long cold slab
			return _snap({"size": Vector2(2200, 1500), "start": Vector2(-800, 0), "walls": [
				Rect2(-420, -420, 120, 360), Rect2(300, 60, 120, 360), Rect2(-120, -40, 240, 80)]})
		"lounge":   # the manager's lounge: desks and a sofa row
			return _snap({"size": Vector2(2400, 1600), "start": Vector2(-900, 0), "walls": [
				Rect2(-500, -500, 400, 120), Rect2(100, -500, 400, 120), Rect2(-500, 380, 400, 120), Rect2(100, 380, 400, 120)]})
		"app_mail":   # the inbox: two long stacks of letters with a lane between them and a lane on either side
			return _snap({"size": Vector2(2200, 1400), "start": Vector2(-700, 0), "walls": [Rect2(-420, -330, 840, 130), Rect2(-420, 200, 840, 130)]})
		"app_messages":   # a chat: bubbles stagger left and right down the room
			return _snap({"size": Vector2(2200, 1400), "start": Vector2(-700, 0), "walls": [
				Rect2(-560, -440, 330, 190), Rect2(-100, -180, 330, 190), Rect2(-560, 90, 330, 190), Rect2(360, -440, 330, 190), Rect2(360, 150, 330, 190)]})
		"app_maps":   # a map: pins scattered over the floor
			return _snap({"size": Vector2(2400, 1500), "start": Vector2(-800, 0), "walls": [
				Rect2(-560, -450, 140, 140), Rect2(-240, 250, 140, 140), Rect2(60, -300, 140, 140), Rect2(420, 40, 140, 140), Rect2(-80, -20, 140, 140)]})
		"app_clock":   # a clock face: a block at each of 12, 3, 6 and 9
			return _snap({"size": Vector2(2200, 1500), "start": Vector2(-700, 0), "walls": [
				Rect2(-70, -480, 140, 140), Rect2(330, -70, 140, 140), Rect2(-70, 340, 140, 140), Rect2(-470, -70, 140, 140)]})
		"app_music":   # an equaliser: bars of different heights standing on the bottom edge
			return _snap({"size": Vector2(2200, 1400), "start": Vector2(-700, 0), "walls": [
				Rect2(-400, 160, 120, 540), Rect2(-160, -20, 120, 720), Rect2(80, 260, 120, 440), Rect2(320, -140, 120, 840)]})
		"app_phone":   # a keypad: 1 2 3 / 4 5 6 / 7 8 9 / 0, ten 128 px number buttons, evenly spaced
			return _snap({"size": Vector2(2600, 2000), "start": Vector2(-1000, 0), "walls": [   # on the 128 grid, pitch 384 both ways (256 px gaps), so the spacing is exactly even
				Rect2(-512, -640, 128, 128), Rect2(-128, -640, 128, 128), Rect2(256, -640, 128, 128),
				Rect2(-512, -256, 128, 128), Rect2(-128, -256, 128, 128), Rect2(256, -256, 128, 128),
				Rect2(-512, 128, 128, 128), Rect2(-128, 128, 128, 128), Rect2(256, 128, 128, 128), Rect2(-128, 512, 128, 128)]})
		"app_settings":   # three slider tracks with gaps to walk around
			return _snap({"size": Vector2(2200, 1400), "start": Vector2(-700, 0), "walls": [
				Rect2(-480, -380, 640, 110), Rect2(-120, -50, 640, 110), Rect2(-480, 280, 640, 110)]})
		"app_photos":   # snapshots stacked on a diagonal
			return _snap({"size": Vector2(2200, 1500), "start": Vector2(-700, 0), "walls": [
				Rect2(-560, -400, 260, 260), Rect2(-130, -130, 260, 260), Rect2(300, 140, 260, 260)]})
		"app_weather":   # a cloud: three puffs at the top of the room
			return _snap({"size": Vector2(2200, 1400), "start": Vector2(-700, 0), "walls": [
				Rect2(-420, -400, 280, 170), Rect2(-200, -470, 320, 210), Rect2(70, -400, 300, 170)]})
		"shop":   # the store: an open hall with room for four pedestals in a row
			return _snap({"size": Vector2(2800, 1500), "start": Vector2(-1100, 0), "walls": []})
		"app":   # a small app room: two pillars
			return _snap({"size": Vector2(2000, 1300), "start": Vector2(-700, 0), "walls": [Rect2(-120, -420, 240, 240), Rect2(-120, 180, 240, 240)]})
		"corrupt":   # the corrupted app: scattered blocks
			return _snap({"size": Vector2(2200, 1500), "start": Vector2(-800, 0), "walls": [
				Rect2(-400, -400, 240, 240), Rect2(160, -400, 240, 240), Rect2(-400, 160, 240, 240), Rect2(160, 160, 240, 240)]})
		"periph_keyboard":   # a keyboard: three rows of keycap blocks (a gap row between each) with a long space bar at the bottom
			var keys := []
			for row in 3:
				for col in 5:
					keys.append(Rect2(-520 + col * 260 + row * 40, -480 + row * 250, 140, 140))
			keys.append(Rect2(-260, 300, 560, 120))
			return _snap({"size": Vector2(2600, 1600), "start": Vector2(-1000, 0), "walls": keys})
		"periph_mouse":   # a mouse and its cable: two long wall segments that make an S-shaped cable, a round-ish body block in the middle
			return _snap({"size": Vector2(2600, 1600), "start": Vector2(-1000, 0), "walls": [
				Rect2(-700, -300, 800, 90), Rect2(10, -300, 90, 380), Rect2(-420, 70, 520, 90), Rect2(-420, 70, 90, 380),
				Rect2(380, -230, 300, 460)]})
		"periph_webcam":   # a lens: eight blocks in a ring around the middle, a gap on each side so you can run through
			var ring := []
			for k in 8:
				var a := TAU * k / 8.0
				ring.append(Rect2(Vector2.from_angle(a) * 480.0 - Vector2(80, 80), Vector2(160, 160)))
			return _snap({"size": Vector2(2400, 1700), "start": Vector2(-1000, 0), "walls": ring})
		"periph_headset":   # a headset: two big ear-cup blocks left and right, a headband of small blocks arching over the top
			return _snap({"size": Vector2(2600, 1600), "start": Vector2(-1000, 0), "walls": [
				Rect2(-820, -180, 240, 360), Rect2(580, -180, 240, 360),
				Rect2(-560, -520, 140, 100), Rect2(-300, -640, 140, 100), Rect2(-70, -680, 140, 100), Rect2(160, -640, 140, 100), Rect2(420, -520, 140, 100)]})
		"periph":   # a peripheral's room: a few pillars
			return _snap({"size": Vector2(2400, 1500), "start": Vector2(-900, 0), "walls": [Rect2(-300, -450, 200, 200), Rect2(100, 250, 200, 200)]})
		"moon":   # the moon base: crater rocks
			return _snap({"size": Vector2(3600, 2200), "start": Vector2(-1500, 0), "walls": [Rect2(-1000, -700, 200, 200), Rect2(-1000, 500, 200, 200), Rect2(100, -100, 200, 200)]})
		"hq":   # the Overseer HQ: an open hall
			return _snap({"size": Vector2(3600, 1500), "start": Vector2(-1400, 300), "walls": []})
		"unobserved":   # the unobserved room: empty
			return _snap({"size": Vector2(2200, 1400), "start": Vector2(-800, 0), "walls": []})
		"upload":   # the data upload hallway: long and empty; the west end is dark (it throws you out), the boss waits at the east end
			return _snap({"size": Vector2(16000, 560), "start": Vector2(-6500, 0), "walls": []})   # a long thin rectangle: about 14000 px from the start to the boss
	return _snap({"size": Vector2(1900, 1300), "start": Vector2(-600, 0), "walls": []})


static func name_of(tier: int) -> String:
	return NAMES[tier % 8]


## Smart Fridge: two long shelves with gaps on opposite ends and two door posts.
static func _fridge() -> Dictionary:
	return {"size": Vector2(3400, 2300), "start": Vector2.ZERO, "walls": [
		Rect2(-1700, -644, 2300, T), Rect2(-600, 596, 2300, T),
		Rect2(1000, -300, T, 600), Rect2(-1048, -300, T, 600)]}


## Smartphone: a grid of square app-icon pillars around an open centre.
static func _phone() -> Dictionary:
	var walls := []
	for gx in range(-2, 3):
		for gy in range(-2, 3):
			if gx == 0 and gy == 0:
				continue
			# every app pillar is exactly 3x3 art tiles (384 px) centred on a tile centre, so the icon art, the hitbox and the grid all agree
			var side := 3.0 * TILE / WALL_SCALE
			var cx := _tile_centre(gx * 540.0 * MAP_SCALE) / MAP_SCALE
			var cy := _tile_centre(gy * 500.0 * MAP_SCALE) / MAP_SCALE
			walls.append(Rect2(cx - side / 2.0, cy - side / 2.0, side, side))
	return {"size": Vector2(3000, 2800), "start": Vector2.ZERO, "walls": walls}


## The centre of the 128 px tile nearest to v (an odd number of tiles wide block centred here has both edges on the grid).
static func _tile_centre(v: float) -> float:
	return roundf(v / TILE - 0.5) * TILE + TILE / 2.0


## Gaming Laptop: rows of key blocks along the top and a touchpad slab at the bottom.
static func _laptop() -> Dictionary:
	var walls := []
	for row in 2:
		for i in range(-5, 6):
			walls.append(Rect2(i * 260 - 100, -820 + row * 200, 200, 100))
	walls.append(Rect2(-260, 460, 520, 300))
	return {"size": Vector2(3500, 2300), "start": Vector2.ZERO, "walls": walls}


## Office Server: staggered rack columns that make a snaking corridor maze.
static func _server() -> Dictionary:
	return {"size": Vector2(3600, 2400), "start": Vector2.ZERO, "walls": [
		Rect2(-1424, -1000, 72, 1200), Rect2(-724, -200, 72, 1200),
		Rect2(652, -1000, 72, 1200), Rect2(1352, -200, 72, 1200)]}


## Data Center: server-row aisles split by a gap, with short blocks forming two halls.
static func _datacenter() -> Dictionary:
	return {"size": Vector2(3800, 2600), "start": Vector2.ZERO, "walls": [
		Rect2(-1700, -824, 1400, T), Rect2(300, -824, 1400, T),
		Rect2(-1700, 776, 1400, T), Rect2(300, 776, 1400, T),
		Rect2(-924, -424, T, 800), Rect2(876, -424, T, 800)]}


## Satellite Uplink: a central dish, with solar panel walls around it. The player starts south of the dish.
static func _satellite() -> Dictionary:
	return {"size": Vector2(3400, 3400), "start": Vector2(0, 520), "walls": [
		Rect2(-200, -200, 400, 400),
		Rect2(-1400, -1200, 700, 70), Rect2(700, -1200, 700, 70),
		Rect2(-1400, 1130, 700, 70), Rect2(700, 1130, 700, 70),
		Rect2(-1250, -700, 70, 500), Rect2(1180, -700, 70, 500)]}


## Mainframe: three nested square rooms whose doors sit on alternating sides.
static func _mainframe() -> Dictionary:
	var walls := []
	walls.append_array(_room(550.0, "S", 440.0))
	walls.append_array(_room(1000.0, "N", 440.0))
	walls.append_array(_room(1450.0, "E", 440.0))
	return {"size": Vector2(3600, 3600), "start": Vector2.ZERO, "walls": walls}


## Four wall rectangles around a square of half-size h, with a door of width gap on side "N", "S", "E" or "W".
static func _room(h: float, door: String, gap: float) -> Array:
	var out := []
	var span := h * 2.0 + T
	for side in ["N", "S", "E", "W"]:
		var horizontal: bool = side == "N" or side == "S"
		var fixed: float = -h - T / 2.0 if (side == "N" or side == "W") else h - T / 2.0
		if side == door:
			var half := (span - gap) / 2.0
			if horizontal:
				out.append(Rect2(-h - T / 2.0, fixed, half, T))
				out.append(Rect2(-h - T / 2.0 + half + gap, fixed, half, T))
			else:
				out.append(Rect2(fixed, -h - T / 2.0, T, half))
				out.append(Rect2(fixed, -h - T / 2.0 + half + gap, T, half))
		elif horizontal:
			out.append(Rect2(-h - T / 2.0, fixed, span, T))
		else:
			out.append(Rect2(fixed, -h - T / 2.0, T, span))
	return out


## Quantum Core: two wall sets that swap every 7 seconds (vertical bars, then horizontal bars) plus a few fixed pillars.
static func _quantum() -> Dictionary:
	return {"size": Vector2(3200, 3200), "start": Vector2.ZERO,
		"walls": [Rect2(-1000, -1000, 140, 140), Rect2(860, -1000, 140, 140), Rect2(-1000, 860, 140, 140), Rect2(860, 860, 140, 140)],
		"phase_a": [Rect2(-724, -1100, 72, 1000), Rect2(652, 100, 72, 1000), Rect2(-724, 400, 72, 700), Rect2(652, -1100, 72, 700)],
		"phase_b": [Rect2(-1100, -724, 1000, 72), Rect2(100, 652, 1000, 72), Rect2(400, -724, 700, 72), Rect2(-1100, 652, 700, 72)]}
