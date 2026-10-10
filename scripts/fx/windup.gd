extends Node2D
const FD = preload("res://scripts/fx/fd.gd")
## Charge-up shown before a class ability fires: a ring that collapses onto the player plus a style per ability
## (rail = vertical neon lines and an aim line, fire = flame spikes, storm = crackling arcs, ice = shards).
## Follows `target` while it charges, then frees itself.

var color := Color.WHITE
var style := "rail"
var life := 0.4
var radius := 150.0
var super_cast := false
var target: Node2D = null
var facing := Vector2.RIGHT
var t := 0.0
var seed_t := 0.0


func _process(delta: float) -> void:
	t += delta
	seed_t += delta
	if is_instance_valid(target):
		global_position = target.global_position
	if t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	var e := k * k   # accelerates into the cast
	var r := radius * (1.0 - e) + 14.0
	var a := 0.35 + 0.65 * k
	var w := 3.0 + 4.0 * k
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, a * 0.25), w * 3.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, a), w)
	FD.circle(self, Vector2.ZERO, 10.0 + 22.0 * e, Color(color, 0.25 + 0.35 * e))
	if super_cast:
		draw_arc(Vector2.ZERO, r * 1.45, 0.0, TAU, 48, Color(Color.WHITE, a * 0.7), w * 0.6)
	match style:
		"rail":
			# vertical tron lines closing in from both sides, plus a growing aim line along the facing
			for i in 5:
				var x := (i - 2) * 30.0 * (1.0 - e) * 2.0
				draw_line(Vector2(x, -radius * 1.2), Vector2(x, radius * 1.2), Color(color, a * 0.6), 2.0)
			draw_line(Vector2.ZERO, facing * 1400.0 * e, Color(Color.WHITE, 0.25 + 0.5 * e), 1.0 + 3.0 * e)
		"fire":
			for i in 12:
				var ang := TAU * i / 12.0 + seed_t * 3.0
				var flame_len := (24.0 + 40.0 * e) * (1.0 + 0.5 * sin(seed_t * 20.0 + i * 1.7))
				var base := Vector2.RIGHT.rotated(ang) * r
				draw_line(base, base + Vector2.RIGHT.rotated(ang) * flame_len, Color(1.0, 0.55 + 0.3 * e, 0.1, a), 3.0)
		"storm":
			for i in 6:
				var ang := TAU * i / 6.0 + seed_t * 6.0
				var p0 := Vector2.RIGHT.rotated(ang) * r
				var p1 := p0.lerp(Vector2.ZERO, 0.5) + Vector2.RIGHT.rotated(ang + 1.57) * randf_range(-18.0, 18.0)
				var p2 := Vector2.RIGHT.rotated(ang) * (r * 0.3)
				draw_polyline(PackedVector2Array([p0, p1, p2]), Color(color, a), 2.0)
		"heal":
			# plus signs drifting up into the player and a pulsing green core
			for i in 6:
				var ang2 := TAU * i / 6.0 + seed_t
				var c := Vector2.RIGHT.rotated(ang2) * r * 0.9 + Vector2(0, -40.0 * k)
				draw_line(c - Vector2(7, 0), c + Vector2(7, 0), Color(color, a), 3.0)
				draw_line(c - Vector2(0, 7), c + Vector2(0, 7), Color(color, a), 3.0)
			FD.circle(self, Vector2.ZERO, 18.0 + 8.0 * sin(seed_t * 18.0), Color(color, 0.3))
		"clock":
			# a dial whose hand spins faster and faster, with tick marks
			var spin := pow(k, 2.0) * 14.0 * TAU
			for i in 12:
				var d2 := Vector2.RIGHT.rotated(TAU * i / 12.0)
				draw_line(d2 * (r - 10.0), d2 * (r + 6.0), Color(color, a), 2.0)
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(spin) * r, Color(Color.WHITE, a), 3.0)
		"lock":
			# four square brackets clamping in from the corners
			var bs := r * 1.2
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := Vector2(sx, sy) * bs * 0.7
					draw_line(corner, corner - Vector2(sx * 26.0, 0), Color(color, a), 4.0)
					draw_line(corner, corner - Vector2(0, sy * 26.0), Color(color, a), 4.0)
		"scan":
			# a radar sweep line with a fading wedge behind it
			var sw := k * TAU * 1.5
			for j in 8:
				var back := sw - j * 0.09
				draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(back) * r, Color(color, a * (1.0 - j / 8.0) * 0.8), 3.0 if j == 0 else 2.0)
		"ice":
			for i in 8:
				var ang := TAU * i / 8.0 - seed_t * 1.5
				var d := Vector2.RIGHT.rotated(ang)
				var tip := d * (r + 6.0)
				var side := d.orthogonal() * 7.0
				draw_colored_polygon(PackedVector2Array([tip, d * (r - 22.0) + side, d * (r - 22.0) - side]), Color(color, a * 0.8))
