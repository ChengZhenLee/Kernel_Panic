extends RefCounted
## Pixel-snapped drawing for the weapon FX (from art-drop/fx.zip): 1 art pixel = 1 world pixel. Every mark is a whole-pixel square
## on the world grid: no antialiased lines or circles. Dithered fills are baked once into small textures and reused.

static var _tex := {}


## p (local to ci) moved so that it lands on a whole world pixel.
static func snap(ci: Node2D, p: Vector2) -> Vector2:
	var o := ci.global_position
	return (o + p).round() - o


## A square mark of s x s px centred on p.
static func dot(ci: Node2D, p: Vector2, col: Color, s := 1.0) -> void:
	ci.draw_rect(Rect2(snap(ci, p - Vector2(s, s) * 0.5), Vector2(s, s)), col)


## A filled w x h rectangle whose top-left corner is p, snapped.
static func rect(ci: Node2D, p: Vector2, size: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(snap(ci, p), size), col)


## A line of s px squares from a to b.
static func line(ci: Node2D, a: Vector2, b: Vector2, col: Color, s := 1.0) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / maxf(1.0, s)))
	for i in n + 1:
		dot(ci, a.lerp(b, float(i) / n), col, s)


## An arc of s px squares (angles in radians).
static func arc(ci: Node2D, c: Vector2, r: float, a0: float, a1: float, col: Color, s := 1.0, max_dots := 400) -> void:
	var n := clampi(ceili(r * absf(a1 - a0) / maxf(1.0, s)), 3, max_dots)
	for i in n + 1:
		dot(ci, c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r, col, s)


static func ring(ci: Node2D, c: Vector2, r: float, col: Color, s := 1.0, max_dots := 400) -> void:
	arc(ci, c, r, 0.0, TAU, col, s, max_dots)


## A checkerboard-dithered filled disc of radius r (rounded to 4 px so few textures exist), tinted col.
static func dither_disc(ci: Node2D, c: Vector2, r: float, col: Color) -> void:
	if r > 48.0:   # big auras grow with area upgrades: baking a new huge texture per radius step hitched for 25-300 ms
		dither_disc_scaled(ci, c, r, col)
		return
	var ri := maxi(4, roundi(r / 4.0) * 4)
	var key := "d%d" % ri
	if not _tex.has(key):
		var img := Image.create(ri * 2 + 1, ri * 2 + 1, false, Image.FORMAT_RGBA8)
		for j in range(-ri, ri + 1):
			for i in range(-ri, ri + 1):
				if ((i + j) & 1) == 0 and i * i + j * j <= ri * ri:
					img.set_pixel(i + ri, j + ri, Color.WHITE)
		_tex[key] = ImageTexture.create_from_image(img)
	ci.draw_texture(_tex[key], snap(ci, c) - Vector2(ri, ri), col)


## A dithered disc of any radius from ONE small baked texture (64 px radius) scaled up: no new texture per radius, so a growing area never hitches.
static func dither_disc_scaled(ci: Node2D, c: Vector2, r: float, col: Color) -> void:
	const BASE := 64
	if not _tex.has("ds"):
		var img := Image.create(BASE * 2 + 1, BASE * 2 + 1, false, Image.FORMAT_RGBA8)
		for j in range(-BASE, BASE + 1):
			for i in range(-BASE, BASE + 1):
				if ((i + j) & 1) == 0 and i * i + j * j <= BASE * BASE:
					img.set_pixel(i + BASE, j + BASE, Color.WHITE)
		_tex["ds"] = ImageTexture.create_from_image(img)
	var s := maxf(4.0, r)
	ci.draw_texture_rect(_tex["ds"], Rect2(snap(ci, c) - Vector2(s, s), Vector2(s, s) * 2.0), false, col)


## A dithered disc of any radius tiled 1:1 from a 2x2 checker (one art pixel per checker cell), so it never scales into chunky blocks or
## moire against the floor grid, and a growing area never bakes a texture. The caller's node needs texture_repeat enabled (set here) and nearest filtering.
static func dither_disc_tiled(ci: Node2D, c: Vector2, r: float, col: Color, segs := 48) -> void:
	if not _tex.has("chk"):
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.set_pixel(0, 0, Color.WHITE)
		img.set_pixel(1, 1, Color.WHITE)
		_tex["chk"] = ImageTexture.create_from_image(img)
	ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var o := ci.global_position
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var ctr := snap(ci, c)
	for i in segs:
		var p := ctr + Vector2.from_angle(TAU * i / segs) * maxf(1.0, r)
		pts.append(p)
		uvs.append((o + p).round() / 2.0)
	ci.draw_colored_polygon(pts, col, uvs, _tex["chk"])


## A ring that stays continuous at any radius: square dots while that takes few of them, otherwise a polyline whose vertices sit on whole pixels
## (hard-edged, not antialiased). Plain Pix.ring() caps its dot count, which leaves big rings as a sparse dotted line.
static func ring_auto(ci: Node2D, c: Vector2, r: float, col: Color, s := 2.0) -> void:
	if TAU * r / maxf(1.0, s) <= 260.0:
		ring(ci, c, r, col, s, 260)
		return
	var n := clampi(ceili(r / 3.0), 48, 220)
	var pts := PackedVector2Array()   # separate segments (no joins): a wide closed polyline can spike into a solid square at small radii
	var prev := snap(ci, c + Vector2(r, 0.0))
	for i in range(1, n + 1):
		var cur := snap(ci, c + Vector2.from_angle(TAU * float(i % n) / n) * r)
		pts.append(prev)
		pts.append(cur)
		prev = cur
	ci.draw_multiline(pts, col, maxf(1.0, s), false)


## The same dithered fill for a regular octagon whose flat sides are r from the centre... (r is the corner radius).
static func dither_octagon(ci: Node2D, c: Vector2, r: float, col: Color) -> void:
	var ri := maxi(4, roundi(r / 4.0) * 4)
	var key := "o%d" % ri
	if not _tex.has(key):
		var img := Image.create(ri * 2 + 1, ri * 2 + 1, false, Image.FORMAT_RGBA8)
		for j in range(-ri, ri + 1):
			for i in range(-ri, ri + 1):
				if ((i + j) & 1) != 0:
					continue
				var a := atan2(j, i)
				var hx := ri * cos(PI / 8.0) / cos(fposmod(a, TAU / 8.0) - PI / 8.0)
				if sqrt(i * i + j * j) < hx:
					img.set_pixel(i + ri, j + ri, Color.WHITE)
		_tex[key] = ImageTexture.create_from_image(img)
	ci.draw_texture(_tex[key], snap(ci, c) - Vector2(ri, ri), col)


## Cheap repeatable noise in 0..1 (the preview's rnd()).
static func rnd(n: float) -> float:
	var v := sin(n * 127.1 + 311.7) * 43758.5453
	return v - floorf(v)
