extends Node2D
## SCORCHED EARTH (evolution of FIREWALL + LOGIC MINE + TOTEM): a big burning ring that ignites and erupts.
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")


var level := 1
var timer := 0.0
var erupt_timer := 3.0
var pulse := 0.0
var blast := 0.0
var spin := 0.0
var clock := 0.0
var pillars := []   # [world pos, delay, age]: the eruption geysers, set off in a wave from the middle outward
var player
const PILLAR_FRAMES := 10


func _ready() -> void:
	player = get_parent()
	z_index = 0   # was -1: under the floor game.gd draws at z 0


func get_radius() -> float:
	return (95.0 + level * 14.0) * player.area()


## Fire geysers on three rings out to the eruption radius, each delayed by its distance so the blast sweeps outward.
func _spawn_pillars() -> void:
	if not WFx.has("evo_inferno_pillar"):
		return
	var big := minf(get_radius() * 1.5, 380.0)   # the geysers cover at most this far; the damage still reaches the full eruption radius
	for ring_k in [0.35, 0.7, 1.0]:
		var rr: float = big * ring_k
		var n := clampi(int(TAU * rr / 90.0), 4, 20)
		var off := randf() * TAU
		for i in n:
			var a := off + TAU * i / n + randf_range(-0.08, 0.08)
			var wp: Vector2 = player.global_position + Vector2.from_angle(a) * rr * randf_range(0.92, 1.05)
			pillars.append([wp, ring_k * 0.28 + randf() * 0.05, 0.0])


func _process(delta: float) -> void:
	queue_redraw()
	clock += delta
	spin += delta * 1.0
	for p in pillars.duplicate():
		if p[1] > 0.0:
			p[1] -= delta
		else:
			p[2] += delta
			if p[2] >= PILLAR_FRAMES / WFx.FPS:
				pillars.erase(p)
	pulse = maxf(0.0, pulse - delta * 3.0)
	blast = maxf(0.0, blast - delta * 2.0)
	erupt_timer -= delta * (1.0 / player.cooldown_mult)
	if erupt_timer <= 0.0:
		erupt_timer = 3.5
		blast = 1.0
		_spawn_pillars()
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - player.global_position
			if off.length() < get_radius() * 1.5 + e.radius:
				var d = player.calc_damage(30.0 + 9.0 * level, "evo_inferno", e)
				e.take_damage(d[0], off.normalized() * 320.0, d[1])
		Global.game.shake(0.2)
		Sfx.play("explode", 0.9, -6.0)
	timer -= delta
	if timer > 0.0:
		return
	timer = 0.4 * player.cooldown_mult
	pulse = 1.0
	var r := get_radius()
	for e in get_tree().get_nodes_in_group("enemies"):
		var off: Vector2 = e.global_position - player.global_position
		if off.length() < r + e.radius:
			var d = player.calc_damage(6.0 + 2.6 * level, "evo_inferno", e)
			e.take_damage(d[0], off.normalized() * 120.0, d[1])
			if e.has_method("apply_status") and is_instance_valid(e):
				e.apply_status("burn", d[0])


func _draw() -> void:
	# pixel-art flames (assets/fx/weapons/evo_inferno_flame.png) standing round the ring over a dithered heat fill, embers rising; the eruption sets off
	# evo_inferno_pillar.png fire geysers in a wave plus the pixel shock rings
	if not WFx.has("evo_inferno_flame"):
		_draw_fallback()
		return
	var r := get_radius() * (1.0 + pulse * 0.04)
	Pix.dither_disc(self, Vector2.ZERO, r, Color(1.0, 0.29, 0.07, 0.12 + 0.08 * pulse))
	Pix.ring_auto(self, Vector2.ZERO, r, Color(0.35, 0.05, 0.02, 0.55), 3.0)   # scorched ground line under the flames
	var n := clampi(int(TAU * minf(r, 300.0) / 30.0), 14, 48)   # a big ring gets sparser flames, not more of them
	var step := 1
	var order := []
	for i in range(0, n, step):
		var a := TAU * i / n + spin * 0.15
		order.append([sin(a) * r, i, a])
	order.sort_custom(func(p, q): return p[0] < q[0])   # back of the ring first, front last
	for o in order:
		WFx.draw(self, "evo_inferno_flame", WFx.at(clock, o[1] * 3), Vector2.from_angle(o[2]) * r, Vector2(24, 76), 1.0, Color(1, 1, 1, 0.9), o[1] % 2 == 1)
	var now := Time.get_ticks_msec() / 1000.0
	for i in 8:
		var q := fmod(now * 0.8 + Pix.rnd(i), 1.0)
		var an := Pix.rnd(i + 2) * TAU
		var rr := Pix.rnd(i + 5) * (r - 4.0)
		Pix.dot(self, Vector2.from_angle(an) * rr + Vector2(0.0, -q * 12.0), Color(1.0, 0.82, 0.29, 1.0 - q), 2.0)
	var live := []
	for p in pillars:
		if p[1] <= 0.0:
			live.append(p)
	live.sort_custom(func(p, q): return p[0].y < q[0].y)
	for p in live:
		WFx.draw(self, "evo_inferno_pillar", int(p[2] * WFx.FPS), to_local(p[0]), Vector2(32, 138), 1.0, Color(1, 1, 1, 0.85))
	if blast > 0.0:
		var br := get_radius() * 1.5 * (1.0 - blast * 0.3)
		Pix.ring(self, Vector2.ZERO, br, Color(1.0, 0.82, 0.29, blast), 4.0, 600)
		Pix.ring(self, Vector2.ZERO, br - 5.0, Color(1.0, 0.48, 0.16, blast * 0.7), 2.0, 600)


func _draw_fallback() -> void:
	# a burning ground ring: dithered heat, layered flame tongues that flicker, embers; the eruption is a wide pixel ring (pixel-snapped)
	var r := get_radius() * (1.0 + pulse * 0.04)
	var now := Time.get_ticks_msec() / 1000.0
	Pix.dither_disc(self, Vector2.ZERO, r, Color(1.0, 0.29, 0.07, 0.12 + 0.08 * pulse))
	var tongues := clampi(int(r * 0.3), 24, 64)
	for i in tongues:
		var a := TAU * i / tongues + spin * 0.15
		var u := Vector2.from_angle(a)
		var f := int(now * 9.0 + i * 1.7) % 4
		var h := 4 + (i * 5 + f * 3) % 6
		for k in h:
			var col := Color(1.0, 0.29, 0.07) if k < 2 else (Color(1.0, 0.6, 0.1) if k < h * 0.6 else Color(1.0, 0.89, 0.48, 0.7))
			Pix.dot(self, u * (r - 3.0 + k * 2.0), col, 2.0)
	for i in 12:
		var q := fmod(now * 0.8 + Pix.rnd(i), 1.0)
		var an := Pix.rnd(i + 2) * TAU
		var rr := Pix.rnd(i + 5) * (r - 4.0)
		Pix.dot(self, Vector2.from_angle(an) * rr + Vector2(0.0, -q * 12.0), Color(1.0, 0.82, 0.29, 1.0 - q), 2.0)
	if blast > 0.0:
		var br := get_radius() * 1.5 * (1.0 - blast * 0.3)
		Pix.ring(self, Vector2.ZERO, br, Color(1.0, 0.82, 0.29, blast), 4.0, 600)
		Pix.ring(self, Vector2.ZERO, br - 5.0, Color(1.0, 0.48, 0.16, blast * 0.7), 2.0, 600)
