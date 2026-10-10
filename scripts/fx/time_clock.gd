extends Node2D
const Pix = preload("res://scripts/fx/pix.gd")
## PAUSE's clockwork: a big translucent bronze dial that fades in over the player while time is stopped. Meshing gears turn in
## steps with the ticks, the second hand jumps forward, and pixel digits show the seconds left. The ticks speed up (and rise in
## pitch) as the stop runs out. Follows `target`, then fades away. A newer clock (SUPER PAUSE) calls dismiss() on the old one.

const BRONZE_DK := Color(0.30, 0.17, 0.07)
const BRONZE := Color(0.72, 0.45, 0.17)
const BRONZE_LT := Color(0.96, 0.74, 0.40)
const BRONZE_HI := Color(1.0, 0.92, 0.7)

## 3x5 pixel digits (row bitmasks, bit 2 = left column) for the seconds-left readout
const DIGITS := {
	0: [7, 5, 5, 5, 7], 1: [2, 6, 2, 2, 7], 2: [7, 1, 7, 4, 7], 3: [7, 1, 7, 1, 7], 4: [5, 5, 7, 1, 1],
	5: [7, 4, 7, 1, 7], 6: [7, 4, 7, 5, 7], 7: [7, 1, 1, 1, 1], 8: [7, 5, 7, 5, 7], 9: [7, 5, 7, 1, 7],
}

var color := Color(0.75, 0.9, 1.0)   # the ice-blue ghost glow behind the bronze
var life := 4.0
var radius := 170.0
var target: Node2D = null
var t := 0.0
var next_tick := 0.5
var ticks := 0
var angle := 0.0
var last_tick := 0.0
var gear := 0.0        # eased gear rotation (radians), chases `gear_goal` which steps on every tick
var gear_goal := 0.0
var _dismissed_at := -1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Fades the clock out right away (a bigger clock is taking over).
func dismiss() -> void:
	if _dismissed_at < 0.0:
		_dismissed_at = t


func _process(delta: float) -> void:
	t += delta
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -20)
	if _dismissed_at < 0.0 and t >= next_tick and t < life:
		ticks += 1
		last_tick = t
		var k := t / life
		angle += TAU / 60.0 * 3.0
		gear_goal += TAU / 24.0
		next_tick = t + lerpf(0.55, 0.16, k * k)
	gear = lerpf(gear, gear_goal, 1.0 - exp(-22.0 * delta))
	if (_dismissed_at >= 0.0 and t >= _dismissed_at + 0.2) or t >= life + 0.5:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade_in := clampf(t / 0.35, 0.0, 1.0)
	var fade_out := clampf((life + 0.5 - t) / 0.5, 0.0, 1.0)
	if _dismissed_at >= 0.0:
		fade_out = minf(fade_out, clampf(1.0 - (t - _dismissed_at) / 0.2, 0.0, 1.0))
	var a := fade_in * fade_out
	var pop := 1.0 + 0.25 * (1.0 - fade_in) * (1.0 - fade_in)   # settles in from slightly larger
	var r := radius * pop
	var drift := 0.5 + 0.5 * sin(t * 2.0)
	# dithered dial: ice glow rim outside, dark bronze plate inside
	Pix.dither_disc_tiled(self, Vector2.ZERO, r + 6.0, Color(color, 0.10 * a))
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(BRONZE_DK, (0.55 + 0.08 * drift) * a))
	# bronze bezel: dark outer edge, bright body, highlight, with rivets
	Pix.ring_auto(self, Vector2.ZERO, r + 6.0, Color(BRONZE_DK, 0.9 * a), 4.0)
	Pix.ring_auto(self, Vector2.ZERO, r + 2.0, Color(BRONZE, 0.95 * a), 6.0)
	Pix.ring_auto(self, Vector2.ZERO, r, Color(BRONZE_LT, 0.9 * a), 2.0)
	Pix.ring_auto(self, Vector2.ZERO, r * 0.84, Color(BRONZE, 0.55 * a), 2.0)
	for i in 8:
		var u := Vector2.from_angle(TAU * (i + 0.5) / 8.0)
		Pix.dot(self, u * (r + 2.0), Color(BRONZE_HI, 0.9 * a), 4.0)
	# hour marks (12 big, 48 small)
	for i in 60:
		var d := Vector2.from_angle(TAU * i / 60.0 - PI / 2.0)
		var big := i % 5 == 0
		Pix.line(self, d * (r * 0.84 - (14.0 if big else 6.0)), d * (r * 0.84 - 2.0), Color(BRONZE_LT if big else BRONZE, (0.95 if big else 0.6) * a), 3.0 if big else 2.0)
	# meshing gears (they step with the ticks, so the movement is visibly ticking, not spinning smoothly)
	var ga := Vector2(-0.30, -0.22) * r
	var gb := Vector2(0.27, -0.10) * r
	var gc := Vector2(-0.02, 0.18) * r
	_gear(ga, r * 0.30, 12, gear, a)
	_gear(gb, r * 0.22, 9, -gear * 12.0 / 9.0 + PI / 9.0, a)
	_gear(gc, r * 0.15, 7, gear * 12.0 / 7.0 + PI / 7.0, a)
	# a plaque under the hub with the seconds left, in pop-in pixel digits
	var left := ceili(maxf(0.0, life - t))
	var py := r * 0.52
	var cell := maxf(4.0, roundf(r / 28.0))
	Pix.rect(self, Vector2(-cell * 3.0, py - cell * 3.6), Vector2(cell * 6.0, cell * 7.2), Color(BRONZE_DK, 0.9 * a))
	Pix.rect(self, Vector2(-cell * 3.0, py - cell * 3.6), Vector2(cell * 6.0, 2.0), Color(BRONZE_LT, 0.9 * a))
	Pix.rect(self, Vector2(-cell * 3.0, py + cell * 3.6 - 2.0), Vector2(cell * 6.0, 2.0), Color(BRONZE_LT, 0.9 * a))
	if t < life and left > 0:
		var frac := (life - t) - floorf(life - t)
		_digit(left, Vector2(0.0, py), cell + (2.0 if frac > 0.85 else 0.0), a)
	# hands: bronze hour / minute unwinding, and the gold second hand that jumps and overshoots like an escapement
	var minute := Vector2.from_angle(-t * 0.9 - PI / 2.0)
	var hour := Vector2.from_angle(-t * 0.075 - PI / 2.0)
	Pix.line(self, Vector2.ZERO, hour * r * 0.45, Color(BRONZE_DK, 0.9 * a), 7.0)
	Pix.line(self, Vector2.ZERO, hour * r * 0.45, Color(BRONZE_LT, 0.95 * a), 4.0)
	Pix.line(self, Vector2.ZERO, minute * r * 0.66, Color(BRONZE_DK, 0.9 * a), 5.0)
	Pix.line(self, Vector2.ZERO, minute * r * 0.66, Color(BRONZE_LT, 0.95 * a), 3.0)
	var jolt := 0.0
	if ticks > 0:
		jolt = exp(-18.0 * (t - last_tick)) * 0.06
	var sec := Vector2.from_angle(angle - PI / 2.0 + jolt)
	for j in 1 + mini(ticks, 4):
		var back := Vector2.from_angle(angle - PI / 2.0 - j * TAU / 20.0)
		Pix.line(self, Vector2.ZERO, back * r * 0.8, Color(color, 0.16 * a / (j + 1)), 2.0)
	Pix.line(self, -sec * r * 0.14, sec * r * 0.8, Color(1.0, 0.85, 0.45, 0.95 * a), 2.0)
	Pix.dot(self, Vector2.ZERO, Color(BRONZE_DK, a), 12.0)
	Pix.dot(self, Vector2.ZERO, Color(BRONZE_HI, a), 6.0)


## A pixel gear: toothed rim, hollow body, spokes and a centre pin. `rad` is the root radius, teeth stick out 20% more.
func _gear(c: Vector2, rad: float, teeth: int, rot: float, a: float) -> void:
	var out := rad * 1.22
	for i in teeth:
		var u := Vector2.from_angle(rot + TAU * i / teeth)
		Pix.line(self, c + u * rad * 0.92, c + u * out, Color(BRONZE_DK, 0.9 * a), 6.0)
		Pix.line(self, c + u * rad * 0.92, c + u * out, Color(BRONZE, 0.95 * a), 4.0)
	Pix.ring_auto(self, c, rad, Color(BRONZE, 0.95 * a), 4.0)
	Pix.ring_auto(self, c, rad * 0.62, Color(BRONZE_DK, 0.85 * a), 2.0)
	for i in 4:
		var u := Vector2.from_angle(rot + TAU * i / 4.0)
		Pix.line(self, c, c + u * rad * 0.9, Color(BRONZE_LT, 0.7 * a), 2.0)
	Pix.dot(self, c, Color(BRONZE_HI, a), 4.0)


func _digit(n: int, center: Vector2, cell: float, a: float) -> void:
	var rows: Array = DIGITS[clampi(n, 0, 9)]
	var o := center - Vector2(1.5, 2.5) * cell
	for y in 5:
		for x in 3:
			if (rows[y] >> (2 - x)) & 1:
				Pix.rect(self, o + Vector2(x, y) * cell, Vector2(cell, cell), Color(BRONZE_HI, 0.98 * a))
