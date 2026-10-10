extends "res://scripts/enemy.gd"
## Bosses. Each has its own look and attack mix; all enrage below 50% HP.
## Bosses come from the catalogue in boss_data.gd. Slot 3 is the device's final boss: defeating it cures the device.

const BossData = preload("res://scripts/boss_data.gd")
var boss_id := ""
var kite := false
var boss_index := 0   # slot: 0-2 regular bosses, 3 the final boss
var attacks := []      # [name, interval, timer]
var enraged := false
const ENRAGE_SHIELD := 3.0   # seconds of invulnerability after a boss enrages
const ENRAGE_AT := 0.5       # enrages below this share of max HP
const ENRAGE_FLOOR := 0.49   # a hit that would carry an un-enraged boss past ENRAGE_AT stops here (no skipping the enrage)
var spiral_time := 0.0
var spiral_angle := 0.0
var spiral_tick := 0.0
var dash_windup := 0.0
var dash_time := 0.0
var intro := 1.2


var face_left := false   # the lopsided bosses (pop-up king, phisher) mirror to face the player
var overtime := false   # a boss summoned after the final boss (does not count towards the 4 bosses)


func setup_boss(def: Dictionary, slot: int, run_minutes: float) -> void:
	boss_index = slot
	boss_id = def["id"]
	is_boss = true
	minutes = run_minutes
	kind = "boss"
	display_name = def["name"]
	kite = def.get("kite", false)
	var hp_mult := Meta.enemy_hp_mult()
	var dmg_mult := Meta.enemy_dmg_mult() * (1.0 + 0.1 * run_minutes)
	if slot < 3:   # regular boss: health, damage and rewards scale by slot, not by which boss it is
		_stats(def["speed"], BossData.SLOT_HP[slot] * def["hp"], BossData.SLOT_DMG[slot] * def["dmg"], def["radius"], BossData.SLOT_XP[slot], def["color"])
	else:
		_stats(def["speed"], def["hp"], def["dmg"], def["radius"], def["xp"], def["color"])
	attacks = []
	for a in def["attacks"]:
		attacks.append(a.duplicate())
	max_hp *= hp_mult * (1.0 + 0.35 * run_minutes) * pow(1.12, run_minutes)
	max_hp *= Global.overtime_hp_mult(run_minutes)
	hp = max_hp
	damage *= dmg_mult * Global.overtime_dmg_mult(run_minutes)


func _ready() -> void:
	super._ready()
	add_to_group("bosses")


## No burst can skip the enrage: the hit that crosses 50% stops at 49% and the boss enrages on the spot.
func _cap_damage(amount: float) -> float:
	if enraged or hp - amount >= max_hp * ENRAGE_AT:
		return amount
	_enrage()
	return maxf(0.0, hp - max_hp * ENRAGE_FLOOR)


func _enrage() -> void:
	enraged = true
	shield_time = ENRAGE_SHIELD
	if Global.game:
		Global.game.hud.announce("%s IS ENRAGED" % display_name, Global.C_RED)
		Global.game.shake(0.5)
	if not Sfx.announce("boss_enraged"):
		Sfx.play("alarm", 0.8)
	for a in attacks:
		a[1] *= 0.65


func _process(delta: float) -> void:
	if Global.game and Global.game.time_stop > 0.0:
		queue_redraw()   # PAUSE ability: time is stopped
		return
	t += delta
	flash = maxf(0.0, flash - delta)
	squash = maxf(0.0, squash - delta * 5.0)
	_tick_status(delta)
	shield_time = maxf(0.0, shield_time - delta)
	queue_redraw()
	if player == null or not player.alive:
		return
	if intro > 0.0:
		intro -= delta
		return
	if player.ghost_time > 0.0:   # the Ghost is invisible: the boss loses it and holds position
		return

	if not enraged and hp < max_hp * ENRAGE_AT:
		_enrage()

	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)

	var arena = Global.game.arena if Global.game else null
	_teleport_if_far(dist, arena)
	var chase := dir
	if arena != null:
		los_timer -= delta
		if los_timer <= 0.0:
			los_timer = 0.25
			los = arena.has_los_path(global_position, player.global_position)
		if not los:
			var fd: Vector2 = arena.flow_dir(global_position)
			if fd != Vector2.ZERO:
				chase = fd
	var move := chase * speed
	if boss_id == "megaworm":
		move = move.rotated(sin(t * 2.5) * 0.7)
	if kite:   # keeps its distance and circles
		if dist < 320.0:
			move = -dir * speed
		elif dist < 430.0:
			move = dir.orthogonal() * speed * 0.7
	if dash_windup > 0.0:
		dash_windup -= delta
		move = Vector2.ZERO
		if dash_windup <= 0.0:
			dash_time = 0.7
			dash_dir = dir
			Sfx.play("en_boss_attack", 1.0)
	elif dash_time > 0.0:
		dash_time -= delta
		move = dash_dir * 560.0

	position += move * delta
	if arena != null:
		position = arena.push_out(position, radius)

	if history.is_empty() or position.distance_to(history[0]) > 14.0:
		history.push_front(position)
		if history.size() > 18:
			history.pop_back()

	if dist < radius + player.radius:
		player.take_damage(damage, self)
	if boss_id == "megaworm":  # the worm's body hurts too
		for i in range(4, history.size(), 4):
			if player.global_position.distance_to(history[i]) < radius * 0.8 + player.radius:
				player.take_damage(damage * 0.6)
				break

	if dist > 1300.0:
		global_position = arena.random_open_point(player.global_position, 550.0, 700.0) if arena != null else player.global_position + dir * 650.0
		history.clear()

	for a in attacks:
		a[2] -= delta
		if a[2] <= 0.0:
			a[2] = a[1]
			_attack(a[0], dir)

	if spiral_time > 0.0:
		spiral_time -= delta
		spiral_tick -= delta
		if spiral_tick <= 0.0:
			spiral_tick = 0.07
			spiral_angle += 0.42
			for k in 3:
				_shoot(Vector2.from_angle(spiral_angle + TAU * k / 3.0) * 210.0)


func _attack(name: String, dir: Vector2) -> void:
	var game = Global.game
	match name:
		"radial":
			var n := 24 if enraged else 16
			for i in n:
				_shoot(Vector2.from_angle(TAU * i / n + t) * 190.0)
			Sfx.play("en_boss_attack", 0.92)
		"aimed":
			var n := 5 if enraged else 3
			for i in n:
				_shoot(dir.rotated((i - (n - 1) / 2.0) * 0.16) * 290.0)
		"spiral":
			spiral_time = 3.0
		"dash":
			dash_windup = 0.8
		"fan":
			var fan_n := 11 if enraged else 7
			for i in fan_n:
				_shoot(dir.rotated((i - (fan_n - 1) / 2.0) * 0.14) * 300.0)
		"blink":
			game.burst(global_position, color, 14, 220.0)
			global_position = game.arena.random_open_point(player.global_position, 260.0, 340.0) if game.arena != null else player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(260.0, 340.0)
			history.clear()
			game.burst(global_position, color, 14, 220.0)
			Sfx.play("en_boss_attack", 1.08)
		"slam":
			var slams := 3 if enraged else 1
			for i in slams:
				var at: Vector2 = player.global_position
				if i > 0:
					at += Vector2.from_angle(randf() * TAU) * randf_range(80.0, 200.0)
				game.slam(at, 100.0, 1.0, damage * 0.9, color)
		"summon_popup":
			game.summon("popup", position, 8 if enraged else 6, 70.0)
			if enraged:
				game.summon("adware", position, 2, 80.0)
		"summon_spy":
			game.summon("spyware", position, 3, 120.0)
		"summon_bug":
			game.summon("bug", position, 8 if enraged else 6, 60.0)
			if enraged:
				game.summon("worm", position, 3, 60.0)
		"summon_trojan":
			game.summon("trojan", position, 3, 90.0)
		"summon_botnet":
			game.summon("botnet", position, 6, 90.0)
		"summon_kernel":
			game.summon("rootkit", position, 3, 120.0)
			game.spawn_elite_near(position + Vector2.from_angle(randf() * TAU) * 200.0)


func _shoot(vel: Vector2) -> void:
	Global.game.enemy_shot(global_position, vel, damage * 0.55, color.lightened(0.3), true)


func take_damage(amount: float, kb := Vector2.ZERO, crit = 0) -> void:
	super.take_damage(amount, kb * 0.0, crit)


func _draw() -> void:
	var col := Color(1.6, 1.6, 1.6) if flash > 0.0 else color
	var grow := 1.0 - clampf(intro, 0.0, 1.2) / 1.2 * 0.7
	var r := radius * grow
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	if player != null and absf(player.global_position.x - global_position.x) > 12.0:
		face_left = player.global_position.x < global_position.x
	var bspr: Texture2D = PixelArt.boss_tex(boss_id, enraged, t)   # the pixel sprite (glow baked in); null falls back to the vector drawing
	if bspr == null:
		FD.circle(self, Vector2.ZERO, r * 3.2, Color(color, 0.05 + 0.04 * pulse))
		Global.glow_circle(self, Vector2.ZERO, r, color, 2.5)
	if dash_windup > 0.0 and player:
		var d: Vector2 = (player.global_position - global_position).normalized()
		draw_line(Vector2.ZERO, d * 500.0, Color(1, 0.2, 0.2, 0.35 + 0.35 * sin(t * 40.0)), r * 0.6)
	if enraged and bspr == null:
		draw_arc(Vector2.ZERO, r + 20.0 + pulse * 6.0, 0.0, TAU, 48, Color(1, 0.2, 0.2, 0.6), 4.0)
	if shield_time > 0.0:   # invulnerable: a bright cyan shell that flickers out in the last half second
		var sa := 0.9 if shield_time > 0.5 else 0.9 * (0.5 + 0.5 * sin(t * 40.0))
		FD.circle(self, Vector2.ZERO, r + 12.0, Color(Global.C_CYAN, 0.12 * sa))
		draw_arc(Vector2.ZERO, r + 12.0, 0.0, TAU, 48, Color(Global.C_CYAN, sa), 5.0)
	_draw_status()

	var mirror := Vector2(-1.0 if face_left and bspr == null and (boss_id == "popupking" or boss_id == "phisher") else 1.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, mirror)

	if bspr != null:
		PixelArt.draw_boss(self, bspr, boss_id, radius, not face_left, grow, Color(2.0, 2.0, 2.0) if flash > 0.0 else Color.WHITE)
	match "" if bspr != null else boss_id:
		"megaworm":
			# a long ringed body that tapers to a tail and wriggles, ending in a head with a toothed mouth (the hurt zones still follow history)
			var face: Vector2 = (player.global_position - global_position).normalized() if player else Vector2.RIGHT
			var side := face.orthogonal()
			var n := history.size()
			for i in range(n - 1, 0, -1):
				var prev: Vector2 = (history[i - 1] if i > 0 else position) - position
				var here: Vector2 = history[i] - position
				var seg_dir := (prev - here).normalized() if prev != here else face
				var p: Vector2 = here + seg_dir.orthogonal() * sin(t * 6.0 - i * 0.9) * r * 0.14 * (1.0 - i / float(n) * 0.5)
				var sr := r * (0.3 + 0.7 * pow(1.0 - i / float(n + 2), 0.7))
				var band := color.darkened(0.35 if i % 2 == 0 else 0.5)
				if i == 6 or i == 7:
					band = color.lightened(0.15)   # the pale band of an earthworm
				if flash > 0.0:
					band = Color(1.6, 1.6, 1.6)
				FD.circle(self, p, sr, band)
				FD.circle(self, p - seg_dir.orthogonal() * sr * 0.3, sr * 0.55, Color(band.lightened(0.25), 0.55))   # the lit top of the ring
				draw_arc(p, sr, seg_dir.angle() + PI * 0.5, seg_dir.angle() + PI * 1.5, 14, band.darkened(0.45), 3.0)   # the groove at the front edge
			var head := PackedVector2Array()
			for k in 20:
				var an := TAU * k / 20.0
				head.append(face * cos(an) * r * 1.15 + side * sin(an) * r * 0.95)
			draw_colored_polygon(head, col)
			head.append(head[0])
			draw_polyline(head, color.darkened(0.5), 3.0)
			var mouth := face * r * 0.8
			FD.circle(self, mouth, r * 0.3, Color(0.25, 0.02, 0.05))
			for k in 5:   # teeth ringing the mouth
				var ta := TAU * k / 5.0 + t * 1.5
				FD.circle(self, mouth + Vector2.from_angle(ta) * r * 0.3, r * 0.06, Color(0.95, 0.95, 0.85))
			for s in [-1.0, 1.0]:
				var ep: Vector2 = face * r * 0.35 + side * s * r * 0.5
				FD.circle(self, ep, r * 0.14, Color(0.05, 0.05, 0.05))
				FD.circle(self, ep + face * r * 0.04, r * 0.06, Color(1.0, 0.3, 0.3))
		"locker":
			for i in 12:
				var a := t * 0.8 + TAU * i / 12.0
				var p := Vector2.from_angle(a) * (r + 28.0)
				draw_arc(p, 7.0, 0.0, TAU, 10, Color(Global.C_GOLD, 0.8), 3.0)
			draw_arc(Vector2(0, -r * 0.35), r * 0.55, PI, TAU, 20, col, 9.0)
			draw_line(Vector2(-r * 0.55, -r * 0.35), Vector2(-r * 0.55, 0), col, 9.0)
			draw_line(Vector2(r * 0.55, -r * 0.35), Vector2(r * 0.55, 0), col, 9.0)
			draw_rect(Rect2(-r * 0.85, -r * 0.1, r * 1.7, r * 1.1), col)
			draw_rect(Rect2(-r * 0.85, -r * 0.1, r * 1.7, r * 1.1), Global.C_GOLD, false, 3.0)
			FD.circle(self, Vector2(0, r * 0.3), r * 0.17, Color(1, 0.85, 0.3, 0.5 + 0.5 * pulse))
			draw_rect(Rect2(-4, r * 0.3, 8, r * 0.38), Color(1, 0.85, 0.3, 0.5 + 0.5 * pulse))
		"hive":
			var nodes := []
			for i in 6:
				nodes.append(Vector2.from_angle(t * 1.2 + TAU * i / 6.0) * (r + 30.0))
			for i in 6:
				draw_line(Vector2.ZERO, nodes[i], Color(col, 0.5), 2.0)
				draw_line(nodes[i], nodes[(i + 1) % 6], Color(col, 0.35), 2.0)
				FD.circle(self, nodes[i], 8.0, col)
				FD.circle(self, nodes[i], 3.0, Color.WHITE)
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(Vector2.from_angle(TAU * i / 6.0 + t * 0.3) * r)
			draw_colored_polygon(hex, Color(0.05, 0.1, 0.3))
			hex.append(hex[0])
			draw_polyline(hex, col, 4.0)
			FD.circle(self, Vector2.ZERO, r * 0.35 * (0.9 + 0.2 * pulse), col)
			FD.circle(self, Vector2.ZERO, r * 0.15, Color.WHITE)
		"kernel":
			var g := Vector2(randf_range(-4, 4), 0) if randf() < 0.2 else Vector2.ZERO
			for k in 3:
				draw_arc(Vector2.ZERO, r + 18.0 + k * 14.0, t * (1.0 + k * 0.5), t * (1.0 + k * 0.5) + PI * 1.3, 32, Color([Global.C_CYAN, Global.C_MAGENTA, Global.C_GOLD][k], 0.7), 3.0)
			var chip := Rect2(-r * 0.75, -r * 0.75, r * 1.5, r * 1.5)
			draw_rect(Rect2(chip.position + g + Vector2(4, 0), chip.size), Color(Global.C_CYAN, 0.35))
			draw_rect(Rect2(chip.position - g - Vector2(4, 0), chip.size), Color(Global.C_MAGENTA, 0.35))
			draw_rect(chip, Color(0.08, 0.02, 0.1))
			draw_rect(chip, col, false, 4.0)
			for i in 5:
				var o := (i - 2) * r * 0.3
				for s in [-1.0, 1.0]:
					draw_line(Vector2(o, s * r * 0.75), Vector2(o, s * r * 1.0), col, 4.0)
					draw_line(Vector2(s * r * 0.75, o), Vector2(s * r * 1.0, o), col, 4.0)
			var look: Vector2 = (player.global_position - global_position).normalized() * r * 0.15 if player else Vector2.ZERO
			FD.circle(self, Vector2.ZERO, r * 0.38, Color(1, 1, 1, 0.9))
			FD.circle(self, look, r * 0.22, col)
			FD.circle(self, look, r * 0.1, Color.BLACK)
		"popupking":
			for k in 3:
				var o := Vector2(-0.5 + k * 0.5, -0.4 + k * 0.4) * r * 0.7
				var win := Rect2(o - Vector2(r * 0.8, r * 0.6), Vector2(r * 1.6, r * 1.2))
				draw_rect(win, Color(0.12, 0.1, 0.02))
				draw_rect(Rect2(win.position, Vector2(win.size.x, r * 0.3)), col)
				draw_rect(win, col, false, 3.0)
				draw_line(win.position + Vector2(win.size.x - r * 0.45, r * 0.06), win.position + Vector2(win.size.x - r * 0.15, r * 0.24), Color.BLACK, 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # the text stays readable
			var wfs := int(r * 0.6)   # fitted inside the front window's body (below its title bar)
			var wsz := Global.FONT_BODY.get_string_size("WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs)
			if wsz.x > r * 1.3:
				wfs = int(wfs * r * 1.3 / wsz.x)
				wsz = Global.FONT_BODY.get_string_size("WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs)
			var wpos := Vector2(r * 0.35 * mirror.x - wsz.x / 2.0, r * 0.43 + wfs * 0.35)
			draw_string_outline(Global.FONT_BODY, wpos, "WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, 6, Color.BLACK)
			draw_string(Global.FONT_BODY, wpos, "WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Color(col, 0.9))   # centred in the front window
		"keylogger":
			var deck := Rect2(-r * 1.2, -r * 0.2, r * 2.4, r * 1.1)
			draw_rect(deck, Color(0.05, 0.05, 0.1))
			draw_rect(deck, col, false, 3.0)
			for row in 3:
				for kx in 7:
					draw_rect(Rect2(deck.position + Vector2(r * 0.15 + kx * r * 0.32, r * 0.12 + row * r * 0.3), Vector2(r * 0.24, r * 0.2)), Color(col, 0.55))
			var eye_look: Vector2 = (player.global_position - global_position).normalized() * r * 0.15 if player else Vector2.ZERO
			FD.circle(self, Vector2(0, -r * 0.65), r * 0.5, Color.WHITE)
			FD.circle(self, Vector2(0, -r * 0.65) + eye_look, r * 0.26, Color(1.0, 0.2, 0.3))
			FD.circle(self, Vector2(0, -r * 0.65) + eye_look, r * 0.11, Color.BLACK)
		"phisher":
			var env := Rect2(-r * 0.95, -r * 0.7, r * 1.9, r * 1.3)
			draw_rect(env, Color(0.04, 0.15, 0.14))
			draw_rect(env, col, false, 4.0)
			draw_polyline(PackedVector2Array([env.position, Vector2(0, -r * 0.05), Vector2(env.end.x, env.position.y)]), col, 4.0)
			draw_line(Vector2(0, env.end.y), Vector2(0, env.end.y + r * 0.35), Global.C_RED, 4.0)
			draw_arc(Vector2(r * 0.22, env.end.y + r * 0.35), r * 0.22, PI, TAU + 0.8, 12, Global.C_RED, 4.0)
		"baseband":
			for k in 4:
				var rr := r * 0.8 + k * r * 0.4 + fmod(t * 30.0, r * 0.4)
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(col, 0.55 - k * 0.12), 3.0)
			var mast := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.6, r * 0.85), Vector2(-r * 0.6, r * 0.85)])
			draw_colored_polygon(mast, Color(0.03, 0.1, 0.16))
			mast.append(mast[0])
			draw_polyline(mast, col, 4.0)
			draw_line(Vector2(-r * 0.3, r * 0.1), Vector2(r * 0.3, r * 0.1), col, 3.0)
			draw_line(Vector2(-r * 0.45, r * 0.5), Vector2(r * 0.45, r * 0.5), col, 3.0)
			FD.circle(self, Vector2(0, -r), r * 0.2 * (0.9 + 0.2 * pulse), Color.WHITE)
		"bluescreen":
			var scr := Rect2(-r * 1.2, -r * 0.85, r * 2.4, r * 1.7)
			var jit := Vector2(randf_range(-3, 3), 0) if randf() < 0.1 else Vector2.ZERO
			draw_rect(Rect2(scr.position + jit, scr.size), Color(0.05, 0.1, 0.45))
			draw_rect(scr, col, false, 5.0)
			draw_rect(Rect2(-r * 0.55, -r * 0.6, r * 0.26, r * 0.36), Color.WHITE)
			draw_rect(Rect2(r * 0.29, -r * 0.6, r * 0.26, r * 0.36), Color.WHITE)
			draw_arc(Vector2(0, r * 0.3), r * 0.38, PI * 1.12, PI * 1.88, 12, Color.WHITE, 5.0)
			for i in 3:
				draw_rect(Rect2(-r * 1.0, r * 0.4 + i * r * 0.16, r * (1.4 - i * 0.35), r * 0.06), Color(1, 1, 1, 0.75))
