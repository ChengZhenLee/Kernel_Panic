extends Node2D
## QUARANTINE: drops freezing hex zones on enemy clusters that slow and damage.
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")
const SpriteFx = preload("res://scripts/fx/sprite_fx.gd")


var level := 1
var timer := 1.0
var player
var zones := []  # [pos, life, tick]
var clock := 0.0
const MAX_ZONES := 12  # on-screen cap so late-game zones don't carpet the screen; the oldest gives way


func _ready() -> void:
	player = get_parent()
	z_index = 0   # was -1: under the floor game.gd draws at z 0
	top_level = true


func zone_radius() -> float:
	return (75.0 + level * 8.0) * player.area()


func _process(delta: float) -> void:
	queue_redraw()
	clock += delta
	timer -= delta
	if timer <= 0.0:
		var targets := []
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(player.global_position) < 420.0:
				targets.append(e)
		if not targets.is_empty():
			timer = maxf(1.2, 3.2 - 0.2 * level) * player.cooldown_mult
			var count: int = 1 + int(level / 4.0)
			for i in count:
				if zones.size() >= MAX_ZONES:
					zones.pop_front()
				var zp: Vector2 = targets.pick_random().global_position
				zones.append([zp, 3.5 * player.duration_mult, 0.0])
				SpriteFx.play("quarantine_drop", zp, 1.0 if zone_radius() < 100.0 else 2.0)
			Sfx.play("weapon_quarantine", randf_range(0.95, 1.05))
	var r := zone_radius()
	for z in zones.duplicate():
		z[1] -= delta
		z[2] -= delta
		if z[2] <= 0.0:
			z[2] = 0.5
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(z[0]) < r + e.radius:
					e.slow(0.7)
					var d = player.calc_damage(4.0 + 2.5 * level, "quarantine", e)
					e.take_damage(d[0], Vector2.ZERO, d[1])
		if z[1] <= 0.0:
			zones.erase(z)


func _draw() -> void:
	# an octagonal containment pad: dithered fill, hard pixel border, a turning sigil and rising particles (pixel-snapped)
	var r := zone_radius()
	var ice := Color(0.56, 0.85, 1.0)
	var white := Color(0.91, 0.98, 1.0)
	var now := Time.get_ticks_msec() / 1000.0
	for z in zones:
		var p: Vector2 = z[0]
		var fade: float = clampf(z[1], 0.0, 1.0)
		var sp: float = z[1] * 0.5
		Pix.dither_octagon(self, p, r, Color(ice, 0.16 * fade))
		for i in 8:   # border: 8 alternating sides with a white stud at each corner
			var a0 := TAU * i / 8.0 + PI / 8.0
			var a1 := TAU * (i + 1) / 8.0 + PI / 8.0
			Pix.line(self, p + Vector2.from_angle(a0) * r, p + Vector2.from_angle(a1) * r, Color(ice if i % 2 == 1 else white, fade), 2.0)
			Pix.dot(self, p + Vector2.from_angle(a0) * r, Color(1, 1, 1, fade), 3.0)
		if WFx.has("quarantine_emblem"):   # a turning trefoil emblem on the pad and a containment pylon on four corners
			var es := 3.0 if r >= 150.0 else 2.0
			WFx.draw(self, "quarantine_emblem", WFx.at(clock, 0, 6.0), p, Vector2(40, 40), es, Color(1, 1, 1, 0.8 * fade))
			var pyl := []
			for k in 4:
				var pa := PI / 8.0 + k * PI / 2.0
				pyl.append([sin(pa), p + Vector2.from_angle(pa) * r])
			pyl.sort_custom(func(u, v): return u[0] < v[0])
			for pp in pyl:
				WFx.draw(self, "quarantine_pylon", WFx.at(clock, int(pp[0] * 7.0), 6.0), pp[1], Vector2(14, 52), 1.0, Color(1, 1, 1, fade))
		else:
			var ticks := 24
			for i in range(0, ticks, 3):   # inner ring ticks
				var u := Vector2.from_angle(TAU * i / ticks + sp)
				Pix.line(self, p + u * (r - r * 0.18), p + u * (r - r * 0.27), Color(ice, 0.8 * fade))
			for k in 3:   # sigil: three short arcs
				var a := sp * 3.2 + k * TAU / 3.0
				Pix.arc(self, p, r * 0.36, a - 0.5, a + 0.5, Color(white, 0.9 * fade), 2.0, 40)
			Pix.dot(self, p, Color(1, 1, 1, fade), 3.0)
		for i in 14:   # particles rising
			var q := fmod(now * 0.4 + Pix.rnd(i), 1.0)
			var an := Pix.rnd(i + 9) * TAU
			var rr := Pix.rnd(i + 3) * (r - 6.0)
			Pix.dot(self, p + Vector2.from_angle(an) * rr + Vector2(0.0, -q * 14.0), Color(white, (1.0 - q) * 0.9 * fade))
