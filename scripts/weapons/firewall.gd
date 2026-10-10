extends Node2D
## FIREWALL: a burning ring that damages every enemy inside it.
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")
const SpriteFx = preload("res://scripts/fx/sprite_fx.gd")


var level := 1
var timer := 0.0
var pulse := 0.0
var spin := 0.0
var clock := 0.0
var player


func _ready() -> void:
	player = get_parent()
	z_index = 0   # was -1: under the floor game.gd draws at z 0


func get_radius() -> float:
	return (58.0 + level * 12.0) * player.area()


func _process(delta: float) -> void:
	queue_redraw()
	spin += delta * 1.2
	clock += delta
	pulse = maxf(0.0, pulse - delta * 3.0)
	timer -= delta
	if timer > 0.0:
		return
	timer = 0.55 * player.cooldown_mult
	pulse = 1.0
	var r := get_radius()
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = e.global_position - player.global_position
		if offset.length() < r + e.radius:
			var d = player.calc_damage(3.0 + level * 2.2, "firewall", e)
			e.take_damage(d[0], offset.normalized() * 140.0, d[1])
			hit_any = true
	if hit_any:
		Sfx.play("weapon_firewall", randf_range(0.95, 1.05))


func _draw() -> void:
	# a turning ring of burning brick wall segments (assets/fx/weapons/firewall_brick.png) over a faint heat fill: the wall of a firewall, on fire
	if not WFx.has("firewall_brick"):
		_draw_fallback()
		return
	var r := get_radius() * (1.0 + pulse * 0.05)
	Pix.dither_disc(self, Vector2.ZERO, r, Color(1.0, 0.35, 0.1, 0.05 + 0.05 * pulse))
	Pix.ring_auto(self, Vector2.ZERO, r + 2.0, Color(0.3, 0.07, 0.03, 0.5), 2.0)   # scorched ground line under the wall
	# round (not truncate) to a whole number of bricks so the gap stays ~34 px at every radius; the old int()/40 cap let it drift wide on big rings
	var step := 2 if Global.low_fx else 1
	var n := clampi(roundi(TAU * r / (34.0 * step) ) * step, 8, 120)
	var order := []
	for i in range(0, n, step):
		var a := spin + TAU * i / n
		order.append([sin(a) * r, i, a])
	order.sort_custom(func(p, q): return p[0] < q[0])   # back of the ring first
	for o in order:
		WFx.draw(self, "firewall_brick", WFx.at(clock, o[1] * 3), Vector2.from_angle(o[2]) * r, Vector2(28, 68), 1.0, Color(1.0, 1.0 - pulse * 0.1, 1.0 - pulse * 0.3))


func _draw_fallback() -> void:
	# a ring of flame bricks: dark-red / orange / yellow cross-section, flickering tongues outward, embers rising (pixel-snapped)
	var r := get_radius() * (1.0 + pulse * 0.05)
	var now := Time.get_ticks_msec() / 1000.0
	Pix.dither_disc(self, Vector2.ZERO, r, Color(1.0, 0.35, 0.1, 0.05 + 0.05 * pulse))
	var segs := 12
	var arc_w := TAU / segs * 0.6
	var samples := clampi(ceili(r * arc_w / 2.0), 4, 14)
	var s := clampf(ceilf(r * arc_w / samples / 2.0) * 2.0, 2.0, 4.0)
	for i in segs:
		var a0 := spin + TAU * i / segs
		for k in samples + 1:
			var a := a0 + arc_w * k / samples
			var u := Vector2.from_angle(a)
			Pix.dot(self, u * (r - s), Color(0.66, 0.2, 0.06), s)
			Pix.dot(self, u * r, Color(1.0, 0.48, 0.1), s)
			Pix.dot(self, u * (r + s), Color(1.0, 0.82, 0.29, 0.7 + 0.3 * pulse), s)
			if (k + i) % 3 == 0:   # a flame tongue, a new length every frame of the flicker
				var fl := 3 + int(now * 10.0 + i + k) % 3
				for m in range(2, fl + 2):
					Pix.dot(self, u * (r + s + m * 2.0), Color(1.0, 0.69, 0.19) if m < 4 else Color(1.0, 0.35, 0.1), 2.0)
	# the faint inner ring turning the other way
	var n := clampi(int(r * 1.0), 16, 120)
	for i in range(0, n, 2):
		Pix.dot(self, Vector2.from_angle(-spin * 1.5 + TAU * i / n) * (r - 7.0), Color(1.0, 0.35, 0.1, 0.5))
	for i in 12:
		var q := fmod(now * 0.7 + Pix.rnd(i), 1.0)
		var an := Pix.rnd(i + 4) * TAU
		Pix.dot(self, Vector2.from_angle(an) * (r + q * 8.0) + Vector2(0.0, -q * 6.0), Color(1.0, 0.82, 0.29, 1.0 - q), 2.0)
