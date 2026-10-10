extends Node2D
## ABSOLUTE ZERO (evolution of QUARANTINE + ORBIT + COLD SNAP): a persistent frost area around you that pulses periodically. Every tick it damages and
## freezes everything inside. One persistent node draws it; a tick spawns no nodes (the old nova made a ring and a burst every pulse).
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")


const TICK := 0.6
const VIS_R_MAX := 340.0   # decorative sprites never spread wider than this (the faint edge ring still shows the true hit radius)
const PULSE_EVERY := 2.2   # seconds between pulses of the visible area
const SOUND_EVERY := 6   # the frost sound plays on every 6th tick, quietly

var level := 1
var timer := 0.0
var player
var t := 0.0
var ticks := 0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # keeps the scaled dither crisp


func nova_radius() -> float:
	return (230.0 + 14.0 * level) * player.area()


## Seconds the old nova took between pulses; the aura keeps the same damage per second by scaling each tick's hit with TICK / this.
func _period() -> float:
	return maxf(1.0, 2.6 - 0.12 * level) * player.cooldown_mult


func _process(delta: float) -> void:
	t += delta
	global_position = player.global_position
	queue_redraw()
	timer -= delta
	if timer > 0.0:
		return
	timer = TICK
	ticks += 1
	if ticks % SOUND_EVERY == 1:
		Sfx.play("frost_pulse" if Sfx.streams.has("frost_pulse") else "zap", 1.0 if Sfx.streams.has("frost_pulse") else 0.6, -16.0)
	var r := nova_radius()
	var scale := TICK / _period()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var reach: float = r + e.radius
		if e.global_position.distance_squared_to(global_position) > reach * reach:
			continue
		var d = player.calc_damage((16.0 + 6.0 * level) * scale, "evo_blizzard", e)
		e.take_damage(d[0], (e.global_position - global_position).normalized() * 40.0 * scale, d[1])
		if is_instance_valid(e) and e.has_method("apply_status"):
			e.apply_status("freeze", d[0] / scale)
		if is_instance_valid(e) and e.has_method("slow"):
			e.slow(1.5)


func _draw() -> void:
	# ABSOLUTE ZERO fx: a freezing nova GROWS from the player every PULSE_EVERY seconds up to the hit radius while it fades (dithered frost fill, bright rim), over a
	# slowly turning frost rune. Ice crystal sprites stand on the edge of the area that is actually hit and snow drifts down inside it (assets/fx/weapons/evo_blizzard_*.png).
	# The fill is a 1:1 tiled checker (no scaled texture), so a huge area stays crisp and never re-bakes.
	var R := nova_radius()
	var q := fmod(t, PULSE_EVERY) / PULSE_EVERY
	var e := 1.0 - pow(1.0 - q, 2.0)   # quick start, soft finish
	var r := maxf(6.0, R * (0.04 + 0.96 * e))
	var fade := 1.0 - q
	var sprites := WFx.has("evo_blizzard_crystal")
	var Rv := minf(R, VIS_R_MAX)   # the crystals, snow and rune stay within a screen-friendly radius however big weapon area makes the real one
	WFx.draw(self, "evo_blizzard_glyph", WFx.at(t, 0, 4.0), Vector2.ZERO, Vector2(112, 112), 1.0, Color(1, 1, 1, 0.35))
	Pix.ring_auto(self, Vector2.ZERO, R, Color(0.6, 0.88, 1.0, 0.16), 2.0)   # the hit edge, always faintly there
	Pix.dither_disc_tiled(self, Vector2.ZERO, r, Color(0.75, 0.92, 1.0, 0.2 * fade))
	Pix.ring_auto(self, Vector2.ZERO, r - 2.0, Color(0.5, 0.85, 1.0, 0.6 * fade), 2.0)
	Pix.ring_auto(self, Vector2.ZERO, r, Color(0.91, 0.98, 1.0, fade), 3.0)
	if not sprites:
		_draw_fallback_extras(r, q, fade)
		return
	# crystals on the hit edge, back of the ring first so the front ones overlap them
	var n := clampi(int(TAU * Rv / 56.0), 12, 36)
	var step := 2 if Global.low_fx else 1
	var order := []
	for i in range(0, n, step):
		order.append([sin(TAU * i / n) * Rv, i])
	order.sort_custom(func(p, o): return p[0] < o[0])
	for o in order:
		var a: float = TAU * o[1] / n
		WFx.draw(self, "evo_blizzard_crystal", WFx.at(t, o[1], 6.0), Vector2.from_angle(a) * Rv, Vector2(32, 84), 1.0, Color(1, 1, 1, 0.85), o[1] % 2 == 1)
	# snow drifting down through the whole area; every 4th flake is a big (2x) one
	var flakes := 10 if Global.low_fx else 18
	for i in flakes:
		var x := (Pix.rnd(i * 3.7) * 2.0 - 1.0) * Rv * 0.97
		var h := sqrt(maxf(0.0, Rv * Rv - x * x))
		var span := h * 2.0
		var y := -h + fposmod(t * (22.0 + 16.0 * Pix.rnd(i + 1.3)) + Pix.rnd(i + 8.1) * span, maxf(span, 1.0))
		x += sin(t * 1.3 + i * 2.1) * 9.0
		WFx.draw(self, "evo_blizzard_flake", WFx.at(t, i, 8.0), Vector2(x, y), Vector2(12, 12), 1.0, Color(1, 1, 1, 0.8))


func _draw_fallback_extras(r: float, q: float, fade: float) -> void:
	var shards := 28 if not Global.low_fx else 14
	for i in shards:   # ice shards standing off the rim, tipped white
		var u := Vector2.from_angle(TAU * i / shards + 0.3 * q)
		var l := 6.0 + float(i % 3) * 6.0
		Pix.line(self, u * r, u * (r + l), Color(0.5, 0.85, 1.0 if i % 2 else 0.85, fade * 0.8), 2.0)
		Pix.dot(self, u * (r + l), Color(1, 1, 1, fade), 3.0)
	for i in (7 if Global.low_fx else 14):   # snowflake sparkles, on for two frames of every four
		if ((int(t * 6.0) + i) & 3) < 2:
			var sp := Vector2.from_angle(Pix.rnd(i) * TAU) * (Pix.rnd(i + 4) * r * 0.9)
			Pix.dot(self, sp, Color(1, 1, 1, 0.9 * fade), 3.0)
			for off in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
				Pix.dot(self, sp + off, Color(0.75, 0.92, 1.0, 0.7 * fade), 2.0)
