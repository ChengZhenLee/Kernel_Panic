extends RefCounted
## Vector icons drawn with canvas primitives. Used on upgrade cards, the HUD and the research tree.
## draw_icon(canvas_item, id, center, half_size, color, time, art = true)
## With art on, weapon, stat card and item ids draw their pixel sprite (PixelArt) when one exists; pass false for icons that reuse those ids
## for something else (the class ability button).

const DARK := Color(0.02, 0.03, 0.07)
const Evolutions = preload("res://scripts/evolutions.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")


static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, t := 0.0, art := true) -> void:
	if art:
		var spr := PixelArt.icon_tex(id)
		if spr != null:
			var b := clampf(maxf(col.r, maxf(col.g, col.b)) * 1.15, 0.4, 1.0)   # dimmed icons (locked nodes, cooldowns) stay dim
			var nudge := Vector2(s, s) * 2.1 / 32.0 if (id == "quarantine" or id == "evo_blizzard") else Vector2.ZERO   # these two circles sit half a pixel right and down in their frame
			ci.draw_texture_rect(spr, Rect2(c - Vector2(s, s) * 1.05 - nudge, Vector2(s, s) * 2.1), false, Color(b, b, b, col.a))
			if id.begins_with("evo_"):   # evolved weapons keep their gold ring and orbiting beads
				ci.draw_arc(c, s * 1.18, 0.0, TAU, 32, Color(1.0, 0.88, 0.35, 0.8), maxf(1.5, s * 0.1))
				for i in 4:
					var a := t * 0.8 + TAU * i / 4.0
					ci.draw_circle(c + Vector2.from_angle(a) * s * 1.18, s * 0.09, Color(1.0, 0.95, 0.6))
			return
	id = PixelArt.FALLBACK.get(id, id)
	if id.begins_with("evo_"):
		var base: String = Evolutions.base_icon(id)
		draw_icon(ci, base, c, s * 0.8, col.lerp(Color(1.0, 0.88, 0.35), 0.6), t)
		ci.draw_arc(c, s * 1.12, 0.0, TAU, 32, Color(1.0, 0.88, 0.35, 0.8), maxf(1.5, s * 0.1))
		for i in 4:
			var a := t * 0.8 + TAU * i / 4.0
			ci.draw_circle(c + Vector2.from_angle(a) * s * 1.12, s * 0.09, Color(1.0, 0.95, 0.6))
		return
	var w := maxf(1.5, s * 0.12)
	var glow := Color(col, 0.28)
	ci.draw_circle(c, s * 1.15, Color(col, 0.06))
	match id:
		"cursor":   # the BASIC class avatar: the white arrow cursor inside the spinning hexagon, as in the game
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(t * 0.6 + TAU * i / 6.0) * s * 1.05)
			ci.draw_colored_polygon(hex, Color(col, 0.15))
			hex.append(hex[0])
			ci.draw_polyline(hex, col, w * 1.3)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.62, 0), c + Vector2(-s * 0.34, s * 0.4), c + Vector2(-s * 0.11, 0), c + Vector2(-s * 0.34, -s * 0.4)]), Color(0.9, 1.0, 1.0))
			ci.draw_circle(c + Vector2.from_angle(-t * 1.3) * s * 1.22, maxf(1.5, s * 0.1), col)
		"laser":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.95, -s * 0.32), Vector2(s * 0.6, s * 0.64)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.16), Vector2(s * 0.2, s * 0.32)), col)
			ci.draw_line(c + Vector2(-s * 0.15, 0), c + Vector2(s * 0.95, 0), glow, w * 3.5)
			ci.draw_line(c + Vector2(-s * 0.15, 0), c + Vector2(s * 0.95, 0), Color.WHITE, w)
			for i in 3:
				var x := -0.05 + fmod(t * 0.8 + i * 0.33, 1.0) * 0.9
				ci.draw_rect(Rect2(c + Vector2(s * x, -s * 0.5), Vector2(s * 0.14, s * 0.14)), col)
		"firewall":
			for row in 3:
				var y := c.y + s * (0.0 + row * 0.3)
				var off := 0.0 if row % 2 == 0 else s * 0.3
				for i in 4:
					var x := c.x - s * 0.9 + off + i * s * 0.6
					var r := Rect2(Vector2(maxf(x, c.x - s * 0.9), y), Vector2(s * 0.56, s * 0.26))
					r.size.x = minf(r.size.x, c.x + s * 0.9 - r.position.x)
					if r.size.x > 2.0:
						ci.draw_rect(r, col, false, w * 0.8)
			for i in 4:
				var fx := c.x - s * 0.68 + i * s * 0.45
				var h := s * (0.45 + 0.15 * sin(t * 8.0 + i * 1.7))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - s * 0.18, c.y - s * 0.05), Vector2(fx, c.y - s * 0.05 - h), Vector2(fx + s * 0.18, c.y - s * 0.05)]), Color(1.0, 0.75, 0.25))
		"orbit":
			ci.draw_arc(c, s * 0.75, 0.0, TAU, 32, Color(col, 0.35), w * 0.6)
			_diamond(ci, c, s * 0.3, col)
			_diamond(ci, c, s * 0.14, Color.WHITE)
			for i in 3:
				var p := c + Vector2.from_angle(t * 2.0 + TAU * i / 3.0) * s * 0.75
				_diamond(ci, p, s * 0.2, col)
		"zap":
			var bolt := PackedVector2Array([
				c + Vector2(s * 0.15, -s), c + Vector2(-s * 0.5, s * 0.1), c + Vector2(-s * 0.02, s * 0.1),
				c + Vector2(-s * 0.2, s), c + Vector2(s * 0.55, -s * 0.15), c + Vector2(s * 0.05, -s * 0.15)])
			ci.draw_colored_polygon(bolt, col)
			bolt.append(bolt[0])
			ci.draw_polyline(bolt, Color.WHITE, w * 0.6)
		"mines":
			ci.draw_circle(c + Vector2(-s * 0.1, s * 0.15), s * 0.62, col)
			ci.draw_circle(c + Vector2(-s * 0.3, -s * 0.05), s * 0.15, Color(1, 1, 1, 0.6))
			ci.draw_rect(Rect2(c + Vector2(s * 0.12, -s * 0.62), Vector2(s * 0.28, s * 0.25)), col)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.6), c + Vector2(s * 0.6, -s * 0.85), Color.WHITE, w * 0.7)
			var spark := 0.5 + 0.5 * sin(t * 18.0)
			ci.draw_circle(c + Vector2(s * 0.68, -s * 0.9), s * (0.1 + 0.08 * spark), Color(1.0, 0.85, 0.3))
		"scanner":
			for i in 3:
				ci.draw_arc(c, s * (0.35 + i * 0.3), 0.0, TAU, 32, Color(col, 0.35), w * 0.5)
			var a := t * 3.0
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * s * 0.95, c + Vector2.from_angle(a - 0.6) * s * 0.95]), Color(col, 0.35))
			ci.draw_line(c, c + Vector2.from_angle(a) * s * 0.95, Color.WHITE, w)
			ci.draw_circle(c + Vector2.from_angle(1.2) * s * 0.55, s * 0.09, Color(1.0, 0.35, 0.4))
		"quarantine":
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * s * 0.9)
			ci.draw_colored_polygon(hex, Color(col, 0.18))
			hex.append(hex[0])
			ci.draw_polyline(hex, col, w)
			for i in 3:
				var d := Vector2.from_angle(TAU * i / 6.0) * s * 0.55
				ci.draw_line(c - d, c + d, Color.WHITE, w * 0.8)
		"backdoor":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.85), Vector2(s * 0.8, s * 1.7)), col, false, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.55, -s * 0.85), c + Vector2(-s * 0.1, -s * 0.65), c + Vector2(-s * 0.1, s * 1.0), c + Vector2(-s * 0.55, s * 0.85)]), Color(col, 0.45))
			ci.draw_line(c + Vector2(s * 0.0, 0), c + Vector2(s * 0.95, 0), Color.WHITE, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.0, 0), c + Vector2(s * 0.65, -s * 0.28), c + Vector2(s * 0.65, s * 0.28)]), Color.WHITE)
		"speed":
			for i in 3:
				var x := -0.75 + i * 0.5 + fmod(t, 1.0) * 0.08
				var a := Color(col, 0.4 + 0.3 * i)
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * x, -s * 0.55), c + Vector2(s * (x + 0.4), 0), c + Vector2(s * x, s * 0.55)]), a, w * 1.3)
		"vitality", "heal":
			var pts := PackedVector2Array()
			for i in 28:
				var a := TAU * i / 28.0
				var x := 16.0 * pow(sin(a), 3)
				var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
				pts.append(c + Vector2(x, y - 2.54) * s / 17.0)   # shifted so the heart is centred on c, which centres the wave inside it
			var beat := 1.0 + 0.06 * sin(t * 6.0)
			for i in pts.size():
				pts[i] = c + (pts[i] - c) * beat
			ci.draw_colored_polygon(pts, col)
			if id == "heal":
				ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.1), Vector2(s * 0.7, s * 0.2)), Color.WHITE)
				ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.35), Vector2(s * 0.2, s * 0.7)), Color.WHITE)
			else:
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.55, 0), c + Vector2(-s * 0.2, 0), c + Vector2(-s * 0.05, -s * 0.3), c + Vector2(s * 0.1, s * 0.25), c + Vector2(s * 0.25, 0), c + Vector2(s * 0.55, 0)]), Color.WHITE, w * 0.7)
		"bomb":
			# a round bomb with a fuse and a flickering spark
			var bc := c + Vector2(-s * 0.1, s * 0.15)
			ci.draw_circle(bc, s * 0.62, col)
			ci.draw_arc(bc, s * 0.62, 0.0, TAU, 28, Color.WHITE, w * 0.7)
			ci.draw_circle(bc + Vector2(-s * 0.2, -s * 0.2), s * 0.14, Color(1, 1, 1, 0.6))
			var fuse := PackedVector2Array([bc + Vector2(s * 0.3, -s * 0.5), c + Vector2(s * 0.5, -s * 0.8), c + Vector2(s * 0.75, -s * 0.75)])
			ci.draw_polyline(fuse, Color.WHITE, w)
			var sp := 0.7 + 0.3 * sin(t * 14.0)
			ci.draw_circle(c + Vector2(s * 0.8, -s * 0.78), s * 0.2 * sp, Color(1.0, 0.8, 0.2))
			ci.draw_circle(c + Vector2(s * 0.8, -s * 0.78), s * 0.1 * sp, Color.WHITE)
		"magnet":
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.55, PI, TAU, 20, col, s * 0.32)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.71, -s * 0.12), Vector2(s * 0.32, s * 0.5)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.39, -s * 0.12), Vector2(s * 0.32, s * 0.5)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.71, s * 0.38), Vector2(s * 0.32, s * 0.25)), Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(s * 0.39, s * 0.38), Vector2(s * 0.32, s * 0.25)), Color.WHITE)
			for i in 3:
				var k := fmod(t * 0.9 + i / 3.0, 1.0)
				ci.draw_rect(Rect2(c + Vector2((i - 1) * s * 0.35, s * (1.0 - k * 0.6)), Vector2(s * 0.1, s * 0.1)), Color(col, 1.0 - k))
		"might":
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.75, -s * 0.75), glow, w * 4.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.85, -s * 0.85), c + Vector2(s * 0.45, -s * 0.75), c + Vector2(-s * 0.35, s * 0.15), c + Vector2(-s * 0.15, s * 0.35), c + Vector2(s * 0.75, -s * 0.45)]), Color.WHITE)
			ci.draw_line(c + Vector2(-s * 0.55, -s * 0.05), c + Vector2(-s * 0.05, s * 0.55), col, w * 1.6)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.3), c + Vector2(-s * 0.7, s * 0.7), col, w * 1.6)
		"haste":
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 32, col, w)
			for i in 12:
				var d := Vector2.from_angle(TAU * i / 12.0)
				ci.draw_line(c + d * s * 0.62, c + d * s * 0.72, Color(col, 0.6), w * 0.5)
			ci.draw_line(c, c + Vector2.from_angle(t * 6.0 - PI / 2) * s * 0.6, Color.WHITE, w)
			ci.draw_line(c, c + Vector2.from_angle(t * 0.5 - PI / 2) * s * 0.38, col, w * 1.2)
		"crit", "critdmg":
			var spin := t * 0.8
			ci.draw_arc(c, s * 0.62, 0.0, TAU, 32, col, w)
			for i in 4:
				var d := Vector2.from_angle(spin + TAU * i / 4.0)
				ci.draw_line(c + d * s * 0.35, c + d * s * 0.95, col, w)
			ci.draw_circle(c, s * 0.14, Color.WHITE if id == "crit" else Color(1.0, 0.85, 0.3))
			if id == "critdmg":
				_star(ci, c + Vector2(s * 0.62, -s * 0.62), s * 0.3, Color(1.0, 0.85, 0.3))
		"regen":
			ci.draw_arc(c, s * 0.75, -PI * 0.9 + t, PI * 0.6 + t, 24, col, w * 1.2)
			var tip := c + Vector2.from_angle(PI * 0.6 + t) * s * 0.75
			ci.draw_circle(tip, w * 1.6, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.1), Vector2(s * 0.7, s * 0.2)), Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.35), Vector2(s * 0.2, s * 0.7)), Color.WHITE)
		"armor", "shield":
			var sh := PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.75, -s * 0.6), c + Vector2(s * 0.65, s * 0.2),
				c + Vector2(0, s * 0.95), c + Vector2(-s * 0.65, s * 0.2), c + Vector2(-s * 0.75, -s * 0.6)])
			ci.draw_colored_polygon(sh, Color(col, 0.3))
			sh.append(sh[0])
			ci.draw_polyline(sh, col, w)
			if id == "shield":
				ci.draw_arc(c, s * (0.95 + 0.08 * sin(t * 4.0)), 0.0, TAU, 32, Color(col, 0.5), w * 0.6)
			ci.draw_line(c + Vector2(0, -s * 0.55), c + Vector2(0, s * 0.6), Color.WHITE, w * 0.8)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.15), c + Vector2(s * 0.4, -s * 0.15), Color.WHITE, w * 0.8)
		"revive":
			ci.draw_arc(c, s * 0.75, 0.3, TAU - 0.3, 28, col, w * 1.2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.95, s * 0.05), c + Vector2(s * 0.5, s * 0.1), c + Vector2(s * 0.78, -s * 0.35)]), col)
			ci.draw_line(c + Vector2(0, -s * 0.38), c + Vector2(0, s * 0.38), Color.WHITE, w * 1.3)
			ci.draw_line(c + Vector2(-s * 0.38, 0), c + Vector2(s * 0.38, 0), Color.WHITE, w * 1.3)
		"thorns":
			var spikes := PackedVector2Array()
			for i in 16:
				var r := s * (0.95 if i % 2 == 0 else 0.55)
				spikes.append(c + Vector2.from_angle(t * 0.5 + TAU * i / 16.0) * r)
			ci.draw_colored_polygon(spikes, Color(col, 0.5))
			ci.draw_circle(c, s * 0.4, col)
			ci.draw_circle(c, s * 0.18, Color(1.0, 0.85, 0.3))
		"xp":
			_diamond(ci, c, s * 0.85, Color(col, 0.35))
			_diamond(ci, c, s * 0.55, col)
			_diamond(ci, c + Vector2(-s * 0.12, -s * 0.12), s * 0.2, Color.WHITE)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.7, -s * 0.95), c + Vector2(s * 0.45, -s * 0.6), c + Vector2(s * 0.95, -s * 0.6)]), Color.WHITE)
		"data":
			for i in 3:
				var y := c.y - s * 0.55 + i * s * 0.45
				ci.draw_rect(Rect2(Vector2(c.x - s * 0.7, y), Vector2(s * 1.4, s * 0.38)), Color(col, 0.35 + 0.2 * i))
				ci.draw_rect(Rect2(Vector2(c.x - s * 0.7, y), Vector2(s * 1.4, s * 0.38)), col, false, w * 0.6)
				var blink := 0.5 + 0.5 * sin(t * 5.0 + i * 2.0)
				ci.draw_circle(Vector2(c.x + s * 0.45, y + s * 0.19), s * 0.07, Color(0.4, 1.0, 0.5, blink))
		"luck":
			var r := Rect2(c - Vector2(s, s) * 0.72, Vector2(s, s) * 1.44)
			ci.draw_rect(r, Color(col, 0.3))
			ci.draw_rect(r, col, false, w)
			for p in [Vector2(-0.38, -0.38), Vector2(0.38, 0.38), Vector2(0, 0), Vector2(0.38, -0.38), Vector2(-0.38, 0.38)]:
				ci.draw_circle(c + p * s, s * 0.12, Color.WHITE)
		"cache":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.85, -s * 0.45), Vector2(s * 1.7, s * 1.15)), Color(col, 0.3))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.85, -s * 0.45), Vector2(s * 1.7, s * 1.15)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.85, -s * 0.1), Vector2(s * 1.7, s * 0.18)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.25), Vector2(s * 0.3, s * 0.45)), Color.WHITE)
			_star(ci, c + Vector2(s * 0.7, -s * 0.75), s * 0.25 * (1.0 + 0.2 * sin(t * 5.0)), Color.WHITE)
		"slot":
			var r := Rect2(c - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5)
			_dashed_rect(ci, r, col, w)
			ci.draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.4), Color.WHITE, w * 1.4)
			ci.draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.4, 0), Color.WHITE, w * 1.4)
		"reroll":
			ci.draw_arc(c, s * 0.7, -2.6 + t, 0.2 + t, 20, col, w * 1.2)
			ci.draw_arc(c, s * 0.7, 0.55 + t, 3.35 + t, 20, Color.WHITE, w * 1.2)
			ci.draw_circle(c + Vector2.from_angle(0.2 + t) * s * 0.7, w * 1.8, col)
			ci.draw_circle(c + Vector2.from_angle(3.35 + t) * s * 0.7, w * 1.8, Color.WHITE)
		"choice":
			for i in 3:
				var a := (i - 1) * 0.3
				var p := c + Vector2(0, s * 0.35)
				var pts := PackedVector2Array()
				for v in [Vector2(-0.32, -1.0), Vector2(0.32, -1.0), Vector2(0.32, 0.0), Vector2(-0.32, 0.0)]:
					pts.append(p + (v * s).rotated(a))
				ci.draw_colored_polygon(pts, Color(col, 0.35 + 0.25 * i))
				pts.append(pts[0])
				ci.draw_polyline(pts, Color.WHITE if i == 1 else col, w * 0.6)
		"boss":
			ci.draw_circle(c + Vector2(0, -s * 0.15), s * 0.65, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.38, s * 0.25), Vector2(s * 0.76, s * 0.45)), col)
			ci.draw_circle(c + Vector2(-s * 0.25, -s * 0.15), s * 0.17, DARK)
			ci.draw_circle(c + Vector2(s * 0.25, -s * 0.15), s * 0.17, DARK)
			for i in 3:
				ci.draw_line(c + Vector2((i - 1) * s * 0.22, s * 0.35), c + Vector2((i - 1) * s * 0.22, s * 0.7), DARK, w * 0.6)
		"elite":
			var crown := PackedVector2Array([c + Vector2(-s * 0.85, s * 0.5), c + Vector2(-s * 0.85, -s * 0.45), c + Vector2(-s * 0.4, 0),
				c + Vector2(0, -s * 0.75), c + Vector2(s * 0.4, 0), c + Vector2(s * 0.85, -s * 0.45), c + Vector2(s * 0.85, s * 0.5)])
			ci.draw_colored_polygon(crown, col)
			ci.draw_circle(c + Vector2(0, s * 0.18), s * 0.14, Color.WHITE)
		"area":
			for i in 3:
				var k := fmod(t * 0.7 + i / 3.0, 1.0)
				ci.draw_arc(c, s * (0.25 + k * 0.75), 0.0, TAU, 32, Color(col, 1.0 - k), w)
			ci.draw_circle(c, s * 0.2, Color.WHITE)
		"proj":
			for i in 3:
				var y := (i - 1) * s * 0.5
				ci.draw_line(c + Vector2(-s * 0.8, y), c + Vector2(s * 0.5, y), glow, w * 3.0)
				ci.draw_line(c + Vector2(-s * 0.8, y), c + Vector2(s * 0.5, y), col, w)
				ci.draw_circle(c + Vector2(s * 0.6, y), w * 1.4, Color.WHITE)
		"pierce":
			for i in 3:
				ci.draw_arc(c + Vector2((i - 1) * s * 0.5, 0), s * 0.22, 0.0, TAU, 16, Color(col, 0.7), w * 0.8)
			ci.draw_line(c + Vector2(-s * 0.95, 0), c + Vector2(s * 0.8, 0), Color.WHITE, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.0, 0), c + Vector2(s * 0.7, -s * 0.22), c + Vector2(s * 0.7, s * 0.22)]), Color.WHITE)
		"start":
			ci.draw_arc(c, s * 0.7, -PI / 2 + 0.6, -PI / 2 + TAU - 0.6, 28, col, w * 1.3)
			ci.draw_line(c + Vector2(0, -s * 0.85), c + Vector2(0, -s * 0.1), Color.WHITE, w * 1.3)
		"iframe":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.55, -s * 0.85), c + Vector2(s * 0.55, -s * 0.85), c, ]), Color(col, 0.6))
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(s * 0.55, s * 0.85), c + Vector2(-s * 0.55, s * 0.85)]), col)
			ci.draw_line(c + Vector2(-s * 0.65, -s * 0.85), c + Vector2(s * 0.65, -s * 0.85), Color.WHITE, w)
			ci.draw_line(c + Vector2(-s * 0.65, s * 0.85), c + Vector2(s * 0.65, s * 0.85), Color.WHITE, w)
		"key":
			ci.draw_arc(c + Vector2(-s * 0.4, 0), s * 0.38, 0.0, TAU, 20, col, w * 1.3)
			ci.draw_line(c + Vector2(-s * 0.02, 0), c + Vector2(s * 0.9, 0), col, w * 1.3)
			ci.draw_line(c + Vector2(s * 0.55, 0), c + Vector2(s * 0.55, s * 0.35), col, w * 1.3)
			ci.draw_line(c + Vector2(s * 0.8, 0), c + Vector2(s * 0.8, s * 0.3), col, w * 1.3)
			ci.draw_circle(c + Vector2(-s * 0.4, 0), s * 0.12, Color.WHITE)
		"infinity":
			var pts := PackedVector2Array()
			for i in 41:
				var a := TAU * i / 40.0
				var d := 1.0 + sin(a) * sin(a)
				pts.append(c + Vector2(cos(a) / d, sin(a) * cos(a) / d) * s * 0.95)
			ci.draw_polyline(pts, glow, w * 3.0)
			ci.draw_polyline(pts, col, w * 1.2)
			var k := fmod(t * 0.4, 1.0)
			ci.draw_circle(pts[int(k * 40)], w * 1.6, Color.WHITE)
		"core":
			var r := Rect2(c - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2)
			ci.draw_rect(r, Color(col, 0.3))
			ci.draw_rect(r, col, false, w)
			for i in 4:
				var o := (i - 1.5) * s * 0.3
				ci.draw_line(c + Vector2(o, -s * 0.6), c + Vector2(o, -s * 0.9), col, w * 0.7)
				ci.draw_line(c + Vector2(o, s * 0.6), c + Vector2(o, s * 0.9), col, w * 0.7)
				ci.draw_line(c + Vector2(-s * 0.6, o), c + Vector2(-s * 0.9, o), col, w * 0.7)
				ci.draw_line(c + Vector2(s * 0.6, o), c + Vector2(s * 0.9, o), col, w * 0.7)
			ci.draw_circle(c, s * (0.2 + 0.05 * sin(t * 4.0)), Color.WHITE)
		"drone":
			for k in 4:
				var tip := c + Vector2.from_angle(PI / 4.0 + k * PI / 2.0) * s * 0.75
				ci.draw_line(c, tip, col, w)
				ci.draw_arc(tip, s * 0.28, 0.0, TAU, 12, Color(col, 0.6), w * 0.6)
				var blade := Vector2.from_angle(t * 14.0 + k) * s * 0.28
				ci.draw_line(tip - blade, tip + blade, Color.WHITE, w * 0.6)
			ci.draw_circle(c, s * 0.3, col)
			ci.draw_circle(c, s * 0.12, Color.WHITE)
		"totem":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.35), Vector2(s * 0.9, s * 0.4)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.2), Vector2(s * 0.64, s * 0.5)), Color(col, 0.7))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.7), Vector2(s * 0.44, s * 0.45)), col)
			ci.draw_circle(c + Vector2(0, -s * 0.48), s * (0.1 + 0.04 * sin(t * 6.0)), Color.WHITE)
			ci.draw_arc(c + Vector2(0, -s * 0.48), s * (0.5 + 0.1 * sin(t * 3.0)), 0.0, TAU, 20, Color(col, 0.5), w * 0.6)
		"backfire":
			ci.draw_circle(c, s * 0.28, Color.WHITE)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0 + t)
				ci.draw_line(c + d * s * 0.4, c + d * s * (0.9 if k % 2 == 0 else 0.68), col, w)
			ci.draw_arc(c, s * 0.55, 0.0, TAU, 24, Color(col, 0.6), w * 0.6)
		"killstreak":
			for k in 3:
				var y := s * (0.55 - k * 0.45)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.55, y), c + Vector2(0, y - s * 0.4), c + Vector2(s * 0.55, y)]), Color(col, 0.45 + 0.28 * k), w * 1.4)
		"idleloop":
			ci.draw_arc(c, s * 0.8, t, t + TAU * 0.8, 24, col, w * 1.2)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.35), Vector2(s * 0.2, s * 0.7)), Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(s * 0.1, -s * 0.35), Vector2(s * 0.2, s * 0.7)), Color.WHITE)
		"kinetic":
			ci.draw_arc(c + Vector2(s * 0.15, 0), s * 0.55, 0.0, TAU, 20, col, w * 1.2)
			for k in 3:
				var y := (k - 1) * s * 0.4
				ci.draw_line(c + Vector2(-s * 0.95, y), c + Vector2(-s * 0.45, y), Color(col, 0.6), w)
			ci.draw_circle(c + Vector2(s * 0.15, 0), s * 0.15, Color.WHITE)
		"glasscannon":
			var gem := PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.6, 0), c + Vector2(0, s * 0.9), c + Vector2(-s * 0.6, 0)])
			ci.draw_colored_polygon(gem, Color(col, 0.3))
			gem.append(gem[0])
			ci.draw_polyline(gem, col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.1, -s * 0.7), c + Vector2(-s * 0.15, -s * 0.15), c + Vector2(s * 0.15, s * 0.1), c + Vector2(-s * 0.05, s * 0.7)]), Color.WHITE, w * 0.8)
		"adrenaline":
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.25, -s * 0.25), col, w * 3.0)
			ci.draw_line(c + Vector2(s * 0.25, -s * 0.25), c + Vector2(s * 0.85, -s * 0.85), Color.WHITE, w * 0.8)
			ci.draw_line(c + Vector2(-s * 0.85, s * 0.5), c + Vector2(-s * 0.5, s * 0.85), col, w * 1.5)
			ci.draw_line(c + Vector2(s * 0.05, -s * 0.55), c + Vector2(s * 0.55, -s * 0.05), Color.WHITE, w * 1.2)
		"collector":
			ci.draw_circle(c + Vector2(0, -s * 0.1), s * 0.45, col)
			ci.draw_circle(c + Vector2(-s * 0.17, -s * 0.15), s * 0.1, DARK)
			ci.draw_circle(c + Vector2(s * 0.17, -s * 0.15), s * 0.1, DARK)
			ci.draw_arc(c + Vector2(0, s * 0.2), s * 0.28, 0.0, PI, 10, DARK, w * 0.8)
			_diamond(ci, c + Vector2(0, s * 0.78), s * 0.2, Color.WHITE)
		"decoy":
			var hx := []
			for k in 7:
				hx.append(c + Vector2.from_angle(TAU * k / 6.0 + t * 0.5) * s * 0.8)
			for k in 6:
				ci.draw_dashed_line(hx[k], hx[k + 1], col, w, 5.0)
			ci.draw_circle(c, s * 0.2, Color.WHITE)
		"beacon":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.14, -s * 0.3), Vector2(s * 0.28, s * 0.9)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.6), Vector2(s * 0.8, s * 0.2)), col)
			for k in 3:
				var k2 := fmod(t * 0.8 + k / 3.0, 1.0)
				ci.draw_arc(c + Vector2(0, -s * 0.45), s * (0.2 + k2 * 0.7), 0.0, TAU, 20, Color(col, 1.0 - k2), w * 0.8)
		"chain":
			var zig := PackedVector2Array([c + Vector2(-s * 0.8, s * 0.5), c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(s * 0.1, s * 0.2), c + Vector2(s * 0.45, -s * 0.5), c + Vector2(s * 0.85, s * 0.1)])
			ci.draw_polyline(zig, Color(col, 0.35), w * 3.0)
			ci.draw_polyline(zig, Color.WHITE, w)
			for zp in zig:
				ci.draw_circle(zp, w * 1.3, col)
		"recycler":
			for k in 3:
				var ra := t + TAU * k / 3.0
				var r0 := c + Vector2.from_angle(ra) * s * 0.7
				var r1 := c + Vector2.from_angle(ra + 1.6) * s * 0.7
				ci.draw_line(r0, r1, col, w * 1.2)
				ci.draw_circle(r0, w * 1.6, Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.3), Vector2(s * 0.24, s * 0.6)), Color(col, 0.8))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.12), Vector2(s * 0.6, s * 0.24)), Color(col, 0.8))
		"swarmshield":
			var shd := PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.75, -s * 0.5), c + Vector2(s * 0.6, s * 0.35), c + Vector2(0, s * 0.9), c + Vector2(-s * 0.6, s * 0.35), c + Vector2(-s * 0.75, -s * 0.5)])
			ci.draw_colored_polygon(shd, Color(col, 0.25))
			shd.append(shd[0])
			ci.draw_polyline(shd, col, w)
			for k in 5:
				ci.draw_circle(c + Vector2.from_angle(t * 1.5 + TAU * k / 5.0) * s * 0.5, w * 1.2, Color.WHITE)
		"guardian":
			ci.draw_arc(c, s * 0.75, 0.0, TAU, 28, Color(col, 0.4), w * 0.6)
			var orb := c + Vector2.from_angle(t * 2.0) * s * 0.75
			ci.draw_circle(orb, s * 0.3, col)
			ci.draw_circle(orb, s * 0.12, Color.WHITE)
			ci.draw_circle(c, s * 0.12, Color(col, 0.6))
		"striker":
			var sa := -0.6
			var stip := c + Vector2.from_angle(sa) * s * 0.9
			var stail := c - Vector2.from_angle(sa) * s * 0.7
			ci.draw_colored_polygon(PackedVector2Array([stip, stail + Vector2.from_angle(sa + PI / 2.0) * s * 0.4, stail + Vector2.from_angle(sa - PI / 2.0) * s * 0.4]), col)
			ci.draw_line(stail, stail - Vector2.from_angle(sa) * s * 0.3, Color(col, 0.5), w * 2.0)
		"heavyarmor":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.7), Vector2(s * 1.4, s * 1.4)), Color(col, 0.3))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.7), Vector2(s * 1.4, s * 1.4)), col, false, w * 1.5)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.3), Vector2(s * 0.6, s * 0.6)), Color.WHITE, false, w)
		"slowburn":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.55, s * 0.1), c + Vector2(0, s * 0.85), c + Vector2(-s * 0.55, s * 0.1)]), Color(col, 0.6))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.2), c + Vector2(s * 0.28, s * 0.25), c + Vector2(0, s * 0.7), c + Vector2(-s * 0.28, s * 0.25)]), Color.WHITE)
		"berserker":
			ci.draw_circle(c + Vector2(0, -s * 0.1), s * 0.55, col)
			ci.draw_line(c + Vector2(-s * 0.5, -s * 0.6), c + Vector2(-s * 0.15, -s * 0.3), DARK, w * 1.5)
			ci.draw_line(c + Vector2(s * 0.5, -s * 0.6), c + Vector2(s * 0.15, -s * 0.3), DARK, w * 1.5)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, s * 0.15), Vector2(s * 0.6, s * 0.25)), DARK)
		"momentum":
			var hub := c + Vector2(0, s * 0.3)
			ci.draw_arc(hub, s * 0.8, PI, TAU, 20, col, w * 1.3)
			var needle := PI + (0.5 + 0.5 * sin(t * 2.0)) * PI
			ci.draw_line(hub, hub + Vector2.from_angle(needle) * s * 0.7, Color.WHITE, w)
			ci.draw_circle(hub, w * 1.5, col)
		"duration":
			# hourglass
			var top := PackedVector2Array([c + Vector2(-s * 0.55, -s * 0.8), c + Vector2(s * 0.55, -s * 0.8), c])
			var bot := PackedVector2Array([c, c + Vector2(s * 0.55, s * 0.8), c + Vector2(-s * 0.55, s * 0.8)])
			ci.draw_colored_polygon(top, Color(col, 0.3))
			ci.draw_colored_polygon(bot, col)
			ci.draw_line(c + Vector2(-s * 0.7, -s * 0.8), c + Vector2(s * 0.7, -s * 0.8), Color.WHITE, w)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.8), c + Vector2(s * 0.7, s * 0.8), Color.WHITE, w)
		"itemcd":
			# a clock with a small box (item) in the middle
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 32, col, w)
			ci.draw_arc(c, s * 0.8, -PI / 2.0, -PI / 2.0 + TAU * fmod(t * 0.3, 1.0), 24, Color.WHITE, w)
			ci.draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.6)), col)
			ci.draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.6)), Color.WHITE, false, w * 0.6)
		"holdbuffer":
			# a pause sign inside a combo ring
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 32, col, w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.4), Vector2(s * 0.22, s * 0.8)), Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(s * 0.13, -s * 0.4), Vector2(s * 0.22, s * 0.8)), Color.WHITE)
		"rage":
			# an angry spike burst
			var spikes := PackedVector2Array()
			for i in 16:
				spikes.append(c + Vector2.from_angle(TAU * i / 16.0 + t) * s * (0.9 if i % 2 == 0 else 0.45))
			ci.draw_colored_polygon(spikes, Color(col, 0.6))
			ci.draw_circle(c, s * 0.3, Color.WHITE)
		"trophy":
			# a cup
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.55, -s * 0.7), c + Vector2(s * 0.55, -s * 0.7), c + Vector2(s * 0.3, s * 0.1), c + Vector2(-s * 0.3, s * 0.1)]), col)
			ci.draw_line(c + Vector2(0, s * 0.1), c + Vector2(0, s * 0.55), col, w * 1.5)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.55), Vector2(s * 0.8, s * 0.2)), Color.WHITE)
			ci.draw_arc(c + Vector2(-s * 0.55, -s * 0.4), s * 0.25, PI / 2.0, PI * 1.5, 10, col, w)
			ci.draw_arc(c + Vector2(s * 0.55, -s * 0.4), s * 0.25, -PI / 2.0, PI / 2.0, 10, col, w)
		"cherrypick":
			# two cards, one crossed out, one gold
			ci.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.55), Vector2(s * 0.65, s * 1.1)), Color(col, 0.3))
			ci.draw_line(c + Vector2(-s * 0.8, -s * 0.55), c + Vector2(-s * 0.15, s * 0.55), col, w)
			ci.draw_rect(Rect2(c + Vector2(s * 0.05, -s * 0.7), Vector2(s * 0.75, s * 1.3)), Global.C_GOLD)
			_star(ci, c + Vector2(s * 0.42, -s * 0.05), s * 0.25, Color.WHITE)
		# ---------- devices (#31) ----------
		"dev_fridge":
			var body := Rect2(c + Vector2(-s * 0.5, -s * 0.9), Vector2(s, s * 1.8))
			ci.draw_rect(body, Color(col, 0.25))
			ci.draw_rect(body, col, false, w)
			ci.draw_line(c + Vector2(-s * 0.5, -s * 0.25), c + Vector2(s * 0.5, -s * 0.25), col, w)
			ci.draw_line(c + Vector2(s * 0.32, -s * 0.7), c + Vector2(s * 0.32, -s * 0.45), Color.WHITE, w)
			ci.draw_line(c + Vector2(s * 0.32, -s * 0.05), c + Vector2(s * 0.32, s * 0.4), Color.WHITE, w)
		"dev_phone":
			var body := Rect2(c + Vector2(-s * 0.45, -s * 0.9), Vector2(s * 0.9, s * 1.8))
			ci.draw_rect(body, Color(col, 0.25))
			ci.draw_rect(body, col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.68), Vector2(s * 0.64, s * 1.2)), Color(col, 0.55))
			ci.draw_circle(c + Vector2(0, s * 0.72), w * 0.9, Color.WHITE)
		"dev_laptop":
			var scr := Rect2(c + Vector2(-s * 0.65, -s * 0.7), Vector2(s * 1.3, s * 0.95))
			ci.draw_rect(scr, Color(col, 0.3))
			ci.draw_rect(scr, col, false, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, s * 0.35), c + Vector2(s * 0.8, s * 0.35), c + Vector2(s * 0.95, s * 0.6), c + Vector2(-s * 0.95, s * 0.6)]), col)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(s * 0.1, -s * 0.3), Color.WHITE, w * 0.7)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.05), c + Vector2(s * 0.35, -s * 0.05), Color(1, 1, 1, 0.6), w * 0.7)
		"dev_server":
			for k in 3:
				var row := Rect2(c + Vector2(-s * 0.7, -s * 0.85 + k * s * 0.58), Vector2(s * 1.4, s * 0.48))
				ci.draw_rect(row, Color(col, 0.25))
				ci.draw_rect(row, col, false, w * 0.8)
				var blink := 1.0 if fmod(t * 2.0 + k * 0.37, 1.0) < 0.6 else 0.3
				ci.draw_circle(row.position + Vector2(s * 0.22, s * 0.24), w * 0.8, Color(Global.C_GREEN, blink))
				ci.draw_line(row.position + Vector2(s * 0.5, s * 0.24), row.position + Vector2(s * 1.2, s * 0.24), Color(col, 0.7), w * 0.6)
		"dev_datacenter":
			for k in 3:
				var x := (k - 1) * s * 0.6
				var tower := Rect2(c + Vector2(x - s * 0.24, -s * 0.85), Vector2(s * 0.48, s * 1.6))
				ci.draw_rect(tower, Color(col, 0.25))
				ci.draw_rect(tower, col, false, w * 0.8)
				for j in 4:
					var lit := 1.0 if fmod(t * 1.5 + k * 0.3 + j * 0.21, 1.0) < 0.5 else 0.35
					ci.draw_line(c + Vector2(x - s * 0.12, -s * 0.6 + j * s * 0.35), c + Vector2(x + s * 0.12, -s * 0.6 + j * s * 0.35), Color(1, 1, 1, lit), w * 0.6)
			ci.draw_line(c + Vector2(-s * 0.95, s * 0.8), c + Vector2(s * 0.95, s * 0.8), col, w)
		"dev_satellite":
			var rot := sin(t * 0.8) * 0.15
			var xa := Vector2.from_angle(rot)
			var ya := Vector2.from_angle(rot + PI / 2.0)
			for side in [-1.0, 1.0]:
				var pc: Vector2 = c + xa * side * s * 0.62
				var pts := PackedVector2Array([pc - xa * s * 0.3 - ya * s * 0.3, pc + xa * s * 0.3 - ya * s * 0.3, pc + xa * s * 0.3 + ya * s * 0.3, pc - xa * s * 0.3 + ya * s * 0.3])
				ci.draw_colored_polygon(pts, Color(col, 0.55))
				ci.draw_line(pc - ya * s * 0.3, pc + ya * s * 0.3, Color.WHITE, w * 0.5)
			ci.draw_circle(c, s * 0.28, col)
			ci.draw_line(c - ya * s * 0.25, c - ya * s * 0.65, Color.WHITE, w)
			ci.draw_arc(c - ya * s * 0.75, s * 0.18, rot + PI, rot + TAU, 8, Color.WHITE, w * 0.8)
		"dev_mainframe":
			var cab := Rect2(c + Vector2(-s * 0.85, -s * 0.8), Vector2(s * 1.7, s * 1.6))
			ci.draw_rect(cab, Color(col, 0.2))
			ci.draw_rect(cab, col, false, w)
			for k in 2:
				var reel := c + Vector2((k - 0.5) * s * 0.8, -s * 0.3)
				ci.draw_arc(reel, s * 0.28, 0.0, TAU, 16, Color.WHITE, w * 0.8)
				var a := t * 3.0 * (1.0 if k == 0 else -1.0)
				ci.draw_line(reel, reel + Vector2.from_angle(a) * s * 0.26, col, w * 0.8)
			for k in 5:
				var lit := 1.0 if fmod(t * 2.5 + k * 0.29, 1.0) < 0.5 else 0.3
				ci.draw_circle(c + Vector2((k - 2) * s * 0.3, s * 0.45), w * 0.7, Color(Global.C_GOLD, lit))
		"dev_quantum":
			for k in 3:
				var a := t * 1.2 + k * PI / 3.0
				var pts := PackedVector2Array()
				for i in 25:
					var u := TAU * i / 24.0
					pts.append(c + Vector2(cos(u) * s * 0.9, sin(u) * s * 0.32).rotated(a))
				ci.draw_polyline(pts, Color(col, 0.8), w * 0.7)
			ci.draw_circle(c, s * 0.24, Color.WHITE)
			ci.draw_circle(c, s * 0.38, Color(col, 0.35))
		"knockback":
			ci.draw_circle(c + Vector2(-s * 0.55, 0), s * 0.28, col)
			for i in 3:
				var k := i * s * 0.32
				ci.draw_line(c + Vector2(-s * 0.15 + k, -s * 0.42), c + Vector2(s * 0.15 + k, 0), Color(col, 0.9 - i * 0.25), w)
				ci.draw_line(c + Vector2(s * 0.15 + k, 0), c + Vector2(-s * 0.15 + k, s * 0.42), Color(col, 0.9 - i * 0.25), w)
		"healing":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.7), Vector2(s * 0.36, s * 1.4)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.18), Vector2(s * 1.4, s * 0.36)), col)
			ci.draw_arc(c, s * (0.85 + 0.06 * sin(t * 4.0)), 0.0, TAU, 24, Color(col, 0.5), w * 0.7)
		"lifesteal":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.85), c + Vector2(s * 0.55, s * 0.15), c + Vector2(0, s * 0.8), c + Vector2(-s * 0.55, s * 0.15)]), col)
			ci.draw_circle(c + Vector2(-s * 0.15, s * 0.1), s * 0.14, Color(1, 1, 1, 0.8))
		"dodge":
			var off := sin(t * 5.0) * s * 0.12
			ci.draw_circle(c + Vector2(-s * 0.5 + off, 0), s * 0.35, Color(col, 0.25))
			ci.draw_circle(c + Vector2(-s * 0.1 + off, 0), s * 0.35, Color(col, 0.5))
			ci.draw_circle(c + Vector2(s * 0.3 + off, 0), s * 0.35, col)
		"projspeed":
			for i in 3:
				var y := (i - 1) * s * 0.5
				ci.draw_line(c + Vector2(-s * 0.9, y), c + Vector2(s * 0.1, y), Color(col, 0.3), w)
				ci.draw_line(c + Vector2(-s * 0.2, y), c + Vector2(s * 0.6, y), col, w)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.9, y), c + Vector2(s * 0.55, y - s * 0.14), c + Vector2(s * 0.55, y + s * 0.14)]), Color.WHITE)
		"ban":
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 28, col, w * 1.4)
			ci.draw_line(c + Vector2(-s * 0.57, s * 0.57), c + Vector2(s * 0.57, -s * 0.57), col, w * 1.4)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.15), Vector2(s * 0.6, s * 0.3)), Color(Color.WHITE, 0.5))
		"hotstreak":
			# a die with a flame on top: combo-driven luck
			var die := Rect2(c + Vector2(-s * 0.5, -s * 0.15), Vector2(s, s))
			ci.draw_rect(die, Color(col, 0.3))
			ci.draw_rect(die, col, false, w * 1.3)
			for pip in [Vector2(-0.25, 0.1), Vector2(0.0, 0.35), Vector2(0.25, 0.6)]:
				ci.draw_circle(c + pip * s, w * 1.2, Color.WHITE)
			var flick := 0.08 * sin(t * 6.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * (0.95 + flick)), c + Vector2(s * 0.28, -s * 0.2), c + Vector2(-s * 0.28, -s * 0.2)]), Color(1.0, 0.55, 0.2))
		"burn":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.95), c + Vector2(s * 0.55, s * 0.1), c + Vector2(s * 0.3, s * 0.75), c + Vector2(-s * 0.3, s * 0.75), c + Vector2(-s * 0.55, s * 0.1)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.2), c + Vector2(s * 0.28, s * 0.35), c + Vector2(0, s * 0.7), c + Vector2(-s * 0.28, s * 0.35)]), Color(1.0, 0.95, 0.6))
		"poison":
			ci.draw_circle(c + Vector2(0, s * 0.25), s * 0.5, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.42, s * 0.05), c + Vector2(-s * 0.42, s * 0.05)]), col)
			ci.draw_circle(c + Vector2(-s * 0.15, s * 0.15), s * 0.1, Color(1, 1, 1, 0.7))
		"freeze":
			for i in 3:
				var a := PI * i / 3.0 + t * 0.3
				ci.draw_line(c + Vector2.from_angle(a) * s * 0.9, c - Vector2.from_angle(a) * s * 0.9, col, w * 1.3)
			ci.draw_circle(c, s * 0.18, Color.WHITE)
		"shock":
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.9), c + Vector2(-s * 0.35, s * 0.05), c + Vector2(s * 0.1, s * 0.05), c + Vector2(-s * 0.3, s * 0.9)]), col, w * 1.8)
			ci.draw_circle(c, s * 0.8, Color(col, 0.12))
		"potency":
			_star(ci, c, s * 0.85, col)
			ci.draw_circle(c, s * 0.25, Color.WHITE)
		_:
			ci.draw_circle(c, s * 0.5, col)


static func _diamond(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), col)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)


static func _dashed_rect(ci: CanvasItem, r: Rect2, col: Color, w: float) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		ci.draw_dashed_line(corners[i], corners[i + 1], col, w, 6.0)
