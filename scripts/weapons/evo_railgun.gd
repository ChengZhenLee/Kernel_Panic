extends Node2D
## RAILGUN (evolution of PACKET GUN + BACKDOOR + DRONE): a beam that pierces everything in a line.
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")

const RANGE := 900.0
const WIDTH := 26.0

var level := 1
var timer := 0.6
var beam_t := 0.0
var beam_dir := Vector2.RIGHT
var beam_len := RANGE
var beam_age := 99.0   # seconds since the last shot: drives the 8-frame beam sheet (0.67 s)
var beam_dirs := []    # one aim direction per shot of the last volley
var hits := []         # [world pos, age]: the spark sheet on every threat the beam pierced
var player
const BEAM_FRAMES := 8
const HIT_FRAMES := 6


func _ready() -> void:
	player = get_parent()
	z_index = 3


func _process(delta: float) -> void:
	queue_redraw()
	beam_t = maxf(0.0, beam_t - delta * 4.0)
	beam_age += delta
	for h in hits.duplicate():
		h[1] += delta
		if h[1] >= HIT_FRAMES / WFx.FPS:
			hits.erase(h)
	timer -= delta
	if timer > 0.0:
		return
	var target = null
	var best := 700.0 * 700.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_squared_to(player.global_position)
		if d < best and Global.game.can_hit(player.global_position, e):
			best = d
			target = e
	if target == null:
		return
	timer = maxf(0.5, 1.5 - 0.06 * level) * player.cooldown_mult
	beam_dir = (target.global_position - player.global_position).normalized()
	beam_t = 1.0
	beam_age = 0.0
	beam_dirs.clear()
	beam_len = RANGE * player.proj_size()
	var arena = Global.game.arena
	if arena != null:   # the beam stops at the first wall
		beam_len = minf(beam_len, arena.clip_move(player.global_position, player.global_position + beam_dir * beam_len, 0.0).distance_to(player.global_position))
	var shots: int = 1 + int(player.extra_proj / 2)
	for s in shots:
		var dir := beam_dir.rotated((s - (shots - 1) / 2.0) * 0.25)
		beam_dirs.append(dir)
		for e in get_tree().get_nodes_in_group("enemies"):
			var off: Vector2 = e.global_position - player.global_position
			var along := off.dot(dir)
			if along > 0.0 and along < beam_len and absf(off.cross(dir)) < WIDTH * player.proj_size() + e.radius:
				var d = player.calc_damage(42.0 + 12.0 * level, "evo_railgun", e)
				e.take_damage(d[0], dir * 220.0, d[1])
				if hits.size() < 30 and is_instance_valid(e):
					hits.append([e.global_position, 0.0])
	Global.game.shake(0.15)
	Sfx.play("explode", 1.6, -8.0)


func _draw() -> void:
	# pixel-art beam sheet (assets/fx/weapons/evo_railgun_beam.png): muzzle bloom cap | seamless 192 px body tile | impact flare cap, rotated to each aim
	var f := int(beam_age * WFx.FPS)
	if not WFx.has("evo_railgun_beam"):
		_draw_fallback()
		return
	if f < BEAM_FRAMES:
		var t := WFx.tex("evo_railgun_beam")
		var fs := WFx.frame_size("evo_railgun_beam")   # 384 x 96
		var x0 := f * fs.x
		var L := maxf(beam_len, 110.0)
		var col := Color(1, 1, 1, 0.85 - maxf(0.0, f - 5.0) * 0.3)   # the sheet has no dither (it is rotated): the fade is the draw colour's alpha
		for dir in beam_dirs:
			draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
			draw_texture_rect_region(t, Rect2(-48.0, -48.0, 96.0, 96.0), Rect2(x0, 0.0, 96.0, 96.0), col)   # muzzle
			var x := 48.0
			while x < L - 48.0:   # body tiles
				var w := minf(192.0, L - 48.0 - x)
				draw_texture_rect_region(t, Rect2(x, -48.0, w, 96.0), Rect2(x0 + 96.0, 0.0, w, 96.0), col)
				x += 192.0
			draw_texture_rect_region(t, Rect2(L - 48.0, -48.0, 96.0, 96.0), Rect2(x0 + 288.0, 0.0, 96.0, 96.0), col)   # impact
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for h in hits:
		WFx.draw(self, "evo_railgun_hit", int(h[1] * WFx.FPS), to_local(h[0]), Vector2(32, 32), 1.0, Color(1, 1, 1, 0.8))


func _draw_fallback() -> void:
	# a solid white core with a stepped orange sheath that thins with distance, hit sparks along the line (pixel-snapped)
	if beam_t <= 0.0:
		return
	var th := beam_t
	var u := beam_dir
	var side := u.orthogonal()
	var step := 3.0
	var n := int(beam_len / step)
	for i in n + 1:
		var d := i * step
		var h := roundi(7.0 * th * (1.0 - d / maxf(beam_len * 1.6, 1.0)) * 1.4) * 2   # sheath half-width in px, stepped
		var p := u * d
		Pix.dot(self, p, Color(1.0, 0.91, 0.63, th), 4.0)
		Pix.dot(self, p, Color(1, 1, 1, th), 2.0)
		if h > 0:
			Pix.dot(self, p + side * h, Color(1.0, 0.6, 0.16, 0.35 * th), 3.0)
			Pix.dot(self, p - side * h, Color(1.0, 0.6, 0.16, 0.35 * th), 3.0)
			if (i & 1) == 0:
				Pix.dot(self, p + side * (h + 3.0), Color(1.0, 0.82, 0.29, 0.25 * th), 2.0)
				Pix.dot(self, p - side * (h + 3.0), Color(1.0, 0.82, 0.29, 0.25 * th), 2.0)
	var f := int(Time.get_ticks_msec() / 120.0)
	for i in 8:
		var d := 20.0 + Pix.rnd(i + f) * (beam_len - 20.0)
		Pix.dot(self, u * d + side * (4.0 + Pix.rnd(i) * 4.0), Color(1.0, 0.88, 0.54, th), 2.0)
		Pix.dot(self, u * d - side * (4.0 + Pix.rnd(i + 2) * 4.0), Color(1.0, 0.69, 0.29, th), 2.0)
