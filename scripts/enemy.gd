extends Node2D
const FD = preload("res://scripts/fx/fd.gd")
## Malware. Kinds:
##  bug (fast zig-zag), worm (segmented), adware (splits into popups), popup,
##  trojan (tanky), spyware (keeps distance, shoots), botnet (telegraphed dash),
##  ransom (padlock brute), rootkit (cloaked, teleports),
##  sentry (static turret: warps to within range of the player, then stays put shooting fans),
##  miner (wanders aimlessly, never chases),
##  nanobot (paints a sight line, then fires a red laser beam), ram (rears back, then charges and knocks you back),
##  zipbomb (arms when close, then explodes).
## Elites are huge, crowned, named, and carry an affix.

const PixelArt = preload("res://scripts/pixel_art.gd")
const AFFIXES := ["SWIFT", "ARMORED", "VAMPIRIC", "SUMMONER", "VOLATILE"]
const NAMES := {"bug": "BUG", "worm": "WORM", "adware": "ADWARE", "popup": "POPUP", "trojan": "TROJAN",
	"spyware": "SPYWARE", "botnet": "BOTNET", "ransom": "RANSOMWARE", "rootkit": "ROOTKIT",
	"mite": "MITE", "miner": "MINER", "leech": "LEECH", "sentry": "SENTRY",
	"nanobot": "NANOBOT", "ram": "RAM", "zipbomb": "ZIP BOMB"}

var kind := "bug"
var speed := 60.0
var max_hp := 15.0
var hp := 15.0
var damage := 8.0
var radius := 12.0
var xp_value := 1
var color := Color(1.0, 0.25, 0.75)
var elite := false
var is_boss := false
var affix := ""
var display_name := ""
var damage_taken_mult := 1.0
var shield_time := 0.0   # invulnerable while above 0 (bosses get a window after enraging)
var minutes := 0.0

## Status effects (applied by the player's burn / poison / freeze / shock chances on every hit; see player.status_chance).
const STATUS_TIME := {"burn": 3.0, "poison": 5.0, "freeze": 2.0, "shock": 3.0}
const STATUS_COLOR := {"burn": Color(1.0, 0.5, 0.1), "poison": Color(0.5, 1.0, 0.3), "freeze": Color(0.5, 0.9, 1.0), "shock": Color(1.0, 0.95, 0.3)}
const BURN_RATE := 0.45     # burn: damage per second as a share of the hit that lit it
const POISON_RATE := 0.12   # poison: per stack, up to POISON_STACKS
const POISON_STACKS := 5
const FREEZE_SLOW := 0.55   # freeze: move speed multiplier (bosses are immune)
const SHOCK_VULN := 1.25    # shock: damage taken multiplier
const SHOCK_STUN := 0.8     # shock: seconds a threat is stunned (no moving, shooting or touching); bosses are immune
const STUN_GAP := 2.0       # seconds after a stun starts before the same threat can be stunned again
var status := {}            # kind -> seconds left

## Mites and leeches latch onto the player on contact: they ride along for LATCH_TIME, slowing the player and biting LATCH_TICKS times.
## A mite is spent once it lets go (it vanishes, no drops); a leech heals LEECH_DRAIN of its max HP per bite that lands,
## then hops off and cannot latch again for LATCH_CD.
const LATCH_TIME := 1.0
const LATCH_TICKS := 2
const LATCH_CD := 1.5
const LEECH_DRAIN := 0.25
const LEECH_REGEN := 0.03   # leeches also heal this share of max HP per second on their own
var latch_t := -1.0         # seconds since latching; below 0 = not latched
var latch_off := Vector2.ZERO
var latch_ticks := 0
var latch_cd := 0.0
## Close to the player a mite or leech stops dead and crouches for MITE_WINDUP (a readable pause), then lunges in a straight line for MITE_DASH_TIME to try to latch on.
## A dash that misses leaves it unable to dash again for MITE_DASH_CD (it keeps chasing and can still latch by touch).
const MITE_DASH_RANGE := 110.0
const MITE_WINDUP := 0.35
const MITE_DASH_TIME := 0.2
const MITE_DASH_SPEED := 470.0
const MITE_DASH_CD := 1.2
var mite_phase := ""        # "", "windup" or "dash"
var mite_t := 0.0
var mite_dir := Vector2.ZERO
var mite_dash_cd := 0.0
## Sentries never walk. They warp in to SENTRY_MIN..SENTRY_MAX from the player (with clear line of sight where possible),
## bolt down and fire three-shot fans. Each warp is telegraphed for SENTRY_WARP: the sentry flickers and hums where it stands
## while a shrinking crosshair marks where it will land. Once the player has been beyond SENTRY_LEASH or out of sight for
## SENTRY_REPOSITION seconds, it warps again.
const SENTRY_MIN := 240.0
const SENTRY_MAX := 340.0
const SENTRY_LEASH := 560.0
const SENTRY_WARP := 0.75
const SENTRY_REPOSITION := 1.0
const SENTRY_FIRE_CD := 3.0
var sentry_phase := ""      # "" (not placed yet), "warp" or "planted"
var warp_to := Vector2.ZERO
var warp_t := 0.0
var far_t := 0.0
## Miners never path toward the player: they pick a random heading every MINER_TURN seconds (or on hitting a wall).
## A miner that has drifted past MINER_DRIFT picks its next heading loosely toward the player's area, so they keep
## turning up on screen instead of wandering off forever.
const MINER_TURN := Vector2(1.5, 3.5)
const MINER_DRIFT := 650.0
var wander_dir := Vector2.ZERO
var wander_t := 0.0
## Nanobots hold at mid range. When ready they stand still and paint a sight line at the player for NANO_AIM seconds
## (it tracks for the first part, then locks for the last NANO_LOCK), then fire a red laser beam along the locked line.
## The beam lasts NANO_BEAM seconds, reaches NANO_BEAM_LEN (walls cut it short) and hurts once for NANO_BEAM_DMG x damage.
const NANO_AIM := 0.9
const NANO_LOCK := 0.3
const NANO_RANGE := 520.0
const NANO_CD := 3.2
const NANO_BEAM := 0.35
const NANO_BEAM_LEN := 760.0
const NANO_BEAM_W := 7.0
const NANO_BEAM_DMG := 1.8
var beam_len := 0.0
var beam_hit := false
## Rams rear back for RAM_REAR seconds behind a red lane (the direction locks when they start), then charge along it.
## A charge that connects deals RAM_DMG times its damage and throws the player back (player.knock).
const RAM_RANGE := 380.0
const RAM_REAR := 0.6
const RAM_CHARGE := 0.55
const RAM_SPEED := 600.0
const RAM_CD := 3.0
const RAM_DMG := 1.4
const RAM_KNOCK := 720.0
## Zip bombs chase; within ZIP_ARM_RANGE they stop and arm for ZIP_FUSE seconds, then explode for their damage
## (30 base) in ZIP_RADIUS. Killing one first defuses it; a self-detonation leaves no drops. They never deal contact damage.
const ZIP_ARM_RANGE := 90.0
const ZIP_FUSE := 1.1
const ZIP_RADIUS := 95.0
var atk_phase := ""         # nanobot "aim" / "beam"; ram "rear" / "charge"; zipbomb "armed"
var atk_t := 0.0
var atk_dir := Vector2.ZERO
var atk_cd := 0.0
var atk_hit := false        # a ram charge lands at most once
var hit_src := ""           # weapon id set by player.calc_damage for the hit about to land
var kill_src := ""          # weapon of the last direct hit (DoT ticks keep it); credited in the WEAPONS codex on death
var dot_rate := {"burn": 0.0, "poison": 0.0}
var poison_stacks := 0
var dot_sum := 0.0
var dot_tick := 0.5

var knockback := Vector2.ZERO
var slow_timer := 0.0
var stun_timer := 0.0
var stun_cd := 0.0
var flash := 0.0
var squash := 0.0
var t := 0.0
var history := []
var state := "chase"
var state_timer := 0.0
var los := true              # clear line to the player (walls); refreshed every ~0.3s
var los_timer := 0.0
var action_timer := 2.0
var tp_check := 0.5          # elites check every half second whether they have been left too far behind
var dash_dir := Vector2.ZERO
var player


func setup(enemy_kind: String, run_minutes: float, is_elite := false) -> void:
	kind = enemy_kind
	minutes = run_minutes
	match kind:
		"bug":
			_stats(105.0, 6.0, 5.0, 9.0, 1, Color(1.0, 0.25, 0.75))
		"worm":
			_stats(62.0, 16.0, 9.0, 11.0, 2, Color(0.35, 1.0, 0.45))
		"adware":
			_stats(52.0, 24.0, 8.0, 15.0, 3, Color(1.0, 0.88, 0.25))
		"popup":
			_stats(95.0, 6.0, 5.0, 8.0, 1, Color(1.0, 0.88, 0.25))
		"trojan":
			_stats(72.0, 45.0, 13.0, 15.0, 4, Color(1.0, 0.55, 0.15))
		"spyware":
			_stats(78.0, 22.0, 8.0, 12.0, 3, Color(0.92, 0.95, 1.0))
		"botnet":
			_stats(82.0, 30.0, 14.0, 12.0, 4, Color(0.35, 0.55, 1.0))
		"ransom":
			_stats(40.0, 130.0, 22.0, 22.0, 10, Color(1.0, 0.22, 0.3))
		"rootkit":
			_stats(80.0, 70.0, 16.0, 14.0, 8, Color(0.7, 0.3, 1.0))
		"mite":
			_stats(125.0, 3.5, 4.0, 6.0, 1, Color(0.6, 1.0, 0.2))
		"miner":
			_stats(50.0, 60.0, 11.0, 16.0, 6, Color(0.95, 0.75, 0.2))
		"leech":
			_stats(88.0, 26.0, 10.0, 12.0, 3, Color(0.85, 0.15, 0.35))
		"sentry":
			_stats(66.0, 34.0, 9.0, 13.0, 4, Color(0.3, 0.9, 0.85))
		"nanobot":
			_stats(74.0, 20.0, 9.0, 11.0, 3, Color(0.55, 0.8, 1.0))
		"ram":
			_stats(70.0, 42.0, 12.0, 15.0, 4, Color(0.85, 0.6, 0.35))
		"zipbomb":
			_stats(96.0, 14.0, 30.0, 12.0, 2, Color(1.0, 0.72, 0.15))
	var m := run_minutes
	max_hp *= (1.0 + 0.5 * m) * pow(1.18, m) * Meta.enemy_hp_mult()
	damage *= (1.0 + 0.2 * m) * pow(1.04, m) * Meta.enemy_dmg_mult()   # linear ramp plus mild compounding
	max_hp *= Global.overtime_hp_mult(m)
	damage *= Global.overtime_dmg_mult(m)
	speed *= 1.0 + m * 0.025
	display_name = NAMES.get(kind, kind.to_upper())
	elite = is_elite
	if elite:
		max_hp *= 9.0 * (1.0 + 0.2 * m)   # elites keep scaling on top of normal enemies
		radius *= 1.7
		damage *= 1.5
		xp_value *= 6
		apply_affix(AFFIXES.pick_random())
		display_name = "%s %s" % [affix, display_name]
	hp = max_hp
	t = randf() * 10.0
	action_timer = randf_range(1.0, 3.0)


## Elites always carry a modifier; regular enemies can too on later devices and higher threat levels (see game._spawn_enemy).
## Elites and bosses left about 1.5 minimaps behind jump back inside the minimap range (still off screen). Checked twice a second.
func _teleport_if_far(dist: float, arena) -> void:
	if not (elite or is_boss) or Global.game == null or Global.game.in_room:
		return
	tp_check -= get_process_delta_time()
	if tp_check > 0.0:
		return
	tp_check = 0.5
	var radar := 1300.0   # the minimap's range (ui/minimap.gd RANGE)
	if dist <= radar * 1.5:
		return
	var near_r: float = Global.game.offscreen_radius()
	var lo := minf(near_r + 60.0, radar * 0.9)
	var to: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(lo, radar * 0.9)
	if arena != null:
		to = arena.random_open_point(player.global_position, lo, radar * 0.9)
	Global.game.burst(global_position, color, 12, 200.0)
	global_position = to
	Global.game.burst(global_position, color, 12, 200.0)
	history.clear()


func apply_affix(a: String) -> void:
	affix = a
	match affix:
		"SWIFT":
			speed *= 1.6
		"ARMORED":
			damage_taken_mult = 0.5
		_:
			speed *= 0.95


func affix_color() -> Color:
	match affix:
		"ARMORED":
			return Color(0.6, 0.8, 1.0)
		"VAMPIRIC":
			return Color(1.0, 0.2, 0.3)
		"SUMMONER":
			return Color(1.0, 0.3, 0.8)
		"VOLATILE":
			return Color(1.0, 0.5, 0.1)
		"SWIFT":
			return Color(0.4, 1.0, 0.9)
	return Global.C_GOLD


func _stats(spd: float, h: float, dmg: float, r: float, xp: int, col: Color) -> void:
	speed = spd
	max_hp = h
	damage = dmg
	radius = r
	xp_value = xp
	color = col


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if Global.game and Global.game.time_stop > 0.0 and not is_boss:
		queue_redraw()   # PAUSE ability: time is stopped
		return
	t += delta
	flash = maxf(0.0, flash - delta)
	squash = maxf(0.0, squash - delta * 5.0)
	slow_timer = maxf(0.0, slow_timer - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	stun_cd = maxf(0.0, stun_cd - delta)
	latch_cd = maxf(0.0, latch_cd - delta)
	_tick_status(delta)
	if player == null or not player.alive:
		queue_redraw()
		return
	if stun_timer > 0.0:
		if latch_t >= 0.0:
			_unlatch()   # a stun shakes a latched mite or leech loose
			if not is_inside_tree() or is_queued_for_deletion():
				return
		mite_phase = ""   # and cancels a lunge
		atk_phase = ""    # ...or an aim, charge or fuse
		queue_redraw()   # stunned: it does nothing at all until the timer runs out
		return
	if latch_t >= 0.0:
		_tick_latch(delta)
		return
	# redraw level of detail: threats far off screen are not redrawn, and calm ones on screen redraw at half or quarter rate
	# (staggered per threat so the work is spread over frames). Anything mid-effect, hit, or special redraws every frame.
	var d2 := global_position.distance_squared_to(player.global_position)
	if is_boss or elite or sentry_phase == "warp" or flash > 0.0 or squash > 0.0 or atk_phase != "" or mite_phase != "" or state == "windup" or not status.is_empty() or slow_timer > 0.0 or (d2 < 1000000.0 and (kind == "sentry" or kind == "spyware")):
		queue_redraw()   # sentry / spyware turn toward the player, so they redraw every frame while near
	elif d2 < 1000000.0:
		var step := 2 if d2 < 490000.0 else 4   # within ~700 px: 30 Hz, beyond (still near the screen edge): 15 Hz
		if (Engine.get_process_frames() + get_instance_id()) % step == 0:
			queue_redraw()

	if player.ghost_time > 0.0:   # the Ghost is invisible: threats lose it, stand where they are and only drift from hits
		position += knockback * delta
		knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		mite_phase = ""
		atk_phase = ""
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)
	var spd := speed * (0.5 if slow_timer > 0.0 else 1.0) * (FREEZE_SLOW if status.has("freeze") else 1.0)
	var chase := dir
	var dp = Global.game.decoy_pos() if Global.game else null
	if dp != null:
		var to_decoy: Vector2 = dp - global_position
		if to_decoy.length() < 650.0:
			chase = to_decoy.normalized()   # the Decoy item draws nearby threats
	var arena = Global.game.arena if Global.game else null
	var walls_apply: bool = arena != null and kind != "rootkit"   # rootkits phase through walls
	_teleport_if_far(dist, arena)
	if walls_apply and dp == null:
		los_timer -= delta
		if los_timer <= 0.0:
			los_timer = randf_range(0.2, 0.4)
			los = arena.has_los_path(global_position, player.global_position)
		if not los:
			var fd: Vector2 = arena.flow_dir(global_position)
			if fd != Vector2.ZERO:
				chase = fd
	var move := chase * spd

	match kind:
		"bug":
			move = move.rotated(sin(t * 9.0) * 0.6)
		"spyware":
			if dist < 250.0:
				move = -dir * spd
			elif dist < 340.0:
				move = dir.orthogonal() * spd * 0.7
			action_timer -= delta
			if action_timer <= 0.0 and dist < 600.0:
				action_timer = 2.4
				Global.game.enemy_shot(global_position, dir * 230.0, damage * 0.8, color)
				Sfx.play_at("en_spy_shot", global_position, randf_range(0.95, 1.08))
		"sentry":
			move = Vector2.ZERO
			_sentry(delta, dir, dist, arena)
		"miner":
			move = _miner(delta, dir, dist, spd)
		"botnet":
			move = _botnet(delta, dir, dist, spd)
		"rootkit":
			action_timer -= delta
			if action_timer <= 0.0:
				action_timer = randf_range(3.5, 5.0)
				Global.game.burst(global_position, color, 12, 200.0)
				Sfx.play_at("en_rootkit_blink", global_position)
				global_position = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(170.0, 230.0)
				Global.game.burst(global_position, color, 12, 200.0)
				history.clear()
		"mite", "leech":
			move = _mite_dash(delta, dir, dist, spd, move, dp == null and los)
			if kind == "leech" and hp > 0.0:
				hp = minf(max_hp, hp + max_hp * LEECH_REGEN * delta)
		"nanobot":
			move = _nanobot(delta, dir, dist, spd, move)
		"ram":
			move = _ram(delta, dir, dist, spd, move, dp == null and los)
		"zipbomb":
			move = _zipbomb(delta, dist, move)
			if not is_inside_tree() or is_queued_for_deletion():
				return   # it went off

	if affix != "":
		match affix:
			"VAMPIRIC":
				hp = minf(max_hp, hp + max_hp * 0.015 * delta)
			"SUMMONER":
				state_timer -= delta
				if state_timer <= 0.0:
					state_timer = 4.5 if elite else 7.0
					Global.game.summon("bug", global_position, 3 if elite else 2, 40.0)

	var before := position
	position += (move + knockback) * delta
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	if walls_apply:
		if knockback.length() > 160.0:
			position = arena.clip_move(before, position, radius)   # a hard hit cannot throw a threat through a wall
			if position.distance_to(before + (move + knockback) * delta) > 1.0:
				knockback = Vector2.ZERO
		position = arena.push_out(position, radius)
		if kind == "miner" and position.distance_to(before + (move + knockback) * delta) > 0.5:
			wander_t = 0.0   # bumped into a wall: pick a new heading

	if kind == "worm" and (history.is_empty() or position.distance_to(history[0]) > 7.0):
		history.push_front(position)
		if history.size() > 12:
			history.pop_back()

	if dist < radius + player.radius:
		if kind == "mite" or kind == "leech":
			if latch_cd <= 0.0:
				_latch(to_player)
		elif kind == "ram" and atk_phase == "charge":
			if not atk_hit:
				atk_hit = true
				var before_hp: float = player.hp
				player.take_damage(damage * RAM_DMG, self)
				if player.hp < before_hp:
					player.knock(atk_dir * RAM_KNOCK)
				squash = 1.0
		elif kind != "zipbomb":
			player.take_damage(damage, self)

	if dist > 1500.0:
		if arena != null:
			global_position = arena.random_open_point(player.global_position, Global.game.offscreen_radius(), Global.game.offscreen_radius() + 100.0)
		else:
			global_position = player.global_position + dir * Global.game.offscreen_radius()
		history.clear()


## Sentry: bolted in place; fires while the player is in range and in sight, warps to a new spot once they are not.
func _sentry(delta: float, dir: Vector2, dist: float, arena) -> void:
	knockback = Vector2.ZERO   # hits do not shove it
	if sentry_phase == "warp":
		warp_t -= delta
		if warp_t <= 0.0:
			_sentry_land()
		return
	var in_reach := dist <= SENTRY_LEASH and los
	far_t = 0.0 if in_reach else far_t + delta
	if sentry_phase == "" or far_t >= SENTRY_REPOSITION:
		_sentry_warp(arena)
		return
	action_timer -= delta
	if action_timer <= 0.0 and in_reach:
		action_timer = SENTRY_FIRE_CD
		squash = 1.0
		for a in [-0.3, 0.0, 0.3]:   # three-shot fan
			Global.game.enemy_shot(global_position, dir.rotated(a) * 210.0, damage * 0.7, color)
		Sfx.play_at("en_sentry_fan", global_position)


func _sentry_warp(arena) -> void:
	var c: Vector2 = player.global_position
	warp_to = c + Vector2.from_angle(randf() * TAU) * randf_range(SENTRY_MIN, SENTRY_MAX)
	if arena != null:
		for i in 8:   # prefer a spot with a clear shot at the player
			warp_to = arena.random_open_point(c, SENTRY_MIN, SENTRY_MAX)
			if arena.has_los(warp_to, c):
				break
	sentry_phase = "warp"
	warp_t = SENTRY_WARP
	far_t = 0.0
	Sfx.play_at("en_sentry_warp", global_position)   # a rising whine that ends in a pop at the landing
	if Global.game:
		Global.game.ring(warp_to, color, radius * 3.0, SENTRY_WARP, 3.0)


func _sentry_land() -> void:
	if Global.game:
		Global.game.burst(global_position, color, 10, 180.0)
	global_position = warp_to
	sentry_phase = "planted"
	squash = 1.0
	action_timer = 0.8   # a beat after landing before the first fan
	los = true
	los_timer = 0.0
	history.clear()
	if Global.game:
		Global.game.burst(global_position, color, 14, 220.0)
		Global.game.ring(global_position, color, radius * 2.5, 0.3, 4.0)


## Miner: random headings, no pathing and no interest in the player beyond a loose drift back when it strays far.
func _miner(delta: float, dir: Vector2, dist: float, spd: float) -> Vector2:
	wander_t -= delta
	if wander_t <= 0.0 or wander_dir == Vector2.ZERO:
		wander_t = randf_range(MINER_TURN.x, MINER_TURN.y)
		if dist > MINER_DRIFT:
			wander_dir = dir.rotated(randf_range(-1.0, 1.0))
		else:
			wander_dir = Vector2.from_angle(randf() * TAU)
	return wander_dir * spd


## Mite lunge: windup (stands still, still aiming), then a fixed-direction dash; returns the move vector.
func _mite_dash(delta: float, dir: Vector2, dist: float, spd: float, move: Vector2, can_start: bool) -> Vector2:
	mite_dash_cd = maxf(0.0, mite_dash_cd - delta)
	match mite_phase:
		"windup":
			mite_t -= delta
			mite_dir = dir
			if mite_t <= 0.0:
				mite_phase = "dash"
				mite_t = MITE_DASH_TIME
				Sfx.play_at("en_mite_lunge", global_position, randf_range(0.9, 1.15))
			return Vector2.ZERO   # holds still: the pause telegraphs the lunge
		"dash":
			mite_t -= delta
			if mite_t <= 0.0:
				mite_phase = ""
				mite_dash_cd = MITE_DASH_CD
			return mite_dir * MITE_DASH_SPEED * (spd / speed) * (1.0 + minutes * 0.025)   # slows and freeze shorten the lunge too
	if can_start and dist < MITE_DASH_RANGE and latch_cd <= 0.0 and mite_dash_cd <= 0.0:
		mite_phase = "windup"
		mite_t = MITE_WINDUP
		mite_dir = dir
		return Vector2.ZERO
	return move


func _latch(to_player: Vector2) -> void:
	mite_phase = ""
	mite_dash_cd = MITE_DASH_CD
	latch_t = 0.0
	latch_ticks = 0
	latch_off = -to_player.normalized() * (player.radius + radius * 0.6)
	knockback = Vector2.ZERO
	history.clear()


func _tick_latch(delta: float) -> void:
	latch_t += delta
	global_position = player.global_position + latch_off
	player.latch_timer = maxf(player.latch_timer, 0.1)   # slowed while anything is latched on
	if latch_ticks < LATCH_TICKS and latch_t >= LATCH_TIME * (latch_ticks + 1) / LATCH_TICKS:
		latch_ticks += 1
		squash = 1.0
		var before_hp: float = player.hp
		player.take_damage(damage, self)
		if kind == "leech" and player.hp < before_hp and hp > 0.0:
			var gain := minf(max_hp * LEECH_DRAIN, max_hp - hp)
			hp += gain
			if gain > 0.5 and Global.game:
				Global.game.float_text(global_position + Vector2(0, -radius - 8.0), "+%d" % int(gain), Global.C_GREEN, 18, 0.5)
		if not is_inside_tree() or is_queued_for_deletion():
			return   # thorns can kill it mid-bite
	if latch_t >= LATCH_TIME:
		_unlatch()
	queue_redraw()


func _unlatch() -> void:
	latch_t = -1.0
	if kind == "mite":
		if Global.game:
			Global.game.on_enemy_vanished(self)   # a mite is spent after one latch
		queue_free()
		return
	latch_cd = LATCH_CD
	knockback = latch_off.normalized() * 320.0   # hops off the player


## Nanobot: holds at mid range like spyware; aims (standing still, sight line on the player), then fires a red laser beam.
func _nanobot(delta: float, dir: Vector2, dist: float, spd: float, move: Vector2) -> Vector2:
	atk_cd -= delta
	if atk_phase == "aim":
		atk_t -= delta
		if atk_t > NANO_LOCK:
			atk_dir = dir   # tracks the player until the line locks
		if atk_t <= 0.0:
			atk_phase = "beam"
			atk_t = NANO_BEAM
			squash = 1.0
			beam_hit = false
			beam_len = _beam_reach(atk_dir, NANO_BEAM_LEN)
			Sfx.play_at("en_nano_beam", global_position)
		return Vector2.ZERO
	if atk_phase == "beam":
		atk_t -= delta
		if not beam_hit and player and player.alive:
			var a := global_position + atk_dir * radius
			var b := global_position + atk_dir * beam_len
			var near := Geometry2D.get_closest_point_to_segment(player.global_position, a, b)
			if near.distance_to(player.global_position) < NANO_BEAM_W + player.radius:
				beam_hit = true
				player.take_damage(damage * NANO_BEAM_DMG)
		if atk_t <= 0.0:
			atk_phase = ""
			atk_cd = NANO_CD
		return Vector2.ZERO
	if atk_cd <= 0.0 and dist < NANO_RANGE and los:
		atk_phase = "aim"
		atk_t = NANO_AIM
		Sfx.play_at("en_nano_lock", global_position)
		atk_dir = dir
		return Vector2.ZERO
	if dist < 240.0:
		return -dir * spd
	if dist < 320.0:
		return dir.orthogonal() * spd * 0.6
	return move


## How far a beam from here along d travels before a wall stops it.
func _beam_reach(d: Vector2, max_len: float) -> float:
	var arena = Global.game.arena if Global.game else null
	if arena == null:
		return max_len
	var l := radius
	while l < max_len:
		if arena.point_blocked(global_position + d * l):
			return l
		l += 12.0
	return max_len


## Draws a nanobot's red laser from a to b on canvas c (shared with the codex cage). k fades 1 -> 0.
static func draw_laser_beam(c: CanvasItem, a: Vector2, b: Vector2, k: float, time: float) -> void:
	var w := NANO_BEAM_W * (0.6 + 0.4 * k) * (1.0 + 0.15 * sin(time * 60.0))
	c.draw_line(a, b, Color(1.0, 0.1, 0.12, 0.25 * k), w * 3.2)
	c.draw_line(a, b, Color(1.0, 0.18, 0.2, 0.85 * k), w * 1.6)
	c.draw_line(a, b, Color(1.0, 0.75, 0.75, k), w * 0.5)
	FD.circle(c, a, w * 1.4, Color(1.0, 0.3, 0.3, 0.8 * k))
	FD.circle(c, b, w * 1.8, Color(1.0, 0.2, 0.2, 0.5 * k))


## Ram: chases; in range it rears back (drifting slowly away, lane locked), then charges straight along the lane.
func _ram(delta: float, dir: Vector2, dist: float, spd: float, move: Vector2, can_start: bool) -> Vector2:
	atk_cd -= delta
	match atk_phase:
		"rear":
			atk_t -= delta
			if atk_t <= 0.0:
				atk_phase = "charge"
				atk_t = RAM_CHARGE
				atk_hit = false
				squash = 1.0
			return -atk_dir * 35.0
		"charge":
			atk_t -= delta
			if atk_t <= 0.0:
				atk_phase = ""
				atk_cd = RAM_CD
			return atk_dir * RAM_SPEED * (spd / speed)   # slows and freeze shorten the charge
	if can_start and atk_cd <= 0.0 and dist < RAM_RANGE:
		atk_phase = "rear"
		atk_t = RAM_REAR
		Sfx.play_at("en_ram_charge", global_position)
		atk_dir = dir
		return Vector2.ZERO
	return move


## Zip bomb: chases; once close it stops and arms, then explodes. A stun resets the fuse.
func _zipbomb(delta: float, dist: float, move: Vector2) -> Vector2:
	if atk_phase == "armed":
		atk_t -= delta
		if atk_t <= 0.0:
			_zip_explode()
		return Vector2.ZERO
	if dist < ZIP_ARM_RANGE + player.radius:
		atk_phase = "armed"
		atk_t = ZIP_FUSE
		Sfx.play_at("en_zip_arm", global_position)
		return Vector2.ZERO
	return move


func zip_radius() -> float:
	return ZIP_RADIUS * (1.5 if elite else 1.0)


func _zip_explode() -> void:
	var r := zip_radius()
	if Global.game:
		Global.game.burst(global_position, color, 24, 320.0, 5.0, 0.5)
		Global.game.ring(global_position, color, r, 0.35, 8.0)
		Global.game.shake(0.2)
	Sfx.play("hit", 0.5, 0.0)
	hp = 0.0   # before the blast: thorns cannot "kill" it a second time
	if player != null and player.alive and global_position.distance_to(player.global_position) < r + player.radius:
		player.take_damage(damage, self)
	if Global.game:
		Global.game.on_enemy_vanished(self)   # self-detonation: no kill, no drops
	queue_free()


func _botnet(delta: float, dir: Vector2, dist: float, spd: float) -> Vector2:
	action_timer -= delta
	match state:
		"windup":
			state_timer -= delta
			if state_timer <= 0.0:
				state = "dash"
				state_timer = 0.45
				Sfx.play_at("en_botnet_dash", global_position, randf_range(0.95, 1.1))
			return Vector2.ZERO
		"dash":
			state_timer -= delta
			if state_timer <= 0.0:
				state = "chase"
				action_timer = 2.5
			return dash_dir * 520.0
	if dist < 330.0 and action_timer <= 0.0:
		state = "windup"
		state_timer = 0.6
		dash_dir = dir
	return dir * spd


func take_damage(amount: float, kb := Vector2.ZERO, crit = 0) -> void:
	if hp <= 0.0:
		return
	kill_src = hit_src   # a hit without calc_damage (purge, hazards) clears it, so only weapon kills are counted
	hit_src = ""
	if shield_time > 0.0:
		Sfx.play("deny", randf_range(1.3, 1.6), -10.0, 0.04)   # the hit glances off
		return
	amount *= damage_taken_mult * (SHOCK_VULN if status.has("shock") else 1.0)
	amount = _cap_damage(amount)
	hp -= amount
	if Global.game:
		kb *= Global.game.player.knockback_mult
		Global.game.player.on_damage_dealt(amount)
		if hp > 0.0:
			_roll_status(amount)
	knockback += kb / (4.0 if elite else 1.0)
	flash = 0.08
	squash = 1.0
	Sfx.play("hit", randf_range(0.9, 1.2), -4.0, 0.04)
	if Global.game:
		Global.game.damage_number(global_position + Vector2(0, -radius), amount, crit)
	if hp <= 0.0:
		if Global.game:
			Global.game.on_enemy_killed(self)
		queue_free()


## Lets a subclass limit a hit before it lands (bosses stop at their enrage threshold; see boss.gd).
func _cap_damage(amount: float) -> float:
	return amount


## Every hit rolls each status chance. DoTs scale with the hit that applied them and with VIRULENCE.
func _roll_status(hit: float) -> void:
	var chances: Dictionary = Global.game.player.status_chance
	var cm: float = Global.game.player.status_chance_mult
	for k in STATUS_TIME:
		if chances[k] > 0.0 and randf() * 100.0 < chances[k] * cm:
			apply_status(k, hit)


func apply_status(k: String, hit: float) -> void:
	if k == "freeze" and is_boss:
		return
	var p = Global.game.player
	var power: float = p.status_mult()
	_status_combo(k, hit * power)
	if hp <= 0.0:
		return
	match k:
		"burn":
			dot_rate["burn"] = maxf(dot_rate["burn"], hit * BURN_RATE * power)
		"poison":
			poison_stacks = mini(poison_stacks + 1, POISON_STACKS)
			dot_rate["poison"] = maxf(dot_rate["poison"], hit * POISON_RATE * power)
	if not status.has(k) and k != "freeze":
		Sfx.play(k, 1.0, -6.0)   # burn / poison / shock, only when first applied
	status[k] = maxf(status.get(k, 0.0), STATUS_TIME[k] * p.status_time_mult())
	if k == "shock" and not is_boss and stun_cd <= 0.0:
		stun_timer = SHOCK_STUN
		stun_cd = STUN_GAP
		squash = 1.0


## Status combos: the new status reacts with one already on the threat, consuming that one.
##  SHATTER (shock on frozen): 80% of the hit as extra damage. MELTDOWN (burn on frozen): 60% extra and the freeze thaws.
##  TOXIC FLARE (burn on poisoned): 35% of the hit per poison stack as extra damage, clearing the poison.
func _status_combo(k: String, hit: float) -> void:
	var name := ""
	var extra := 0.0
	if k == "shock" and status.has("freeze"):
		name = "SHATTER"
		extra = hit * 0.8
		status.erase("freeze")
	elif k == "burn" and status.has("freeze"):
		name = "MELTDOWN"
		extra = hit * 0.6
		status.erase("freeze")
	elif k == "burn" and status.has("poison") and poison_stacks > 0:
		name = "TOXIC FLARE"
		extra = hit * 0.35 * poison_stacks
		status.erase("poison")
		dot_rate["poison"] = 0.0
		poison_stacks = 0
	if name == "":
		return
	Meta.codex_applied("combo:" + name.to_lower().replace(" ", ""))
	if Global.game:
		if Global.status_words and Global.game.challenge.get("rule", "") != "incognito":
			Global.game.float_text(global_position + Vector2(0, -radius - 18.0), name, STATUS_COLOR["shock"] if k == "shock" else STATUS_COLOR["burn"], 22, 0.6)
		Global.game.burst(global_position, STATUS_COLOR[k], 8, 200.0, 3.0, 0.3)
	if hit_src != "":
		kill_src = hit_src   # a combo can finish the threat before the hit that caused it lands
	_dot_hit(extra)


func _tick_status(delta: float) -> void:
	if status.is_empty():
		return
	for k in status.keys():
		status[k] -= delta
		if status[k] <= 0.0:
			status.erase(k)
			if k == "burn":
				dot_rate["burn"] = 0.0
			elif k == "poison":
				dot_rate["poison"] = 0.0
				poison_stacks = 0
	var dps := 0.0
	if status.has("burn"):
		dps += dot_rate["burn"]
	if status.has("poison"):
		dps += dot_rate["poison"] * poison_stacks
	dot_sum += dps * delta
	dot_tick -= delta
	if dot_tick <= 0.0:
		dot_tick = 0.5
		if dot_sum >= 1.0:
			_dot_hit(dot_sum)
			dot_sum = 0.0


## Damage over time: no knockback, no hit sound, no new status rolls.
func _dot_hit(amount: float) -> void:
	if hp <= 0.0 or shield_time > 0.0:
		return
	amount *= damage_taken_mult * (SHOCK_VULN if status.has("shock") else 1.0)
	amount = _cap_damage(amount)
	hp -= amount
	if Global.game:
		Global.game.player.on_damage_dealt(amount)
		Global.game.damage_number(global_position + Vector2(0, -radius), amount, 0)
	if hp <= 0.0:
		if Global.game:
			Global.game.on_enemy_killed(self)
		queue_free()


func _draw_status() -> void:
	var r := radius
	if status.has("burn"):
		for i in 3:
			var a := t * 5.0 + i * 2.1
			var f := Vector2(sin(a) * r * 0.6, -r - 4.0 - fmod(t * 14.0 + i * 5.0, 12.0))
			FD.circle(self, f, 3.5, Color(STATUS_COLOR["burn"], 0.85))
	if status.has("poison"):
		# a small, faint fog clinging to the threat (stacks only thicken it slightly)
		var fog_a := 0.07 + 0.015 * poison_stacks
		for i in 3:
			var a := t * 0.8 + i * 2.1
			FD.circle(self, Vector2.from_angle(a) * r * 0.45, r * 0.55, Color(STATUS_COLOR["poison"], fog_a))
	if status.has("freeze"):
		FD.ring(self, Vector2.ZERO, r + 6.0, 24, Color(STATUS_COLOR["freeze"], 0.9), 3.0)
	if stun_timer > 0.0:
		FD.ring(self, Vector2.ZERO, r + 8.0, 20, Color(STATUS_COLOR["shock"], 0.9), 3.0)
	if status.has("shock"):
		_draw_shock_bolts(r)


## Shock: jagged lightning keeps striking down onto the threat (two new bolts every 0.1s, like the LIVE WIRES hazard),
## with a flash where each lands and a spark arc crackling across its body.
func _draw_shock_bolts(r: float) -> void:
	var col: Color = STATUS_COLOR["shock"]
	var slot := int(t * 10.0)
	var fade := 1.0 - fmod(t * 10.0, 1.0) * 0.5
	for b in 2:
		var seed_v := float(slot * 2 + b) * 12.9898 + float(get_instance_id() % 997)
		var bolt: Array = _bolt(r, int(seed_v) & 255)
		draw_mesh(bolt[0], null, Transform2D.IDENTITY, Color(col, 0.5 * fade))
		draw_mesh(bolt[1], null, Transform2D.IDENTITY, Color(1.0, 1.0, 0.75, fade))
		FD.circle(self, bolt[2], (r * 0.4 + 5.0) * fade, Color(1.0, 1.0, 0.6, 0.6 * fade))
	# a spark arc crackling across the body
	var s0 := float(slot) * 3.17 + float(get_instance_id() % 991)
	draw_mesh(_spark(r, int(s0) & 255), null, Transform2D.IDENTITY, Color(col, 0.95 * fade))


## One lightning strike, built once per (radius, variant) and reused: [wide glow mesh, white core mesh, landing point].
## The strikes are random flicker, so 256 variants per radius look like a fresh random bolt every 0.1s but cost almost nothing to draw
## (building and triangulating a polyline per bolt per frame was the single most expensive thing a shocked threat did).
static var _bolt_cache := {}
static var _spark_cache := {}


static func _bolt(r: float, q: int) -> Array:
	var key := Vector2(r, q)
	var hit = _bolt_cache.get(key)
	if hit != null:
		return hit
	var seed_v := float(q) * 12.9898
	var sx := fmod(absf(sin(seed_v) * 43758.5453), 1.0)
	var ground := Vector2.from_angle(sx * TAU) * r * 0.55
	var top := ground + Vector2(sx * 40.0 - 20.0, -r - 52.0)
	var pts := PackedVector2Array([top])
	for k in range(1, 6):
		var jx := (fmod(absf(sin(seed_v + k * 7.7) * 9301.7), 1.0) - 0.5) * 26.0
		pts.append(top.lerp(ground, k / 6.0) + Vector2(jx, 0.0))
	pts.append(ground)
	hit = [FD.polyline_mesh(pts, 8.0), FD.polyline_mesh(pts, 3.0), ground]
	_bolt_cache[key] = hit
	return hit


static func _spark(r: float, q: int) -> ArrayMesh:
	var key := Vector2(r, q)
	var m: ArrayMesh = _spark_cache.get(key)
	if m != null:
		return m
	var s0 := float(q) * 3.17
	var a0 := fmod(absf(sin(s0) * 2834.1), 1.0) * TAU
	var arc := PackedVector2Array()
	for k in 5:
		var jr := r + 3.0 + (fmod(absf(sin(s0 + k * 5.1) * 7213.3), 1.0) - 0.5) * 8.0
		arc.append(Vector2.from_angle(a0 + k * 0.4) * jr)
	m = FD.polyline_mesh(arc, 2.0)
	_spark_cache[key] = m
	return m


func slow(seconds: float) -> void:
	slow_timer = maxf(slow_timer, seconds)


func _draw() -> void:
	var col := Color(1.6, 1.6, 1.6) if flash > 0.0 else color
	var spr: Texture2D = PixelArt.enemy_tex(kind)   # the pixel sprite for this kind; null falls back to the vector shapes below
	var sq := 1.0 + squash * 0.25
	var alpha := 1.0
	if kind == "rootkit":
		alpha = 0.3 + 0.7 * absf(sin(t * 2.2))
		col.a = alpha
	if spr == null:   # a pixel sprite stands alone, no glow circle behind it (elites and modifiers keep their aura / ring)
		Global.glow_circle(self, Vector2.ZERO, radius, color, (2.2 if elite else 1.0) * alpha)

	if elite:
		_draw_elite_aura()
	elif affix != "":   # a modified regular enemy: a ring and four studs in the modifier's colour
		var ac := affix_color()
		FD.ring(self, Vector2.ZERO, radius + 5.0, 24, Color(ac, 0.85), 2.5)
		for i in 4:
			FD.circle(self, Vector2.from_angle(t * 2.0 + TAU * i / 4.0) * (radius + 5.0), 2.5, ac)
	if slow_timer > 0.0:
		FD.ring(self, Vector2.ZERO, radius + 4.0, 20, Color(0.5, 0.9, 1.0, 0.7), 2.0)
	_draw_status()
	if kind == "sentry" and sentry_phase == "warp":   # crosshair closing in on the landing spot, and a flicker where it stands
		var k := clampf(1.0 - warp_t / SENTRY_WARP, 0.0, 1.0)
		var lp := warp_to - global_position
		var lr := radius * (2.6 - 1.4 * k)
		var lc := Color(color, 0.5 + 0.5 * absf(sin(t * 30.0)))
		draw_arc(lp, lr, 0.0, TAU, 28, lc, 2.5)
		for i in 4:
			var d := Vector2.from_angle(TAU * i / 4.0 + k * 1.5)
			draw_line(lp + d * (lr + 4.0), lp + d * (lr - 8.0), lc, 2.5)
		FD.circle(self, lp, radius * 0.5 * k, Color(color, 0.35))
		col.a = 0.35 + 0.65 * absf(sin(t * 25.0)) * (1.0 - k)
	if kind == "nanobot" and atk_phase == "aim":   # sight line: thin and flickering while tracking, solid once locked
		var locked := atk_t <= NANO_LOCK
		var ln := 900.0
		if player:
			ln = global_position.distance_to(player.global_position) + 140.0
		draw_line(atk_dir * radius, atk_dir * ln, Color(1.0, 0.25, 0.3, 0.9 if locked else 0.35 + 0.35 * absf(sin(t * 30.0))), 3.0 if locked else 1.5)
	if kind == "nanobot" and atk_phase == "beam":   # the red laser: wide glow, hot core, fading out
		draw_laser_beam(self, atk_dir * radius, atk_dir * beam_len, clampf(atk_t / NANO_BEAM, 0.0, 1.0), t)
	if kind == "ram" and (atk_phase == "rear" or state == "windup"):   # the lane it is about to charge down
		var rd := atk_dir if atk_phase == "rear" else dash_dir
		var lane := PackedVector2Array([rd.orthogonal() * radius, rd.orthogonal() * radius + rd * 330.0,
			-rd.orthogonal() * radius + rd * 330.0, -rd.orthogonal() * radius])
		draw_colored_polygon(lane, Color(1.0, 0.2, 0.2, 0.12 + 0.1 * absf(sin(t * 20.0))))
		draw_line(rd.orthogonal() * radius, rd.orthogonal() * radius + rd * 330.0, Color(1.0, 0.25, 0.25, 0.7), 2.0)
		draw_line(-rd.orthogonal() * radius, -rd.orthogonal() * radius + rd * 330.0, Color(1.0, 0.25, 0.25, 0.7), 2.0)
	if kind == "zipbomb" and atk_phase == "armed":   # blast radius filling up as the fuse burns
		var k := clampf(1.0 - atk_t / ZIP_FUSE, 0.0, 1.0)
		var zr := zip_radius()
		FD.circle(self, Vector2.ZERO, zr, Color(1.0, 0.2, 0.1, 0.06 + 0.1 * k))
		draw_arc(Vector2.ZERO, zr, 0.0, TAU, 40, Color(1.0, 0.3, 0.15, 0.6 + 0.4 * absf(sin(t * (10.0 + 30.0 * k)))), 2.5)
		FD.circle(self, Vector2.ZERO, zr * k, Color(1.0, 0.45, 0.1, 0.18))
	if kind == "botnet" and state == "windup":
		draw_line(Vector2.ZERO, dash_dir * 240.0, Color(1, 0.3, 0.3, 0.5 + 0.5 * sin(t * 40.0)), 3.0)
	if kind == "worm" and spr == null:
		for i in range(history.size() - 1, 0, -1):
			if i % 3 != 0:
				continue
			var p: Vector2 = history[i] - position
			var r := radius * (1.0 - i / 16.0)
			FD.circle(self, p, r, Color(color.darkened(0.3), 0.9))
			FD.ring(self, p, r, 16, col, 2.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sq, 2.0 - sq))
	if (kind == "mite" or kind == "leech") and mite_phase != "":
		var ma := mite_dir.angle()
		if mite_phase == "windup":   # crouches and trembles, a flickering tell toward the player
			draw_line(mite_dir * (radius + 4.0), mite_dir * (radius + 22.0), Color(1, 1, 1, 0.4 + 0.6 * absf(sin(t * 50.0))), 2.0)
			draw_set_transform(Vector2.from_angle(t * 90.0) * 1.5, ma, Vector2(0.75, 1.25))
		else:   # stretched along the lunge with a fading streak behind
			for k in range(1, 4):
				FD.circle(self, -mite_dir * k * 7.0, radius * (1.0 - k * 0.2), Color(color, 0.45 - k * 0.12))
			draw_set_transform(Vector2.ZERO, ma, Vector2(1.5, 0.7))
	var r := radius
	if spr != null:
		var tint := Color(2.0, 2.0, 2.0) if flash > 0.0 else Color.WHITE
		tint.a = col.a
		var dx: float = (player.global_position.x - global_position.x) if player != null else 0.0
		if PixelArt.has_aimed(kind):   # sentry gun / spyware iris turn toward the player
			var aim: Vector2 = (player.global_position - global_position) if player != null else Vector2.RIGHT
			PixelArt.draw_enemy_aimed(self, kind, maxf(radius * 2.6, 14.0), t, aim, sq, tint)
		else:
			PixelArt.draw_enemy(self, spr, kind, maxf(radius * 2.6, 14.0), t, dx, tint)
	match "" if spr != null else kind:
		"bug":
			var leg := sin(t * 20.0) * 3.0
			for side in [-1.0, 1.0]:
				for i in 3:
					var y := (i - 1) * r * 0.6
					draw_line(Vector2(side * r * 0.7, y), Vector2(side * (r + 6.0), y + leg * side), col, 2.0)
			draw_rect(Rect2(-r * 0.8, -r * 0.8, r * 1.6, r * 1.6), col)
			if randf() < 0.08:
				draw_rect(Rect2(-r + randf_range(-6, 6), randf_range(-r, r), r * 2.0, 3.0), Global.C_CYAN)
			draw_rect(Rect2(-r * 0.5, -r * 0.4, 4, 4), Color.BLACK)
			draw_rect(Rect2(r * 0.15, -r * 0.4, 4, 4), Color.BLACK)
		"worm":
			FD.circle(self, Vector2.ZERO, r, col)
			FD.circle(self, Vector2(-r * 0.35, -r * 0.25), r * 0.22, Color.BLACK)
			FD.circle(self, Vector2(r * 0.35, -r * 0.25), r * 0.22, Color.BLACK)
		"adware", "popup":
			var win := Rect2(-r * 1.1, -r * 0.85, r * 2.2, r * 1.7)
			draw_rect(win, Color(0.12, 0.1, 0.02))
			draw_rect(Rect2(win.position, Vector2(win.size.x, r * 0.5)), col)
			draw_rect(win, col, false, 2.0)
			draw_line(Vector2(r * 0.65, -r * 0.8), Vector2(r * 0.95, -r * 0.45), Color.BLACK, 2.0)
			draw_line(Vector2(r * 0.95, -r * 0.8), Vector2(r * 0.65, -r * 0.45), Color.BLACK, 2.0)
			if kind == "adware":
				var wfs := int(r * 0.8)   # sized to fit the window body, below the title bar
				var wsz := Global.FONT_BODY.get_string_size("WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs)
				if wsz.x > r * 1.8:
					wfs = int(wfs * r * 1.8 / wsz.x)
					wsz = Global.FONT_BODY.get_string_size("WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs)
				draw_string(Global.FONT_BODY, Vector2(-wsz.x / 2.0, r * 0.25 + wfs * 0.35), "WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, col)   # centred in the window body
			else:
				draw_rect(Rect2(-r * 0.6, -r * 0.1, r * 1.2, r * 0.3), Color(col, 0.6))
		"trojan":
			var rot := t * 1.5
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 4:
				outer.append(Vector2.from_angle(rot + TAU * i / 4.0) * r * 1.2)
				inner.append(Vector2.from_angle(rot + TAU * i / 4.0) * r * 0.6)
			FD.poly(self, outer, col)
			FD.poly(self, inner, Color(0.1, 0.03, 0.0))
			draw_rect(Rect2(-1.5, -6, 3, 7), col)
			draw_rect(Rect2(-1.5, 3, 3, 3), col)
		"spyware":
			var look: Vector2 = Vector2.ZERO
			if player:
				look = (player.global_position - global_position).normalized() * r * 0.35
			FD.poly(self, PackedVector2Array([Vector2(-r * 1.2, 0), Vector2(0, -r * 0.75), Vector2(r * 1.2, 0), Vector2(0, r * 0.75)]), col)
			FD.circle(self, look, r * 0.45, Color(1.0, 0.2, 0.3))
			FD.circle(self, look, r * 0.2, Color.BLACK)
		"botnet":
			var a: float = dash_dir.angle() if state != "chase" else (player.global_position - global_position).angle() if player else 0.0
			var tri := PackedVector2Array([Vector2.from_angle(a) * r * 1.3, Vector2.from_angle(a + 2.4) * r, Vector2.from_angle(a - 2.4) * r])
			FD.poly(self, tri, col)
			FD.circle(self, Vector2.ZERO, r * 0.3, Color.WHITE if state == "windup" else Color(0.05, 0.08, 0.2))
			for i in 3:
				FD.circle(self, Vector2.from_angle(t * 4.0 + TAU * i / 3.0) * r * 1.5, 2.0, Color(col, 0.8))
		"ransom":
			FD.arc(self, Vector2(0, -r * 0.35), r * 0.55, PI, TAU, 16, col, 5.0)
			draw_line(Vector2(-r * 0.55, -r * 0.35), Vector2(-r * 0.55, 0), col, 5.0)
			draw_line(Vector2(r * 0.55, -r * 0.35), Vector2(r * 0.55, 0), col, 5.0)
			draw_rect(Rect2(-r * 0.85, -r * 0.1, r * 1.7, r * 1.1), col)
			FD.circle(self, Vector2(0, r * 0.3), r * 0.15, Color(0.15, 0, 0))
			draw_rect(Rect2(-2, r * 0.3, 4, r * 0.35), Color(0.15, 0, 0))
		"mite":
			FD.circle(self, Vector2.ZERO, r, col)
			for i in 3:
				var a := TAU * i / 3.0 + t * 12.0
				draw_line(Vector2.from_angle(a) * r, Vector2.from_angle(a) * (r + 4.0), col, 1.5)
			FD.circle(self, Vector2(0, -r * 0.2), r * 0.3, Color.BLACK)
		"miner":
			var dia := PackedVector2Array([Vector2(0, -r * 1.15), Vector2(r * 1.0, 0), Vector2(0, r * 1.15), Vector2(-r * 1.0, 0)])
			FD.poly(self, dia, col)
			draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), Color(1, 1, 0.8), 2.0)
			draw_line(Vector2(-r * 0.5, 0), Vector2(r * 0.5, 0), Color(0.2, 0.12, 0.0), 3.0)
			draw_line(Vector2(0, -r * 0.5), Vector2(0, r * 0.5), Color(0.2, 0.12, 0.0), 3.0)
		"leech":
			FD.circle(self, Vector2.ZERO, r, col)
			FD.circle(self, Vector2.ZERO, r * 0.55, Color(0.25, 0.0, 0.08))
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			draw_arc(Vector2.ZERO, r * (0.8 + 0.3 * pulse), 0.0, TAU, 16, Color(col, 0.6), 2.0)
		"sentry":
			var look2: Vector2 = Vector2.ZERO
			if player:
				look2 = (player.global_position - global_position).normalized() * r * 0.35
			draw_rect(Rect2(-r, -r * 0.8, r * 2.0, r * 1.6), col)
			draw_rect(Rect2(-r * 0.75, -r * 0.55, r * 1.5, r * 1.1), Color(0.02, 0.1, 0.1))
			FD.circle(self, look2, r * 0.3, col)
			draw_line(Vector2.ZERO, look2.normalized() * r * 1.5, col, 3.0)
		"nanobot":   # a tiny chip with a lens, spinning legs
			var aim: Vector2 = atk_dir if atk_phase in ["aim", "beam"] else ((player.global_position - global_position).normalized() if player else Vector2.RIGHT)
			for i in 6:
				var a := TAU * i / 6.0 + t * 3.0
				draw_line(Vector2.from_angle(a) * r * 0.7, Vector2.from_angle(a) * (r + 5.0), col, 1.5)
			draw_rect(Rect2(-r * 0.75, -r * 0.75, r * 1.5, r * 1.5), col)
			draw_rect(Rect2(-r * 0.5, -r * 0.5, r, r), Color(0.03, 0.06, 0.12))
			FD.circle(self, aim * r * 0.2, r * 0.3, Color(1.0, 0.25, 0.3) if atk_phase in ["aim", "beam"] else col)
		"ram":   # a blocky head with two curled horns
			var fa: float = (atk_dir if atk_phase != "" else ((player.global_position - global_position).normalized() if player else Vector2.RIGHT)).angle()
			if state == "windup" or state == "dash":
				fa = dash_dir.angle()
			var f := Vector2.from_angle(fa)
			var sd := f.orthogonal()
			var body := PackedVector2Array([f * r * 1.15 + sd * r * 0.55, f * r * 1.15 - sd * r * 0.55, -f * r * 0.9 - sd * r * 0.85, -f * r * 0.9 + sd * r * 0.85])
			FD.poly(self, body, col)
			for side in [-1.0, 1.0]:
				var hb: Vector2 = f * r * 0.35 + sd * side * r * 0.75
				FD.arc(self, hb, r * 0.45, fa + side * 0.6, fa + side * 3.6, 10, col.lightened(0.35), 4.0)
			FD.circle(self, f * r * 0.5 + sd * r * 0.25, 2.5, Color.BLACK)
			FD.circle(self, f * r * 0.5 - sd * r * 0.25, 2.5, Color.BLACK)
		"zipbomb":   # a round bomb with a zipper stripe and a burning fuse
			var hot := atk_phase == "armed" and fmod(t * 12.0, 1.0) < 0.5
			FD.circle(self, Vector2.ZERO, r, Color(1.0, 0.35, 0.2) if hot else col)
			draw_line(Vector2(0, -r), Vector2(0, r), Color(0.15, 0.1, 0.0), 2.0)
			for i in 5:
				var y := -r * 0.7 + i * r * 0.35
				draw_line(Vector2(-3, y), Vector2(3, y), Color(0.15, 0.1, 0.0), 2.0)
			draw_line(Vector2(r * 0.5, -r * 0.85), Vector2(r * 0.85, -r * 1.35), Color(0.6, 0.6, 0.6), 2.0)
			FD.circle(self, Vector2(r * 0.85, -r * 1.35), 3.0 + 1.5 * absf(sin(t * 20.0)), Color(1.0, 0.85, 0.3))
		"rootkit":
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(Vector2.from_angle(TAU * i / 6.0 - t) * r)
			FD.poly(self, hex, Color(0.05, 0.0, 0.1, alpha))
			hex.append(hex[0])
			draw_polyline(hex, col, 2.5)
			FD.circle(self, Vector2.ZERO, r * 0.3, Color(col, alpha))
	draw_set_transform(Vector2.ZERO)

	if elite or kind == "ransom":
		var w := radius * 2.2
		var y := -radius - 16.0
		draw_rect(Rect2(-w / 2.0 - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(-w / 2.0, y, w * hp / max_hp, 5), Global.C_GOLD if elite else col)
	if elite:
		var font: Font = Global.FONT_BODY
		var fs := 20
		var tw := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(-tw / 2.0, -radius - 24.0)
		draw_string_outline(font, p, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
		draw_string(font, p, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Global.C_GOLD)


func _draw_elite_aura() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	var gold := Global.C_GOLD
	var aff_col := affix_color()
	FD.circle(self, Vector2.ZERO, radius + 26.0, Color(aff_col, 0.05 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, radius + 8.0 + pulse * 3.0, 0.0, TAU, 40, Color(gold, 0.6 + 0.4 * pulse), 3.0)
	# rotating spikes
	for i in 10:
		var a := t * 1.5 + TAU * i / 10.0
		var base := radius + 12.0
		draw_colored_polygon(PackedVector2Array([
			Vector2.from_angle(a - 0.12) * base, Vector2.from_angle(a) * (base + 10.0 + pulse * 3.0), Vector2.from_angle(a + 0.12) * base]), Color(aff_col, 0.85))
	if affix == "ARMORED":
		for i in 6:
			var a := -t + TAU * i / 6.0
			FD.arc(self, Vector2.ZERO, radius + 18.0, a, a + 0.6, 6, Color(aff_col, 0.8), 4.0)
