extends RefCounted
## Shared pixel-art drawing for the item scripts (totem, beacon, decoy, bots, orbs): the 16x16 item icons from res://art/items drawn 2x on the world
## grid, plus dithered ground zones, orbit trails and motes built from Pix marks. Nothing here is antialiased and nothing is a soft glow.

const Pix = preload("res://scripts/fx/pix.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")


## The item icon `id` (see PixelArt.ITEM_ART) at `pos` (centre), `sc` x its 16 px, snapped to the world grid. False when the art is missing.
static func icon(ci: Node2D, id: String, pos: Vector2, sc := 2.0, col := Color.WHITE) -> bool:
	var tex: Texture2D = PixelArt.icon_tex(id)
	if tex == null:
		return false
	ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ci.draw_texture_rect(tex, Rect2(Pix.snap(ci, pos - Vector2(8.0, 8.0) * sc), Vector2(16.0, 16.0) * sc), false, col)
	return true


## A flat dark oval under a prop, three stacked bars so it stays blocky.
static func shadow(ci: Node2D, pos: Vector2, half_w: float, a := 0.35) -> void:
	var c := Color(0.0, 0.0, 0.05, a)
	Pix.rect(ci, pos + Vector2(-half_w * 0.6, -2.0), Vector2(half_w * 1.2, 2.0), c)
	Pix.rect(ci, pos + Vector2(-half_w, 0.0), Vector2(half_w * 2.0, 2.0), c)
	Pix.rect(ci, pos + Vector2(-half_w * 0.6, 2.0), Vector2(half_w * 1.2, 2.0), c)


## A dithered ground zone: checker fill, a hard 2 px rim that breathes, and `ticks` rune dashes turning slowly round the edge.
static func zone(ci: Node2D, c: Vector2, r: float, col: Color, fade: float, t: float, ticks := 12, fill := 0.1) -> void:
	Pix.dither_disc_tiled(ci, c, r, Color(col, fill * fade))
	var rr := r * (0.97 + 0.03 * sin(t * 5.0))
	Pix.ring_auto(ci, c, rr, Color(col, 0.75 * fade), 2.0)
	Pix.ring_auto(ci, c, maxf(1.0, rr - 6.0), Color(col, 0.25 * fade), 2.0)
	var n := maxi(3, ticks / 2) if Global.low_fx else ticks
	for i in n:
		var ang := TAU * i / n + t * 0.4
		Pix.line(ci, c + Vector2.from_angle(ang) * (rr - 6.0), c + Vector2.from_angle(ang) * (rr + 4.0), Color(Color.WHITE, 0.7 * fade), 2.0)


## Square motes rising off a point, looping; `seed` makes each prop's motes different.
static func motes(ci: Node2D, c: Vector2, col: Color, fade: float, t: float, seed: float, count := 6, spread := 14.0, rise := 36.0) -> void:
	var n := maxi(2, count / 2) if Global.low_fx else count
	for i in n:
		var ph := fposmod(t * 0.9 + Pix.rnd(i * 7.1 + seed), 1.0)
		var p := c + Vector2((Pix.rnd(i * 3.3 + seed) - 0.5) * spread * 2.0 + sin(t * 4.0 + i) * 2.0, -ph * rise)
		Pix.dot(ci, p, Color(Color.WHITE if i % 3 == 0 else col, (1.0 - ph) * fade), 3.0 if ph < 0.5 else 2.0)


## Fading ghost marks along a list of past positions (oldest first), for companion trails.
static func trail(ci: Node2D, pts: Array, col: Color, s := 3.0) -> void:
	var n := pts.size()
	for i in n:
		var f := float(i + 1) / (n + 1)
		Pix.dot(ci, ci.to_local(pts[i]), Color(col, f * 0.6), maxf(2.0, s * f))
