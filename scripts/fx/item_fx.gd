extends Node2D
## Pixel-snapped one-shot FX for items and pickups (same style as ability_fx.gd / the weapon FX: whole-pixel squares, dithered fills,
## hard-edged rings, no antialiasing and no soft glow). One short-lived node per effect; Game.ifx() spawns them.
## kind: "shock" (BACKFIRE) | "nova" (KILLSTREAK, PURGE pickup) | "blast" (FLASHPOINT) | "shatter" (COLD SNAP) | "spore" (PLAGUE VECTOR)
## | "rage" | "boom" (DECOY) | "drop" (TOTEM / BEACON landing) | "pulse" (TOTEM tick) | "block" (GUARDIAN) | "heal" | "suck" (DEFRAG)
## | "cache" (CACHE decrypted) | "levelup" (upgrade offer opens) | "tier" (combo tier reached) | "rarity" (upgrade picked; `size` = rarity 1 rare / 2 epic / 3 legendary). `radius` is the reach, `life` the playback time, `color` the theme. Mark counts are capped.

const Pix = preload("res://scripts/fx/pix.gd")

var kind := "shock"
var color := Color.WHITE
var radius := 160.0
var life := 0.5
var size := 3.0
var t := 0.0
var _seed := 0.0


func _ready() -> void:
	_seed = randf() * 100.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _cap(n: int) -> int:
	return n


func _v(ang: float, r: float) -> Vector2:
	return Vector2.from_angle(ang) * r


## fire ramp: white-hot -> yellow -> orange -> deep red as f goes 0..1
func _fire(f: float, a: float) -> Color:
	if f < 0.25:
		return Color(1.0, 1.0, 0.85, a)
	if f < 0.5:
		return Color(1.0, 0.85, 0.25, a)
	if f < 0.75:
		return Color(1.0, 0.5, 0.12, a)
	return Color(0.75, 0.15, 0.1, a)


func _draw() -> void:
	var k := clampf(t / maxf(life, 0.001), 0.0, 1.0)
	var out := 1.0 - pow(1.0 - k, 3.0)
	match kind:
		"shock": _shock(k, out)
		"nova": _nova(k, out)
		"blast": _blast(k, out)
		"shatter": _shatter(k, out)
		"spore": _spore(k, out)
		"rage": _rage(k, out)
		"boom": _boom(k, out)
		"drop": _drop(k, out)
		"pulse": _pulse(k, out)
		"block": _block(k, out)
		"heal": _heal(k)
		"suck": _suck(k)
		"cache": _cache(k, out)
		"levelup": _levelup(k, out)
		"tier": _tier(k, out)
		"rarity": _rarity(k, out)


## BACKFIRE: a hard white snap-ring and a coloured shockwave with spikes thrown outward, a dithered flood behind them.
func _shock(k: float, out: float) -> void:
	var r := radius * out
	var a := 1.0 - k
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(color, 0.2 * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.82, Color(color, a * 0.85), maxf(2.0, 6.0 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, a), maxf(2.0, 4.0 * a))
	var n := _cap(14)
	for i in n:
		var ang := TAU * i / n + 0.2 + Pix.rnd(i + _seed) * 0.15
		Pix.line(self, _v(ang, r * 0.6), _v(ang, r * (0.92 + 0.08 * Pix.rnd(i * 2.3))), Color(Color.WHITE if i % 3 == 0 else color, a), 3.0 if i % 2 == 0 else 2.0)
	if k < 0.3:
		Pix.dither_disc(self, Vector2.ZERO, 34.0 * (1.0 - k / 0.3) + 6.0, Color(Color.WHITE, 1.0 - k / 0.3))


## KILLSTREAK / PURGE pickup: a golden flood with a double rim, a rotating ring of rays and a star at the heart.
func _nova(k: float, out: float) -> void:
	var r := radius * out
	var a := 1.0 - k
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(color, 0.18 * a))
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.55, Color(Color.WHITE, 0.14 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, a), maxf(2.0, size * 1.6 * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.9, Color(color, a * 0.9), maxf(2.0, size * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.7, Color(color, a * 0.4), 2.0)
	var rays := _cap(16)
	for i in rays:
		var ang := TAU * i / rays + k * 0.9
		var long := i % 2 == 0
		Pix.line(self, _v(ang, r * 0.35), _v(ang, r * (0.9 if long else 0.68)), Color(Color.WHITE if long else color, a), 3.0 if long else 2.0)
	var s := (1.0 - k) * minf(radius * 0.18, 44.0)
	for i in 4:   # four-point star
		var ang2 := PI / 2.0 * i
		Pix.line(self, Vector2.ZERO, _v(ang2, s * 1.4), Color(Color.WHITE, a), 4.0)
		Pix.line(self, Vector2.ZERO, _v(ang2 + PI / 4.0, s * 0.8), Color(color, a), 3.0)
	for i in _cap(14):   # sparks
		var ang3 := TAU * (i + Pix.rnd(i + _seed)) / 14.0
		Pix.dot(self, _v(ang3, r * (0.5 + 0.55 * Pix.rnd(i * 5.1))), Color(Color.WHITE if i % 3 == 0 else color, a), 4.0 if k < 0.5 else 2.0)


## FLASHPOINT: a flare of flame tongues thrown out of the corpse, white-hot at the root and deep red at the tips, with embers climbing.
func _blast(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.9, Color(1.0, 0.45, 0.1, 0.22 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(1.0, 0.85, 0.35, a), maxf(2.0, 5.0 * a))
	var n := _cap(11)
	for i in n:
		var ang := TAU * i / n + Pix.rnd(i + _seed) * 0.5
		var reach := r * (0.55 + 0.45 * Pix.rnd(i * 3.7 + _seed))
		var steps := 8
		for j in steps:
			var f := float(j) / (steps - 1)
			var p := _v(ang + sin(f * 3.0 + i) * 0.12, reach * f) + Vector2(0, -f * 12.0 * k)
			Pix.dot(self, p, _fire(f + k * 0.4, a), maxf(2.0, 6.0 * (1.0 - f * 0.7) * a))
	for i in _cap(10):
		var ang2 := TAU * Pix.rnd(i * 1.7 + _seed)
		var p2 := _v(ang2, r * 0.7 * Pix.rnd(i * 4.4)) + Vector2(0, -k * (30.0 + 30.0 * Pix.rnd(i)))
		Pix.dot(self, p2, Color(1.0, 0.8, 0.3, a), 2.0)
	if k < 0.3:
		Pix.dither_disc(self, Vector2.ZERO, 26.0 * (1.0 - k / 0.3) + 4.0, Color(1.0, 0.95, 0.8, 1.0 - k / 0.3))


## COLD SNAP: a snowflake flashes in the centre, then ice shards of two sizes fly out and spin away.
func _shatter(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.8, Color(0.6, 0.9, 1.0, 0.15 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(0.85, 0.97, 1.0, a), maxf(2.0, 4.0 * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.88, Color(color, a * 0.5), 2.0)
	if k < 0.45:
		var fa := 1.0 - k / 0.45
		var ln := 20.0 + 10.0 * k
		for i in 6:
			var ang := TAU * i / 6.0 + PI / 6.0
			Pix.line(self, Vector2.ZERO, _v(ang, ln), Color(Color.WHITE, fa), 3.0)
			Pix.line(self, _v(ang, ln * 0.6), _v(ang + 0.7, ln * 0.85), Color(color, fa), 2.0)
			Pix.line(self, _v(ang, ln * 0.6), _v(ang - 0.7, ln * 0.85), Color(color, fa), 2.0)
	var n := _cap(14)
	for i in n:
		var ang2 := TAU * (i + Pix.rnd(i + _seed) * 0.8) / n
		var d := r * (0.45 + 0.55 * Pix.rnd(i * 3.3 + _seed))
		var p := _v(ang2, d)
		var big := i % 3 == 0
		var s := 6.0 if big else 4.0
		Pix.dot(self, p, Color(Color.WHITE, a), s)   # diamond: centre plus four tips
		for q in 4:
			Pix.dot(self, p + _v(PI / 2.0 * q + k * 2.0, s), Color(color, a), s * 0.5)


## PLAGUE VECTOR: a ring of sickly spores; hollow bubbles rise and pop, dots drift out.
func _spore(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.9, Color(0.45, 0.9, 0.2, 0.2 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(0.7, 1.0, 0.35, a * 0.9), maxf(2.0, 4.0 * a))
	var n := _cap(12)
	for i in n:
		var ang := TAU * (i + Pix.rnd(i + _seed) * 0.9) / n
		var d := r * (0.25 + 0.7 * Pix.rnd(i * 2.9 + _seed))
		var p := _v(ang, d) + Vector2(sin(t * 6.0 + i) * 3.0, -k * 26.0)
		var rr := 4.0 + 5.0 * Pix.rnd(i * 6.1)
		if i % 3 == 0:
			Pix.ring(self, p, rr * (0.5 + 0.5 * k), Color(0.75, 1.0, 0.4, a), 2.0)
			Pix.dot(self, p + Vector2(-rr * 0.3, -rr * 0.3), Color(Color.WHITE, a), 2.0)
		else:
			Pix.dot(self, p, Color(0.55, 0.95, 0.25, a), 4.0 if k < 0.5 else 2.0)
	if k < 0.25:
		Pix.dither_disc(self, Vector2.ZERO, 18.0, Color(0.85, 1.0, 0.5, 1.0 - k / 0.25))


## RAGE.EXE: a red shockwave and chevrons that climb off the player, speed lines streaking outward.
func _rage(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(color, 0.18 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, a), maxf(2.0, 4.0 * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.8, Color(color, a), maxf(2.0, 7.0 * a))
	for j in 3:
		var kk := clampf(k * 1.4 - j * 0.14, 0.0, 1.0)
		if kk <= 0.0 or kk >= 1.0:
			continue
		var y := -14.0 - kk * 90.0
		var ca := 1.0 - kk
		Pix.line(self, Vector2(-16, y + 10), Vector2(0, y), Color(Color.WHITE if j == 0 else color, ca), 4.0)
		Pix.line(self, Vector2(16, y + 10), Vector2(0, y), Color(Color.WHITE if j == 0 else color, ca), 4.0)
	var n := _cap(12)
	for i in n:
		var ang := TAU * i / n + Pix.rnd(i + _seed)
		Pix.line(self, _v(ang, r * 0.35), _v(ang, r * 0.75), Color(color, a * 0.8), 2.0)


## DECOY detonation: a fat dithered fireball with white core, flame tongues, thrown debris and a smoke ring that lingers.
func _boom(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(1.0, 0.5, 0.12, 0.28 * a))
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.6, Color(1.0, 0.85, 0.4, 0.22 * a))
	if k > 0.45:
		Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.85, Color(0.35, 0.3, 0.3, 0.2 * (1.0 - (k - 0.45) / 0.55)))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, a), maxf(2.0, 6.0 * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.9, Color(1.0, 0.55, 0.15, a), maxf(2.0, 8.0 * a))
	var n := _cap(10)
	for i in n:
		var ang := TAU * i / n + Pix.rnd(i + _seed) * 0.4
		var reach := r * (0.5 + 0.45 * Pix.rnd(i * 2.1 + _seed))
		for j in 7:
			var f := float(j) / 6.0
			Pix.dot(self, _v(ang, reach * f), _fire(f + k * 0.5, a), maxf(2.0, 7.0 * (1.0 - f * 0.6) * a))
	for i in _cap(16):   # debris with a little gravity
		var ang2 := TAU * Pix.rnd(i * 1.3 + _seed)
		var sp := radius * (0.5 + 0.7 * Pix.rnd(i * 7.7))
		var p := _v(ang2, sp * out) + Vector2(0, 120.0 * k * k)
		Pix.dot(self, p, Color(Color.WHITE if i % 4 == 0 else Color(1.0, 0.7, 0.25), a), 4.0 if i % 3 == 0 else 2.0)
	if k < 0.3:
		Pix.dither_disc(self, Vector2.ZERO, 40.0 * (1.0 - k / 0.3) + 6.0, Color(Color.WHITE, 1.0 - k / 0.3))


## TOTEM / BEACON landing: a column of light drops from above and slams into the ground in a ring with a fountain of squares.
func _drop(k: float, out: float) -> void:
	var a := 1.0 - k
	if k < 0.4:
		var kk := k / 0.4
		var w := 4.0 + (1.0 - kk) * 14.0
		Pix.rect(self, Vector2(-w * 0.5, -260.0 * (1.0 - kk * 0.5)), Vector2(w, 260.0 * (1.0 - kk * 0.5)), Color(color, 0.5 * (1.0 - kk * 0.5)))
		Pix.rect(self, Vector2(-w * 0.25, -260.0 * (1.0 - kk * 0.5)), Vector2(maxf(2.0, w * 0.5), 260.0 * (1.0 - kk * 0.5)), Color(Color.WHITE, 0.8))
	var kr := clampf((k - 0.15) / 0.85, 0.0, 1.0)
	if kr > 0.0:
		var r := radius * (1.0 - pow(1.0 - kr, 3.0))
		var ra := 1.0 - kr
		Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, ra), maxf(2.0, 4.0 * ra))
		Pix.ring_auto(self, Vector2.ZERO, r * 0.9, Color(color, ra * 0.8), maxf(2.0, 6.0 * ra))
		Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(color, 0.14 * ra))
		for i in _cap(12):
			var ang := TAU * i / 12.0 + Pix.rnd(i + _seed)
			var d := 70.0 * (1.0 - pow(1.0 - kr, 2.0)) * (0.4 + Pix.rnd(i * 3.0))
			Pix.dot(self, Vector2(cos(ang) * d, -absf(sin(ang)) * d * 0.9 + 60.0 * kr * kr), Color(Color.WHITE if i % 3 == 0 else color, ra), 4.0 if kr < 0.5 else 2.0)


## TOTEM tick: a fast thin ring with rune ticks riding on it.
func _pulse(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	Pix.ring_auto(self, Vector2.ZERO, r, Color(color, a * 0.9), 3.0)
	Pix.ring_auto(self, Vector2.ZERO, maxf(1.0, r - 6.0), Color(Color.WHITE, a * 0.5), 2.0)
	var n := _cap(10)
	for i in n:
		var ang := TAU * i / n + k * 1.2
		Pix.line(self, _v(ang, maxf(1.0, r - 9.0)), _v(ang, r + 3.0), Color(Color.WHITE, a), 3.0)


## GUARDIAN: a quick starburst where the orb swatted a shot.
func _block(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	for i in 8:
		var ang := PI / 4.0 * i
		Pix.line(self, _v(ang, r * 0.35), _v(ang, r), Color(Color.WHITE if i % 2 == 0 else color, a), 2.0)
	Pix.dot(self, Vector2.ZERO, Color(Color.WHITE, a), maxf(2.0, 8.0 * a))


## REPAIR PATCH pickup: plus signs float up off the player.
func _heal(k: float) -> void:
	var n := _cap(6)
	for i in n:
		var kk := clampf(k * 1.3 - i * 0.05, 0.0, 1.0)
		if kk <= 0.0 or kk >= 1.0:
			continue
		var ang := TAU * i / n + _seed
		var p := _v(ang, 12.0 + 10.0 * Pix.rnd(i + _seed)) + Vector2(sin(kk * 7.0 + i) * 4.0, -kk * 56.0)
		var ca := 1.0 - kk
		var s := 6.0 if i % 2 == 0 else 4.0
		Pix.rect(self, p - Vector2(1, s * 0.5), Vector2(2, s), Color(Color.WHITE if i % 3 == 0 else color, ca))
		Pix.rect(self, p - Vector2(s * 0.5, 1), Vector2(s, 2), Color(Color.WHITE if i % 3 == 0 else color, ca))
	Pix.ring_auto(self, Vector2.ZERO, 14.0 + 20.0 * k, Color(color, (1.0 - k) * 0.7), 2.0)


## DEFRAG pickup: rings imploding toward the player, then a bright flash.
func _suck(k: float) -> void:
	for j in 3:
		var kk := clampf(k * 1.5 - j * 0.15, 0.0, 1.0)
		if kk <= 0.0 or kk >= 1.0:
			continue
		var r := radius * (1.0 - kk)
		Pix.ring_auto(self, Vector2.ZERO, r, Color(color, kk * 0.9), maxf(2.0, 4.0 * kk))
		var n := _cap(8)
		for i in n:
			var ang := TAU * i / n + j
			Pix.dot(self, _v(ang, r), Color(Color.WHITE, kk), 4.0)
	if k > 0.6:
		var f := (k - 0.6) / 0.4
		Pix.dither_disc(self, Vector2.ZERO, 22.0 * (1.0 - f) + 4.0, Color(Color.WHITE, 1.0 - f))


## CACHE decrypted: gold brackets snap open around the pickup with glitch bars and rising data bits.
func _cache(k: float, out: float) -> void:
	var a := 1.0 - k
	var h := 14.0 + radius * out
	var w := 3.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c: Vector2 = corner * h
		var bl := minf(18.0, h * 0.6)
		Pix.rect(self, c + Vector2(-bl if corner.x > 0 else 0.0, -w * 0.5), Vector2(bl, w), Color(color, a))
		Pix.rect(self, c + Vector2(-w * 0.5, -bl if corner.y > 0 else 0.0), Vector2(w, bl), Color(color, a))
	Pix.ring_auto(self, Vector2.ZERO, radius * out, Color(Color.WHITE, a * 0.7), 3.0)
	for i in _cap(7):
		var y := (Pix.rnd(i * 3.3 + floorf(t * 24.0)) - 0.5) * h * 2.0
		var x := (Pix.rnd(i * 5.7 + floorf(t * 24.0)) - 0.5) * h
		Pix.rect(self, Vector2(x, y), Vector2(8.0 + 20.0 * Pix.rnd(i + 9.0), 2.0), Color(color, a * 0.8))
	for i in _cap(10):
		var ang := TAU * Pix.rnd(i * 2.2 + _seed)
		Pix.dot(self, _v(ang, 10.0 + radius * 0.5 * out * Pix.rnd(i * 4.0)) + Vector2(0, -k * 40.0), Color(Color.WHITE if i % 2 == 0 else color, a), 3.0)


## LEVEL UP / upgrade offer: a column of light climbs off the player, a double ring snaps out, and square data bits fountain upward.
func _levelup(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	var h := 150.0 * out
	Pix.rect(self, Vector2(-9.0 * a - 1.0, -h), Vector2(maxf(2.0, 18.0 * a), h), Color(color, 0.35 * a))
	Pix.rect(self, Vector2(-3.0, -h), Vector2(6.0, h), Color(Color.WHITE, 0.8 * a))
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.8, Color(color, 0.16 * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, a), maxf(2.0, 5.0 * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.72, Color(color, a * 0.9), maxf(2.0, 7.0 * a))
	for j in 3:   # chevrons climbing the column, staggered
		var kk := clampf(k * 1.5 - j * 0.18, 0.0, 1.0)
		if kk <= 0.0 or kk >= 1.0:
			continue
		var y := -20.0 - kk * 110.0
		Pix.line(self, Vector2(-14, y + 9), Vector2(0, y), Color(Color.WHITE if j == 0 else color, 1.0 - kk), 4.0)
		Pix.line(self, Vector2(14, y + 9), Vector2(0, y), Color(Color.WHITE if j == 0 else color, 1.0 - kk), 4.0)
	for i in _cap(16):
		var ph := fposmod(k * 1.2 + Pix.rnd(i * 2.7 + _seed), 1.0)
		var x := (Pix.rnd(i * 4.1 + _seed) - 0.5) * 70.0
		Pix.dot(self, Vector2(x, -ph * 120.0), Color(Color.WHITE if i % 3 == 0 else color, a * (1.0 - ph)), 4.0 if ph < 0.5 else 2.0)
	if k < 0.25:
		Pix.dither_disc(self, Vector2.ZERO, 30.0 * (1.0 - k / 0.25) + 6.0, Color(Color.WHITE, 1.0 - k / 0.25))


## COMBO TIER reached: a rotating diamond frame of `size` corner pips (the tier number) flashes round the player with a tight snap ring.
func _tier(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, a), maxf(2.0, 4.0 * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.85, Color(color, a * 0.8), maxf(2.0, 6.0 * a))
	var n := 4
	for i in n:
		var ang := PI / 2.0 * i + k * 1.6
		var p := _v(ang, r * 0.85)
		Pix.dot(self, p, Color(Color.WHITE, a), 8.0)
		Pix.line(self, p, _v(ang + 0.5, r * 0.55), Color(color, a), 3.0)
		Pix.line(self, p, _v(ang - 0.5, r * 0.55), Color(color, a), 3.0)
	for i in int(size):   # one pip per tier above the player
		Pix.dot(self, Vector2((i - (size - 1.0) * 0.5) * 12.0, -30.0 - k * 22.0), Color(color if i % 2 == 0 else Color.WHITE, a), 6.0)
	for i in _cap(10):
		var ang2 := TAU * (i + Pix.rnd(i + _seed)) / 10.0
		Pix.dot(self, _v(ang2, r * (0.4 + 0.6 * Pix.rnd(i * 3.1))), Color(Color.WHITE if i % 3 == 0 else color, a), 4.0 if k < 0.5 else 2.0)


## Upgrade picked, scaled by rarity (size 1..3): rare = ring and sparks; epic adds a light column and spinning diamonds; legendary adds
## a crown of rays, twin pillars, a white-hot flood and a gold shower.
func _rarity(k: float, out: float) -> void:
	var a := 1.0 - k
	var r := radius * out
	var tier := int(size)
	Pix.dither_disc_tiled(self, Vector2.ZERO, r * 0.8, Color(color, (0.1 + 0.05 * tier) * a))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(Color.WHITE, a), maxf(2.0, (3.0 + 2.0 * tier) * a))
	Pix.ring_auto(self, Vector2.ZERO, r * 0.78, Color(color, a * 0.9), maxf(2.0, (4.0 + 2.0 * tier) * a))
	if tier >= 2:
		var h := (160.0 + 60.0 * tier) * minf(1.0, out * 1.6)
		var w := (10.0 + 6.0 * tier) * a
		Pix.rect(self, Vector2(-w * 0.5, -h), Vector2(maxf(2.0, w), h), Color(color, 0.4 * a))
		Pix.rect(self, Vector2(-2.0, -h), Vector2(4.0, h), Color(Color.WHITE, 0.8 * a))
		for i in 4:   # diamonds orbiting the frame
			var ang := PI / 2.0 * i + k * 2.4
			var p := _v(ang, r * 0.78)
			Pix.dot(self, p, Color(Color.WHITE, a), 8.0)
			for q in 4:
				Pix.dot(self, p + _v(PI / 2.0 * q, 7.0), Color(color, a), 4.0)
	if tier >= 3:
		var rays := _cap(20)
		for i in rays:
			var ang2 := TAU * i / rays + k * 0.6
			var long := i % 2 == 0
			Pix.line(self, _v(ang2, r * 0.2), _v(ang2, r * (0.95 if long else 0.65)), Color(Color.WHITE if long else color, a), 4.0 if long else 2.0)
		for sx in [-1.0, 1.0]:   # twin pillars either side
			Pix.rect(self, Vector2(sx * r * 0.5 - 3.0, -200.0 * out), Vector2(6.0, 200.0 * out), Color(color, 0.5 * a))
		for i in _cap(24):   # gold shower falling back down
			var ph := fposmod(k * 1.1 + Pix.rnd(i * 2.9 + _seed), 1.0)
			var x := (Pix.rnd(i * 4.7 + _seed) - 0.5) * r * 1.6
			Pix.dot(self, Vector2(x, -160.0 + ph * 200.0), Color(Color.WHITE if i % 4 == 0 else color, a), 4.0 if i % 3 == 0 else 2.0)
	if k < 0.25:
		Pix.dither_disc(self, Vector2.ZERO, (20.0 + 14.0 * tier) * (1.0 - k / 0.25) + 6.0, Color(Color.WHITE, 1.0 - k / 0.25))
	for i in _cap(8 + 4 * tier):
		var ang3 := TAU * (i + Pix.rnd(i + _seed)) / (8.0 + 4.0 * tier)
		Pix.dot(self, _v(ang3, r * (0.3 + 0.7 * Pix.rnd(i * 3.3))), Color(Color.WHITE if i % 3 == 0 else color, a), 4.0 if k < 0.5 else 2.0)
