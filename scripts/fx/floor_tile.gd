extends Node2D
const FD = preload("res://scripts/fx/fd.gd")
## One 1024 px (16x16 cells of 64 px) tile of a device's floor pattern, drawn once into a SubViewport by game.gd and then tiled.
## Static only: the animated layers live in game.gd's backdrop. Cell hashes use tile-local coordinates.

const PixelArt = preload("res://scripts/pixel_art.gd")

var tier := 0
var base := Color.WHITE


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	# pixel floor tiles (art/tiles/floor_<tier>_<0..3>.png, 64 px cells) replace the vector pattern and decoration for a device that has them
	var variants: Array = []
	var patches: Array = []   # THE INTERNET (tier 8): a patchwork of every device's floor, 4x4 cells per patch
	if tier == 8:
		for t in 9:
			var set: Array = _load_variants(t)
			if not set.is_empty():
				patches.append(set)
	else:
		variants = _load_variants(tier)
	for cx in 16:
		for cy in 16:
			var p := Vector2(cx * 64, cy * 64)
			var h := absi(hash(Vector2i(cx, cy)))
			if not patches.is_empty():
				var set: Array = patches[absi(hash(Vector2i(cx / 4 + 11, cy / 4 + 5))) % patches.size()]
				draw_texture_rect(set[h % set.size()], Rect2(p, Vector2(64, 64)), false)
				continue
			if not variants.is_empty():
				draw_texture_rect(variants[h % variants.size()], Rect2(p, Vector2(64, 64)), false)
				continue
			_draw_floor_cell(tier if tier < 8 else 4, p, h, 64.0, base, 0.85, 0.0, cy)
			if h % 13 == 4 and tier != 5:
				_draw_decor(p, h, base, 0.85)


## art/tiles/floor_<t>_<0..23>.png for one device (as many variants as it has: the laptop has a keyboard full).
func _load_variants(t: int) -> Array:
	var out: Array = []
	for v in 24:
		var tex: Texture2D = PixelArt.load_tex("tiles/floor_%d_%d.png" % [t, v])
		if tex == null:
			break
		out.append(tex)
	return out


## Per-device floor decoration (on top of each device's own floor pattern): frost, app icons, key caps, rack lights, fan grilles, stars, tape reels, quantum rings.
func _draw_decor(p: Vector2, h: int, base: Color, light: float) -> void:
	var col := Color(base, 0.3 * light)
	var o := p + Vector2(10 + h % 30, 12 + (h / 7) % 30)
	match tier:
		0:   # frost crystals
			for i in 3:
				var a := PI * i / 3.0
				draw_line(o - Vector2.from_angle(a) * 9.0, o + Vector2.from_angle(a) * 9.0, col, 1.5)
		1:   # app icons
			draw_rect(Rect2(o, Vector2(16, 16)), col, false, 1.5)
			draw_rect(Rect2(o + Vector2(5, 5), Vector2(6, 6)), Color(col, col.a * 0.7))
		2:   # key caps
			for i in 3:
				draw_rect(Rect2(o + Vector2(i * 14, 0), Vector2(11, 11)), col, false, 1.5)
		3:   # server LEDs
			draw_line(o, o + Vector2(34, 0), col, 2.0)
			FD.circle(self, o + Vector2(4 + (h % 3) * 10, 6), 2.5, Color(base.lerp(Color.WHITE, 0.4), 0.7 * light))
		4:   # rack bars
			for i in 4:
				draw_line(o + Vector2(i * 7, 0), o + Vector2(i * 7, 22), col, 2.0)
		5:   # stars and orbit arcs
			FD.circle(self, o, 1.8, Color(col, col.a * 2.0))
			draw_arc(o, 14.0, 0.2, 2.2, 10, col, 1.2)
		6:   # tape reels
			draw_arc(o, 10.0, 0.0, TAU, 16, col, 1.5)
			FD.circle(self, o, 2.5, col)
		7:   # quantum rings
			draw_arc(o, 6.0, 0.0, TAU, 14, col, 1.2)
			draw_arc(o, 13.0, 0.0, TAU, 20, Color(col, col.a * 0.6), 1.2)



## One 64 px floor cell in the theme of the current device (no shared circuit board: each device has its own look).
func _draw_floor_cell(tier: int, p: Vector2, h: int, cell: float, base: Color, light: float, t: float, row: int) -> void:
	var sz := Vector2(cell, cell)
	match tier:
		0:   # SMART FRIDGE: frosted tiles with hairline cracks and ice glints
			draw_rect(Rect2(p, sz), Color(base, 0.04 * light))
			draw_rect(Rect2(p, sz), Color(base, 0.13 * light), false, 1.5)
			if h % 4 == 0:
				var pts := PackedVector2Array([p + Vector2(8, 10), p + Vector2(26, 28), p + Vector2(34, 24), p + Vector2(54, 50)])
				draw_polyline(pts, Color(base, 0.2 * light), 1.5)
			if h % 9 == 1:
				var g := 0.5 + 0.5 * sin(t * 1.5 + h)
				draw_line(p + Vector2(32, 20), p + Vector2(32, 44), Color(Color.WHITE, 0.25 * g * light), 1.5)
				draw_line(p + Vector2(20, 32), p + Vector2(44, 32), Color(Color.WHITE, 0.25 * g * light), 1.5)
		1:   # SMARTPHONE: a grid of rounded app tiles
			var r := Rect2(p + Vector2(7, 7), sz - Vector2(14, 14))
			draw_rect(r, Color(base, (0.09 if h % 5 == 0 else 0.035) * light))
			draw_rect(r, Color(base, 0.16 * light), false, 1.5)
			for corner in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end]:
				draw_rect(Rect2(corner - Vector2(2, 2), Vector2(4, 4)), Color(0.01, 0.015, 0.03))
			if h % 5 == 0:
				FD.circle(self, r.get_center(), 7.0, Color(base, 0.3 * light))
		2:   # GAMING LAPTOP: staggered key caps with a backlight that ripples across
			var off := 32.0 if row % 2 == 0 else 0.0
			var key := Rect2(p + Vector2(off + 3, 4), Vector2(58, 52))
			var glow := 0.5 + 0.5 * sin(t * 1.2 + (p.x + p.y) * 0.004)
			draw_rect(key, Color(base, (0.035 + 0.04 * glow) * light))
			draw_rect(key, Color(base, 0.17 * light), false, 1.5)
			draw_rect(Rect2(key.position + Vector2(6, 6), key.size - Vector2(12, 14)), Color(base, 0.07 * light), false, 1.0)
		3:   # OFFICE SERVER: rack faces with vent slats, rails and status LEDs
			draw_rect(Rect2(p, sz), Color(base, 0.03 * light))
			for i in 4:
				draw_line(p + Vector2(10, 10 + i * 12), p + Vector2(54, 10 + i * 12), Color(base, 0.14 * light), 2.0)
			draw_line(p, p + Vector2(0, cell), Color(base, 0.3 * light), 2.0)
			if h % 3 == 0:
				var led := Color(0.4, 1.0, 0.5) if h % 2 == 0 else Color(1.0, 0.7, 0.2)
				var on := 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 3.0 + h))
				FD.circle(self, p + Vector2(50, 8), 2.5, Color(led, 0.7 * on * light))
		4:   # DATA CENTER: perforated raised-floor tiles with hazard-striped aisle markers
			draw_rect(Rect2(p, sz), Color(base, 0.025 * light))
			draw_rect(Rect2(p, sz), Color(base, 0.16 * light), false, 2.0)
			for i in 3:
				for j in 3:
					FD.circle(self, p + Vector2(14 + i * 18, 14 + j * 18), 2.2, Color(base, 0.18 * light))
			if h % 10 == 0:
				for k in 4:
					draw_line(p + Vector2(k * 16, 0), p + Vector2(k * 16 + 16, 16), Color(1.0, 0.7, 0.15, 0.22 * light), 3.0)
		5:   # SATELLITE UPLINK: deep space, no floor grid: stars, faint constellation lines, nebula haze
			var sp := p + Vector2(8 + h % 48, 8 + (h / 7) % 48)
			var tw := 0.5 + 0.5 * sin(t * (0.8 + (h % 5) * 0.4) + h)
			FD.circle(self, sp, 1.0 + (h % 3) * 0.6, Color(Color.WHITE, (0.25 + 0.45 * tw) * light))
			if h % 6 == 0:
				draw_line(sp, sp + Vector2(40 + h % 40, -20 - h % 30), Color(base, 0.1 * light), 1.0)
			if h % 31 == 0:
				FD.circle(self, sp, 90.0, Color(base, 0.035))
				FD.circle(self, sp, 55.0, Color(base, 0.035))
		6:   # MAINFRAME: scrolling green code columns on a dark panel
			draw_line(p, p + Vector2(0, cell), Color(base, 0.1 * light), 1.0)
			var scroll := fposmod(t * (14.0 + (h % 4) * 9.0), cell)
			for i in 5:
				var gy := fposmod(i * 13.0 + scroll + (h % 11), cell)
				var gw := 4.0 + float((h / (i + 3)) % 3) * 4.0
				draw_rect(Rect2(p.x + 8 + (h % 3) * 14, p.y + gy, gw, 5.0), Color(base, (0.28 if i == 0 else 0.13) * light))
			if h % 8 == 0:
				draw_rect(Rect2(p + Vector2(4, 4), sz - Vector2(8, 8)), Color(base, 0.1 * light), false, 1.0)   # punch-card frame
		7:   # QUANTUM CORE: standing-wave rings and a breathing lattice of probability dots
			var pulse := 0.5 + 0.5 * sin(t * 1.4 + (p.x * 0.003 + p.y * 0.002))
			FD.circle(self, p, 2.0 + 1.5 * pulse, Color(base, (0.25 + 0.2 * pulse) * light))
			if h % 3 == 0:
				for i in 3:
					var rr := 12.0 + i * 14.0 + 4.0 * sin(t * 0.9 + i)
					draw_arc(p + sz * 0.5, rr, 0.0, TAU, 28, Color(base, (0.16 - i * 0.04) * light), 1.5)
			elif h % 3 == 1:
				draw_arc(p, cell, 0.0, PI / 2.0, 12, Color(base, 0.12 * light), 1.5)
				draw_arc(p + sz, cell, PI, PI * 1.5, 12, Color(base, 0.12 * light), 1.5)
