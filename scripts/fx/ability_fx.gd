extends Node2D
## Pixel-snapped class-ability FX (same style as the weapon FX: whole-pixel squares, no antialiased arcs or circles).
## One short-lived node per effect. kind: "ring" | "burst" | "disc" | "phase" | "lock" | "scan" | "heal" | "clock" | "rail" | "fire" | "ice" | "pause"
## | "storm" | "strike" (one-shots) and "aura_overclock" | "aura_scan" | "aura_storm" | "aura_pause" (follow `target` until `life` runs out or stop() is called).
## Every kind except "ring" and "burst" plays a pixel-art sprite sheet from res://assets/fx/abilities (see README.md there); the code-drawn
## versions below are only a fallback when a sheet is missing. `radius` sets the sprite scale (radius / ref radius, in half steps); `life` is the playback time.
## Every mark count is capped.

const Pix = preload("res://scripts/fx/pix.gd")

## kind -> sheet. fw/fh: frame size, n: frames, ox/oy: the sprite's origin inside a frame, ref: reference radius in sheet px (0 = fixed 1x).
const SHEETS := {
	"disc": {"f": "purge_impact", "fw": 192, "fh": 192, "n": 12, "ox": 96, "oy": 96, "ref": 88.0},
	"lock": {"f": "lockdown_impact", "fw": 192, "fh": 192, "n": 12, "ox": 96, "oy": 96, "ref": 88.0},
	"scan": {"f": "deepscan_impact", "fw": 192, "fh": 192, "n": 12, "ox": 96, "oy": 96, "ref": 88.0},
	"heal": {"f": "restore_impact", "fw": 192, "fh": 192, "n": 12, "ox": 96, "oy": 96, "ref": 88.0},
	"clock": {"f": "overclock_impact", "fw": 192, "fh": 192, "n": 10, "ox": 96, "oy": 96, "ref": 88.0},
	"pause": {"f": "pause_impact", "fw": 192, "fh": 192, "n": 12, "ox": 96, "oy": 96, "ref": 88.0},
	"fire": {"f": "wildfire_impact", "fw": 384, "fh": 384, "n": 24, "ox": 192, "oy": 192, "ref": 170.0},
	"ice": {"f": "deepfreeze_impact", "fw": 384, "fh": 384, "n": 24, "ox": 192, "oy": 192, "ref": 170.0},
	"storm": {"f": "thunderstorm_impact", "fw": 384, "fh": 384, "n": 24, "ox": 192, "oy": 192, "ref": 170.0},
	"strike": {"f": "thunderstorm_strike", "fw": 160, "fh": 288, "n": 14, "ox": 80, "oy": 250, "ref": 0.0},
	"phase": {"f": "phase_impact", "fw": 192, "fh": 64, "n": 10, "ox": 22, "oy": 32, "ref": 0.0},
	"rail": {"f": "railstrike_impact", "fw": 640, "fh": 160, "n": 20, "ox": 64, "oy": 80, "ref": 0.0},
	"aura_overclock": {"f": "overclock_aura", "fw": 64, "fh": 64, "n": 8, "ox": 32, "oy": 32, "ref": 0.0},
	"aura_scan": {"f": "deepscan_aura", "fw": 64, "fh": 64, "n": 8, "ox": 32, "oy": 32, "ref": 0.0},
	"aura_pause": {"f": "pause_aura", "fw": 64, "fh": 64, "n": 8, "ox": 32, "oy": 32, "ref": 0.0},
	"aura_storm": {"f": "thunderstorm_aura", "fw": 96, "fh": 96, "n": 8, "ox": 48, "oy": 56, "ref": 0.0},
}
const SHEET_FPS := 12.0
static var _sheets := {}

var kind := "ring"
var color := Color.WHITE
var radius := 200.0
var life := 0.5   # auras: set to a huge value until stop()
var size := 4.0        # square size in px
var count := 16        # particles / spokes
var sup := false
var from := Vector2.ZERO   # world-space start (phase)
var to := Vector2.ZERO     # world-space end (phase)
var target: Node2D = null
var t := 0.0
var _seed := 0.0
var _fading := false


func _ready() -> void:
	_seed = randf() * 100.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func stop() -> void:
	if not _fading:
		_fading = true
		life = t + 0.25


func _process(delta: float) -> void:
	t += delta
	if is_instance_valid(target):
		global_position = target.global_position
	elif kind.begins_with("aura"):
		queue_free()
		return
	if (not kind.begins_with("aura") or _fading) and t >= life:
		queue_free()
	queue_redraw()


func _cap(n: int) -> int:
	return n


## The sheet texture for this kind, or null when it is not imported yet (the code-drawn fallback is used then).
func _sheet() -> Texture2D:
	if not SHEETS.has(kind):
		return null
	var f: String = SHEETS[kind]["f"]
	if not _sheets.has(f):
		var path := "res://assets/fx/abilities/%s.png" % f
		_sheets[f] = load(path) if ResourceLoader.exists(path) else null
	return _sheets[f]


func _draw_sheet(tex: Texture2D) -> void:
	var sh: Dictionary = SHEETS[kind]
	var n: int = sh["n"]
	var fw: float = sh["fw"]
	var fh: float = sh["fh"]
	var origin := Vector2(sh["ox"], sh["oy"])
	var frame: int
	var alpha := 1.0
	if kind.begins_with("aura"):
		frame = int(t * SHEET_FPS) % n
		alpha = _aura_a()
	else:
		frame = clampi(int(t / maxf(life, 0.001) * n), 0, n - 1)
	var src := Rect2(frame * fw, 0.0, fw, fh)
	var col := Color(1, 1, 1, alpha)
	if kind == "rail" or kind == "phase":
		_draw_directed(tex, sh, src, col)
		return
	var sc := 1.0
	if float(sh["ref"]) > 0.0:   # scale to the game radius in half steps so pixels stay even
		sc = maxf(1.0, roundf(radius / float(sh["ref"]) * 2.0) / 2.0)
	elif kind == "strike":
		sc = 1.0 if radius <= 0.0 else maxf(1.0, roundf(radius))
	if sup and kind != "strike" and not kind.begins_with("aura"):
		sc *= 1.25
	draw_texture_rect_region(tex, Rect2(Pix.snap(self, -origin * sc), Vector2(fw, fh) * sc), src, col)


## Directional sheets: drawn from `from` toward `to`. PHASE stretches along the dash; RAIL STRIKE is 3-sliced (muzzle, beam, impact) so only the beam stretches.
func _draw_directed(tex: Texture2D, sh: Dictionary, src: Rect2, col: Color) -> void:
	var o := to_local(from)
	var d := to_local(to) - o
	var dist := maxf(1.0, d.length())
	var thick := 1.25 if sup else 1.0
	draw_set_transform(o, d.angle(), Vector2.ONE)
	var oy: float = sh["oy"]
	if kind == "phase":   # sheet runs x=22 (start) .. x=170 (landing)
		var sx := dist / 148.0
		draw_set_transform(o, d.angle(), Vector2(sx, thick))
		draw_texture_rect_region(tex, Rect2(Vector2(-22.0, -oy), src.size), src, col)
	else:   # rail: muzzle at x=64, impact at x=576 (512 long); slices at x<110 and x>530
		var fw := src.size.x
		var left := Rect2(src.position, Vector2(110.0, src.size.y))
		var mid := Rect2(src.position + Vector2(110.0, 0.0), Vector2(420.0, src.size.y))
		var right := Rect2(src.position + Vector2(530.0, 0.0), Vector2(fw - 530.0, src.size.y))
		var h := src.size.y * thick
		var y0 := -oy * thick
		if dist < 92.0:   # too short to slice: squash the whole sheet
			draw_set_transform(o, d.angle(), Vector2(dist / 512.0, thick))
			draw_texture_rect_region(tex, Rect2(Vector2(-64.0, -oy), src.size), src, col)
		else:
			draw_texture_rect_region(tex, Rect2(Vector2(-64.0, y0), Vector2(110.0, h)), left, col)
			draw_texture_rect_region(tex, Rect2(Vector2(46.0, y0), Vector2(dist - 92.0, h)), mid, col)
			draw_texture_rect_region(tex, Rect2(Vector2(dist - 46.0, y0), Vector2(fw - 530.0, h)), right, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if kind != "ring" and kind != "burst":
		var tex := _sheet()
		if tex != null:
			_draw_sheet(tex)
			return
	var k := clampf(t / maxf(life, 0.001), 0.0, 1.0)
	var out := 1.0 - pow(1.0 - k, 3.0)   # fast start, soft stop
	match kind:
		"ring": _draw_ring(k, out)
		"burst": _draw_burst(k)
		"disc": _draw_disc(k, out)
		"phase": _draw_phase(k)
		"lock": _draw_lock(k)
		"scan": _draw_scan(k)
		"heal": _draw_heal(k)
		"clock": _draw_clock(k, out)
		"rail": _draw_rail(k, out)
		"fire": _draw_fire(k, out)
		"ice": _draw_ice(k, out)
		"pause": _draw_pause(k)
		"aura_overclock": _draw_aura_overclock()
		"aura_scan": _draw_aura_scan()
		"aura_storm": _draw_aura_storm()


# ---------- one-shots ----------

## An expanding ring of squares: thick leading edge, thin trailing echo.
func _draw_ring(k: float, out: float) -> void:
	var r := radius * out
	var a := 1.0 - k
	var s := maxf(2.0, size * (1.0 - k * 0.6))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(color, a), s)
	if r > 12.0:
		Pix.ring_auto(self, Vector2.ZERO, r * 0.9, Color(color, a * 0.45), maxf(1.0, s * 0.5))


func _draw_burst(k: float) -> void:
	var n := _cap(count)
	var a := 1.0 - k
	for i in n:
		var ang := TAU * (float(i) + Pix.rnd(i + _seed) * 0.8) / n
		var sp := radius * (0.4 + 0.6 * Pix.rnd(i * 3.1 + _seed))
		var d := sp * (1.0 - pow(1.0 - k, 2.5))
		var p := Vector2.from_angle(ang) * d
		var s := maxf(1.0, size * (1.0 - k * 0.7))
		Pix.dot(self, p, Color(Color.WHITE if i % 5 == 0 else color, a), s)
		if k < 0.5:   # short pixel tail
			Pix.dot(self, p * 0.8, Color(color, a * 0.5), maxf(1.0, s - 1.0))


## PURGE: a dithered white-gold flood with a hard rim and four sweeping diagonal pixel rays.
func _draw_disc(k: float, out: float) -> void:
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(color, 0.14 * (1.0 - k)))
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.6, Color(Color.WHITE, 0.12 * (1.0 - k)))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, 1.0 - k), size)
	var rays := 8
	for i in rays:
		var ang := TAU * i / rays + k * 0.8
		Pix.line(self, Vector2.from_angle(ang) * r * 0.55, Vector2.from_angle(ang) * r, Color(color, 1.0 - k), 3.0)


## PHASE: a trail of hollow ghost squares along the dash that fade out from the start, plus a speed-line streak.
func _draw_phase(k: float) -> void:
	var a := 1.0 - k
	var n := 10
	var span := to - from
	var dir := span.normalized() if span.length() > 1.0 else Vector2.RIGHT
	for i in n:
		var f := float(i) / (n - 1)
		var delay := f * 0.35
		var kk := clampf((k - delay) / (1.0 - delay), 0.0, 1.0)
		if kk >= 1.0:
			continue
		var p := to_local(from.lerp(to, f))
		var ga := (1.0 - kk) * 0.8
		var h := 13.0 - kk * 4.0
		Pix.rect(self, p - Vector2(h, h), Vector2(h * 2.0, 2.0), Color(color, ga))
		Pix.rect(self, p + Vector2(-h, h - 2.0), Vector2(h * 2.0, 2.0), Color(color, ga))
		Pix.rect(self, p - Vector2(h, h), Vector2(2.0, h * 2.0), Color(color, ga))
		Pix.rect(self, p + Vector2(h - 2.0, -h), Vector2(2.0, h * 2.0), Color(color, ga))
	var perp := dir.orthogonal()
	for j in 3:
		var off := perp * (j - 1) * 9.0
		Pix.line(self, to_local(from) + off, to_local(to) + off, Color(Color.WHITE if j == 1 else color, a * 0.6), 2.0)
	# landing flare: a chevron pointing the way you were going
	var land := to_local(to)
	Pix.line(self, land - dir * 6.0 + perp * 12.0, land + dir * 8.0, Color(Color.WHITE, a), 3.0)
	Pix.line(self, land - dir * 6.0 - perp * 12.0, land + dir * 8.0, Color(Color.WHITE, a), 3.0)


## LOCKDOWN: a square cage slams shut onto the player, corner brackets and tick marks, then padlocks on the rim.
func _draw_lock(k: float) -> void:
	var a := 1.0 - k * k
	var close := pow(clampf(k * 2.2, 0.0, 1.0), 2.0)
	var h := radius * (1.0 - 0.7 * close)
	var w := 3.0
	Pix.rect(self, Vector2(-h, -h), Vector2(h * 2.0, w), Color(color, a))
	Pix.rect(self, Vector2(-h, h - w), Vector2(h * 2.0, w), Color(color, a))
	Pix.rect(self, Vector2(-h, -h), Vector2(w, h * 2.0), Color(color, a))
	Pix.rect(self, Vector2(h - w, -h), Vector2(w, h * 2.0), Color(color, a))
	var bl := minf(h * 0.35, 56.0)   # bright corner brackets
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(sx * h, sy * h)
			Pix.rect(self, c + Vector2(-bl if sx > 0 else 0.0, -w * 0.5 - 1.0 if sy > 0 else -w * 0.5), Vector2(bl, w + 2.0), Color(Color.WHITE, a))
			Pix.rect(self, c + Vector2(0.0 if sx < 0.0 else -bl, -1.0), Vector2(bl, w + 2.0), Color(Color.WHITE, a))
			Pix.rect(self, c + Vector2(-1.0, 0.0 if sy < 0.0 else -bl), Vector2(w + 2.0, bl), Color(Color.WHITE, a))
	var ticks := 8
	for i in ticks:   # ticks creeping along each edge toward the middle
		var f := (float(i) + 0.5) / ticks * 2.0 - 1.0
		var tk := h * f
		Pix.rect(self, Vector2(tk, -h + w), Vector2(2.0, 10.0), Color(color, a * 0.8))
		Pix.rect(self, Vector2(tk, h - w - 10.0), Vector2(2.0, 10.0), Color(color, a * 0.8))
	if close > 0.95:
		Pix.dither_disc_tiled(self, Vector2.ZERO, h * 1.1, Color(color, 0.18 * a))


## DEEP SCAN: a horizontal sweep line crosses the zone top to bottom leaving fading scanline rows, with a target grid.
func _draw_scan(k: float) -> void:
	var a := 1.0 - k * 0.7
	var y := lerpf(-radius, radius, k)
	var half := radius
	Pix.rect(self, Vector2(-half, y - 2.0), Vector2(half * 2.0, 4.0), Color(Color.WHITE, a))
	Pix.rect(self, Vector2(-half, y - 6.0), Vector2(half * 2.0, 4.0), Color(color, a * 0.7))
	var rows := 22
	for i in rows:   # scanlines left in the wake
		var ry := y - 8.0 - i * 6.0
		if ry < -radius:
			break
		var fade := 1.0 - float(i) / rows
		Pix.rect(self, Vector2(-half, ry), Vector2(half * 2.0, 2.0), Color(color, a * 0.35 * fade))
	var cols := 12   # grid ticks on the lines already scanned
	for i in cols + 1:
		var gx := lerpf(-half, half, float(i) / cols)
		Pix.rect(self, Vector2(gx - 1.0, -radius), Vector2(2.0, maxf(0.0, y + radius)), Color(color, 0.12 * a))
	Pix.dot(self, Vector2(-half, y), Color.WHITE, 8.0)
	Pix.dot(self, Vector2(half, y), Color.WHITE, 8.0)


## RESTORE: pixel plus-signs drift up around the player, with a soft green ring.
func _draw_heal(k: float) -> void:
	var a := 1.0 - k
	var n := _cap(count)
	for i in n:
		var ang := TAU * i / n + Pix.rnd(i + _seed) * 0.6
		var rr := radius * (0.25 + 0.75 * Pix.rnd(i * 1.7 + _seed))
		var base := Vector2.from_angle(ang) * rr
		var rise := (k * (50.0 + 70.0 * Pix.rnd(i * 4.3))) * (1.0 if sup else 0.8)
		var p := base + Vector2(0.0, -rise)
		var arm := 4.0 if i % 3 else 6.0
		var c := Color(Color.WHITE if i % 4 == 0 else color, a)
		Pix.rect(self, p + Vector2(-arm, -1.0), Vector2(arm * 2.0 + 1.0, 3.0), c)
		Pix.rect(self, p + Vector2(-1.0, -arm), Vector2(3.0, arm * 2.0 + 1.0), c)
	Pix.ring(self, Vector2.ZERO, radius * (1.0 - pow(1.0 - k, 2.0)) * 0.7, Color(color, a * 0.7), 3.0, 120)


## OVERCLOCK: gear-tooth ring spinning out, with radial speed dashes.
func _draw_clock(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	var teeth := 20
	for i in teeth:
		var ang := TAU * i / teeth + k * 2.5
		var d := Vector2.from_angle(ang)
		var in_r := maxf(0.0, r - (14.0 if i % 2 == 0 else 6.0))
		Pix.line(self, d * in_r, d * r, Color(color, a), 3.0)
	Pix.ring(self, Vector2.ZERO, r, Color(Color.WHITE, a * 0.7), 2.0, 160)
	for i in (8):   # dashes streaking outward
		var ang2 := TAU * i / 8.0 - k * 4.0
		var d2 := Vector2.from_angle(ang2)
		Pix.line(self, d2 * (r * 0.3), d2 * (r * 0.3 + 30.0 * a), Color(Color.WHITE, a), 2.0)


## RAIL STRIKE: a hard white core inside a coloured sheath that thins out, a muzzle flare, grid ticks snapping on along the beam and an impact flare.
func _draw_rail(k: float, out: float) -> void:
	var a := 1.0 - k
	var o := to_local(from)
	var e := to_local(to)
	var dir := (e - o).normalized()
	var perp := dir.orthogonal()
	var step := 4.0
	var sheath := (14.0 if sup else 10.0) * (1.0 - k * 0.8)
	Pix.line(self, o, e, Color(color, 0.35 * a), maxf(2.0, sheath * 1.6 + 4.0))
	Pix.line(self, o, e, Color(color, 0.8 * a), maxf(2.0, sheath))
	Pix.line(self, o, e, Color(Color.WHITE, a), maxf(2.0, step * (1.0 - k * 0.6)))
	var ticks := 10
	var reach := clampf(k * 3.0, 0.0, 1.0)   # the ticks light up from the muzzle outwards in the first third
	for i in ticks:
		var f := (float(i) + 0.5) / ticks
		if f > reach:
			break
		var p := o.lerp(e, f)
		var h := (36.0 if sup else 24.0) * (1.0 - k)
		Pix.line(self, p - perp * h, p + perp * h, Color(Color.WHITE if i % 3 == 0 else color, a * 0.8), 2.0)
	Pix.ring_auto(self, o, 14.0 + 50.0 * out, Color(Color.WHITE, a), 3.0)   # muzzle flare
	Pix.dot(self, o, Color(Color.WHITE, a), 14.0 * (1.0 - k) + 2.0)
	for i in (12):   # sparks thrown off the far end
		var an := dir.angle() + (Pix.rnd(i + _seed) - 0.5) * 2.4
		var d := 70.0 * out * (0.4 + Pix.rnd(i * 2.3))
		Pix.dot(self, e + Vector2.from_angle(an) * d, Color(color, a), 3.0)


## WILDFIRE: a ring of jagged flame tongues sweeps outward over a dithered red-orange wash, with embers lifting off it.
func _draw_fire(k: float, out: float) -> void:
	var a := 1.0 - k * k
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(1.0, 0.35, 0.05, 0.2 * a))
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.6, Color(1.0, 0.7, 0.2, 0.14 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(1.0, 0.3, 0.05, a), 6.0)
	var n := 48
	for i in n:
		var u := Vector2.from_angle(TAU * i / n)
		var flick := 0.6 + 0.4 * sin(t * 20.0 + i * 1.7)
		var h := (24.0 + 40.0 * Pix.rnd(i + _seed)) * flick * (1.0 - k * 0.5)
		var fl := (u * 0.45 + Vector2(0.0, -1.0)).normalized()   # flames lean upward
		var b := u * r
		Pix.line(self, b, b + fl * h, Color(0.9, 0.15, 0.03, a), 6.0)
		Pix.line(self, b, b + fl * h * 0.7, Color(1.0, 0.5, 0.1, a), 4.0)
		Pix.line(self, b, b + fl * h * 0.4, Color(1.0, 0.9, 0.4, a), 2.0)
	for i in (24):   # embers
		var p := Vector2.from_angle(Pix.rnd(i * 5.1 + _seed) * TAU) * r * Pix.rnd(i * 1.3 + _seed) * 0.95
		p.y -= k * (40.0 + 80.0 * Pix.rnd(i * 7.7))
		Pix.dot(self, p, Color(1.0, 0.7 if i % 2 else 0.4, 0.15, a), 3.0 if i % 3 else 2.0)


## DEEP FREEZE: frost spreads out as a white rim with crystal spikes, a six-armed snowflake stamped at the centre, and twinkling sparkles.
func _draw_ice(k: float, out: float) -> void:
	var a := 1.0 - k * k
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(0.75, 0.92, 1.0, 0.2 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(0.9, 0.98, 1.0, a), 5.0)
	Pix.ring_auto(self, Vector2.ZERO, r * 0.94, Color(0.5, 0.85, 1.0, a * 0.6), 3.0)
	var n := 28
	for i in n:   # crystal spikes growing off the rim, inward and outward
		var u := Vector2.from_angle(TAU * i / n + Pix.rnd(i + _seed) * 0.1)
		var len := (10.0 + 24.0 * Pix.rnd(i * 3.3 + _seed)) * minf(1.0, k * 5.0 + 0.3)
		Pix.line(self, u * r, u * (r + len), Color(1.0, 1.0, 1.0, a), 3.0)
		Pix.line(self, u * (r - 4.0), u * (r - len * 0.6), Color(0.6, 0.9, 1.0, a * 0.8), 2.0)
	var arm := r * 0.42 * minf(1.0, out * 1.3)   # the snowflake
	for i in 3:
		var d := Vector2.from_angle(PI * i / 3.0 + PI / 6.0)
		Pix.line(self, -d * arm, d * arm, Color(0.85, 0.97, 1.0, a * 0.8), 3.0)
		for sgn in [-1.0, 1.0]:
			var tip: Vector2 = d * arm * 0.65 * sgn
			Pix.line(self, tip, tip + (-d * sgn + d.orthogonal()).normalized() * 16.0, Color(Color.WHITE, a * 0.8), 2.0)
			Pix.line(self, tip, tip + (-d * sgn - d.orthogonal()).normalized() * 16.0, Color(Color.WHITE, a * 0.8), 2.0)
	for i in (18):   # twinkling plus-sparkles
		if ((int(t * 8.0) + i) & 3) < 2:
			var sp := Vector2.from_angle(Pix.rnd(i * 2.9 + _seed) * TAU) * r * Pix.rnd(i + 9.0 + _seed)
			Pix.rect(self, sp + Vector2(-3, -1), Vector2(7, 3), Color(Color.WHITE, a))
			Pix.rect(self, sp + Vector2(-1, -3), Vector2(3, 7), Color(Color.WHITE, a))


## PAUSE: three pale rings roll out in turn and a PAUSE glyph (two bars) hangs over the player (the clock itself is time_clock.gd).
func _draw_pause(k: float) -> void:
	var a := 1.0 - k
	for i in 3:
		var kk := clampf((k - 0.12 * i) / (1.0 - 0.12 * i), 0.0, 1.0)
		var r := radius * (1.0 + 0.62 * i) * (1.0 - pow(1.0 - kk, 3.0))
		Pix.ring_auto(self, Vector2.ZERO, r, Color(color, (1.0 - kk) * (1.0 - 0.2 * i)), 4.0 - i)
	var gy := -radius * 0.55 - 26.0 - k * 10.0
	Pix.rect(self, Vector2(-11, gy), Vector2(8, 24), Color(Color.WHITE, a))
	Pix.rect(self, Vector2(3, gy), Vector2(8, 24), Color(Color.WHITE, a))


# ---------- player auras (small, ~40 px) ----------

func _aura_a() -> float:
	if not _fading:
		return minf(1.0, t * 6.0)
	return clampf((life - t) / 0.25, 0.0, 1.0)


## OVERCLOCK: a few orbiting spark squares and a jittering amber ring.
func _draw_aura_overclock() -> void:
	var a := _aura_a()
	var n := 5
	for i in n:
		var ang := t * 7.0 + TAU * i / n
		var p := Vector2.from_angle(ang) * 22.0
		Pix.dot(self, p, Color(color, a), 4.0)
		Pix.dot(self, Vector2.from_angle(ang - 0.35) * 22.0, Color(color, a * 0.5), 2.0)
	if fmod(t, 0.2) < 0.1:
		Pix.ring(self, Vector2.ZERO, 26.0, Color(color, a * 0.35), 2.0, 48)


## DEEP SCAN: four rotating corner brackets around the player and a small scanning tick that bobs up and down.
func _draw_aura_scan() -> void:
	var a := _aura_a()
	var h := 26.0 + sin(t * 4.0) * 2.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(sx * h, sy * h)
			Pix.rect(self, c + Vector2(0.0 if sx < 0.0 else -8.0, -1.0), Vector2(9.0, 2.0), Color(color, a))
			Pix.rect(self, c + Vector2(-1.0, 0.0 if sy < 0.0 else -8.0), Vector2(2.0, 9.0), Color(color, a))
	var y := sin(t * 3.0) * h
	Pix.rect(self, Vector2(-h, y), Vector2(h * 2.0, 1.0), Color(color, a * 0.6))


## THUNDERSTORM: short zig-zag sparks jump around the player several times a second.
func _draw_aura_storm() -> void:
	var a := _aura_a()
	var step := floorf(t * 12.0)
	var arcs := 3
	for i in arcs:
		var ang := Pix.rnd(step + i * 7.0 + _seed) * TAU
		var p := Vector2.from_angle(ang) * 14.0
		for j in 3:
			var nxt := p + Vector2.from_angle(ang + (Pix.rnd(step * 3.0 + j + i) - 0.5) * 1.6) * 8.0
			Pix.line(self, p, nxt, Color(Color.WHITE if j == 1 else color, a), 2.0)
			p = nxt
	Pix.dot(self, Vector2(0.0, -34.0 + sin(t * 9.0) * 2.0), Color(color, a * 0.8), 3.0)
