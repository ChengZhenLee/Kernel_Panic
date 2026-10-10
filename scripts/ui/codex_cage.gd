extends Node2D
## CODEX cage: a small barred pen where the game's own enemy or boss node walks around at random and now and then attacks.
## The creature is never part of a run: it is given a stand-in target that is "not alive", so its own AI stays idle and
## only animates, and this cage moves it and plays its attacks (real enemy bullets, bursts, rings and summoned minions).
## Nothing in here can hurt anything or play sounds.

const PixelArt = preload("res://scripts/pixel_art.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BulletScript = preload("res://scripts/enemy_bullet.gd")
const BurstScript = preload("res://scripts/fx/burst.gd")
const RingScript = preload("res://scripts/fx/ring.gd")

const W := 480.0                 # cage size in cage units (the codex scales the whole cage to fit its page)
const H := 340.0
const ENEMY_SIZE := 34.0          # drawn radius of a regular enemy in the cage
const BOSS_SIZE := 48.0           # drawn radius of a boss (bosses must read as clearly larger than elites)
const MAX_MINIONS := 10
const MAX_BULLETS := 90


## The creature looks at this point (its eyes, telegraph lines). It is never "alive", so no enemy code chases or hits it.
class Target extends Node2D:
	var alive := false
	var radius := 10.0


## A silent copy of the boss slam telegraph (fx/telegraph.gd plays a sound and looks for a player).
class Slam extends Node2D:
	var radius := 60.0
	var delay := 0.9
	var color := Color.RED
	var t := 0.0
	var cage

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= delay:
			cage.ring(position, color, radius, 0.35, 6.0)
			cage.burst(position, color, 14, 240.0)
			queue_free()

	func _draw() -> void:
		var k := clampf(t / delay, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.08 + 0.12 * k))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.8), 2.5)
		draw_circle(Vector2.ZERO, radius * k, Color(color, 0.25))


## The bars and frame, drawn above everything inside the cage.
class Bars extends Node2D:
	var col := Color.WHITE

	func _draw() -> void:
		var r := Rect2(-W / 2.0, -H / 2.0, W, H)
		var bar := Color(0.55, 0.62, 0.7, 0.35)
		var n := 12
		for i in range(1, n):
			var x := r.position.x + W * i / n
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), bar, 2.0)
		draw_rect(r, Color(col, 0.75), false, 4.0)
		draw_rect(r.grow(5.0), Color(col, 0.18), false, 4.0)
		for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), Color(0.12, 0.14, 0.18))
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), Color(col, 0.9), false, 2.0)


var world: Node2D            # floor contents: creature, minions, bullets, effects
var bars: Bars
var creature                 # the enemy or boss node
var target: Target
var is_boss := false
var cid := ""                # enemy kind, boss id, or modifier name for "affix" entries
var affix := ""
var col := Color.WHITE
var s := 1.0                 # creature scale
var spd := 80.0              # walking speed in cage units
var waypoint := Vector2.ZERO
var wander_time := 0.0
var attack_timer := 1.0
var mode := "walk"           # walk, windup, dash, hidden, aim (nanobot sight line), beam (nanobot laser)
var mode_time := 0.0
var dash_dir := Vector2.ZERO
var spiral_time := 0.0
var spiral_tick := 0.0
var spiral_angle := 0.0
var trail := []              # worm and megaworm body, in cage units
var minions := []            # [node, life, waypoint]
var bullets := []
var t := 0.0
var move_dir := Vector2.ZERO
var facing := Vector2.RIGHT   # where the creature looks: its walking direction, dash line or attack aim
var aim_dir := Vector2.ZERO    # attack aim, held for aim_hold seconds
var aim_hold := 0.0


func _init() -> void:
	var clipper := Control.new()   # keeps boss auras and shots inside the bars
	clipper.clip_contents = true
	clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipper.size = Vector2(W, H)
	clipper.position = Vector2(-W / 2.0, -H / 2.0)
	add_child(clipper)
	world = Node2D.new()
	world.position = Vector2(W / 2.0, H / 2.0)
	clipper.add_child(world)
	bars = Bars.new()
	add_child(bars)
	target = Target.new()
	world.add_child(target)


## kind: "enemy", "affix" or "boss". boost enlarges bosses whose drawing is small for their radius.
func setup(node, kind: String, boost := 1.0) -> void:
	creature = node
	is_boss = kind == "boss"
	col = node.color
	if kind == "affix":
		affix = node.affix
		cid = node.kind
	else:
		cid = node.boss_id if is_boss else node.kind
	if is_boss:
		node.intro = 0.0   # the codex boss is fully grown at once
		s = BOSS_SIZE / node.radius * boost
		var art_w: float = PixelArt.boss_art_width(node.boss_id, node.radius) * s   # in the cage a boss is never smaller than 1.2x a regular enemy sprite (ENEMY_SIZE * 2.6 wide)
		var min_w := ENEMY_SIZE * 2.6 * 1.2
		if art_w > 0.0 and art_w < min_w:
			s *= min_w / art_w
	else:
		s = ENEMY_SIZE / (node.radius + (8.0 if affix != "" else 0.0))
	node.scale = Vector2.ONE * s
	world.add_child(node)
	node.player = target   # the node's _ready runs later (when the cage enters the tree) and clears this; _process sets it again
	spd = clampf(node.speed * s * 0.5, 45.0, 210.0) * (1.6 if affix == "SWIFT" else 1.0)
	bars.col = col
	attack_timer = randf_range(0.8, 1.6)
	_new_waypoint()
	target.position = waypoint
	facing = Vector2.from_angle(randf() * TAU)


## Blacks out the creature and its attacks for entries not met yet, keeping the cage itself visible.
func set_unknown(on: bool) -> void:
	world.modulate = Color.BLACK if on else Color.WHITE


## Scales the cage to fill a page area of this size.
func fit(size: Vector2) -> void:
	scale = Vector2.ONE * minf(size.x / (W + 24.0), size.y / (H + 24.0))


func _draw() -> void:
	var r := Rect2(-W / 2.0, -H / 2.0, W, H)
	draw_rect(r, Color(0.02, 0.03, 0.05, 0.9))
	var grid := Color(col, 0.07)
	for i in range(1, 8):
		var y := r.position.y + H * i / 8.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid, 1.0)


func _radius() -> float:
	return creature.radius * s


func _inner() -> Rect2:
	var m := _radius() + 6.0
	return Rect2(-W / 2.0 + m, -H / 2.0 + m, W - 2.0 * m, H - 2.0 * m)


func _rand_point(rect: Rect2) -> Vector2:
	return Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))


## Distance from p along unit d to the cage bars.
func _reach_bars(p: Vector2, d: Vector2) -> float:
	var best := 2000.0
	if d.x != 0.0:
		best = minf(best, ((W / 2.0 if d.x > 0.0 else -W / 2.0) - p.x) / d.x)
	if d.y != 0.0:
		best = minf(best, ((H / 2.0 if d.y > 0.0 else -H / 2.0) - p.y) / d.y)
	return maxf(best, 0.0)


func _new_waypoint() -> void:
	waypoint = _rand_point(_inner())
	wander_time = randf_range(1.5, 3.5)


func _process(delta: float) -> void:
	if creature == null or not is_instance_valid(creature):
		return
	t += delta
	if creature.player != target:
		creature.player = target   # the creature's own _ready ran once the cage entered the tree and reset this to "no player"
	aim_hold = maxf(0.0, aim_hold - delta)
	_move(delta)
	_face(delta)
	_tick_attacks(delta)
	_tick_minions(delta)
	_tick_bullets()
	if cid in ["worm", "megaworm"]:
		_update_trail()


## Turns the creature smoothly toward where it goes or attacks; its eyes and telegraphs follow the stand-in target.
func _face(delta: float) -> void:
	var goal := facing
	if mode == "windup" or mode == "dash":
		goal = dash_dir
	elif aim_hold > 0.0 and aim_dir != Vector2.ZERO:
		goal = aim_dir
	elif move_dir != Vector2.ZERO:
		goal = move_dir
	if goal != Vector2.ZERO:
		facing = Vector2.from_angle(lerp_angle(facing.angle(), goal.angle(), minf(1.0, delta * 9.0)))
	target.position = creature.position + facing * (2000.0 if mode == "aim" else 120.0)   # a sight line runs out to the bars


func _move(delta: float) -> void:
	var pos: Vector2 = creature.position
	mode_time -= delta
	match mode:
		"aim":   # nanobot: stands still painting its sight line (tracking, then locked), then fires the red laser beam
			creature.atk_t = mode_time
			if mode_time > EnemyScript.NANO_LOCK:
				creature.atk_dir = facing
			if mode_time <= 0.0:
				mode = "beam"
				mode_time = EnemyScript.NANO_BEAM
				creature.atk_phase = "beam"
				creature.squash = 1.0
				var reach := _reach_bars(pos, creature.atk_dir)
				creature.beam_len = reach / s
				burst(pos + creature.atk_dir * reach, Color(1.0, 0.25, 0.25), 10, 180.0)
			move_dir = Vector2.ZERO
			return
		"beam":   # nanobot: the laser burns out to the bars, then fades
			creature.atk_t = mode_time
			if mode_time <= 0.0:
				mode = "walk"
				creature.atk_phase = ""
			move_dir = Vector2.ZERO
			return
		"hidden":
			if mode_time <= 0.0:   # VOLATILE: comes back after bursting
				mode = "walk"
				creature.position = _rand_point(_inner())
				creature.visible = true
				burst(creature.position, col, 10, 160.0)
			return
		"windup":
			creature.dash_dir = dash_dir
			if mode_time <= 0.0:
				mode = "dash"
				mode_time = 0.45
				creature.state = "dash"
				if is_boss:
					creature.dash_windup = 0.0
			elif is_boss:
				creature.dash_windup = mode_time
			return
		"dash":
			var np: Vector2 = pos + dash_dir * spd * 4.5 * delta
			var inner := _inner()
			if mode_time <= 0.0 or not inner.has_point(np):
				mode = "walk"
				creature.state = "chase"
				creature.squash = 1.0
				np = np.clamp(inner.position, inner.end)
				_new_waypoint()
			creature.position = np
			return
	if cid == "sentry":   # a turret: it never walks
		move_dir = Vector2.ZERO
		return
	# walking about
	wander_time -= delta
	var to := waypoint - pos
	if to.length() < 8.0 or wander_time <= 0.0:
		_new_waypoint()
		to = waypoint - pos
	var dir := to.normalized()
	var mv := dir
	if cid in ["bug", "megaworm"]:
		mv = dir.rotated(sin(t * (9.0 if cid == "bug" else 2.5)) * 0.6)
	elif cid == "popup" or cid == "mite":
		mv = dir.rotated(sin(t * 13.0) * 0.35)
	var inner := _inner()
	move_dir = dir
	creature.position = (pos + mv * spd * delta).clamp(inner.position, inner.end)


func _update_trail() -> void:
	var pos: Vector2 = creature.position
	var gap := 7.0 * s if cid == "worm" else 14.0 * s
	if trail.is_empty() or pos.distance_to(trail[0]) > gap:
		trail.push_front(pos)
		if trail.size() > (12 if cid == "worm" else 18):
			trail.pop_back()
	# the creature draws its body at history - position in its own (scaled) space
	var h := []
	for p in trail:
		h.append(pos + (p - pos) / s)
	creature.history = h


func _tick_attacks(delta: float) -> void:
	if spiral_time > 0.0:
		spiral_time -= delta
		spiral_tick -= delta
		if spiral_tick <= 0.0:
			spiral_tick = 0.09
			spiral_angle += 0.42
			for k in 3:
				shoot(Vector2.from_angle(spiral_angle + TAU * k / 3.0) * 130.0, true)
	if mode != "walk":
		return
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	attack_timer = randf_range(1.6, 3.0) if is_boss else randf_range(1.4, 3.2)
	var aim := _rand_point(Rect2(-W / 2.0 + 30.0, -H / 2.0 + 30.0, W - 60.0, H - 60.0))
	aim_dir = _aim_dir(aim)
	aim_hold = 0.6   # keep looking at the aim point for a moment
	if is_boss:
		var names := []
		for a in creature.attacks:
			names.append(a[0])
		_boss_attack(names.pick_random(), aim)
	else:
		_enemy_attack(aim)


func _aim_dir(aim: Vector2) -> Vector2:
	return (aim - creature.position).normalized()


func _enemy_attack(aim: Vector2) -> void:
	var pos: Vector2 = creature.position
	var dir := _aim_dir(aim)
	if affix != "" and randf() < 0.6:
		match affix:
			"SWIFT":
				_dash(dir, 0.25)
			"ARMORED":
				ring(pos, Color(0.6, 0.8, 1.0), _radius() + 26.0, 0.5, 5.0)
			"VAMPIRIC":
				creature.flash = 0.12
				ring(pos, Color(1.0, 0.2, 0.3), _radius() + 30.0, 0.5, 4.0)
				burst(pos, Color(1.0, 0.2, 0.3), 8, 90.0)
			"SUMMONER":
				for i in 2:
					minion("bug", pos)
				burst(pos, Global.C_MAGENTA, 10, 160.0)
			"VOLATILE":
				burst(pos, Color(1.0, 0.5, 0.1), 22, 300.0, 5.0)
				ring(pos, Color(1.0, 0.5, 0.1), 80.0, 0.4, 8.0)
				creature.visible = false
				mode = "hidden"
				mode_time = 0.9
		return
	match cid:
		"bug", "popup", "mite", "worm":
			_dash(dir, 0.0)
		"spyware":
			shoot(dir * 150.0)
		"sentry":
			if randf() < 0.4:
				_blink()   # repositions by warping, never by walking
			for a in [-0.3, 0.0, 0.3]:
				shoot(dir.rotated(a) * 140.0)
		"botnet":
			_dash(dir, 0.6)
		"adware":
			for i in 2:
				minion("popup", pos)
			burst(pos, col, 10, 160.0)
		"trojan":
			creature.squash = 1.0
			ring(pos, col, _radius() + 40.0, 0.45, 6.0)
		"ransom":
			slam(pos, _radius() + 46.0, 0.9)
		"rootkit":
			_blink()
		"miner":
			creature.squash = 1.0
			burst(pos, Color(1.0, 0.85, 0.3), 14, 180.0, 4.0, 0.7)
		"leech":
			creature.flash = 0.12
			ring(pos, Color(0.5, 1.0, 0.3), _radius() + 30.0, 0.5, 4.0)
		"nanobot":   # paints a sight line, then fires a red laser beam (see _move "aim" and "beam")
			mode = "aim"
			mode_time = EnemyScript.NANO_AIM
			creature.atk_phase = "aim"
			creature.atk_t = EnemyScript.NANO_AIM
			creature.atk_dir = dir
			aim_hold = EnemyScript.NANO_AIM + 0.3
		"ram":
			_dash(dir, 0.6)
		"zipbomb":   # pops and reappears, like a VOLATILE threat
			burst(pos, col, 22, 300.0, 5.0)
			ring(pos, col, _radius() + 60.0, 0.4, 8.0)
			creature.visible = false
			mode = "hidden"
			mode_time = 0.9
		_:
			_dash(dir, 0.0)


func _boss_attack(name: String, aim: Vector2) -> void:
	var pos: Vector2 = creature.position
	var dir := _aim_dir(aim)
	match name:
		"radial":
			for i in 16:
				shoot(Vector2.from_angle(TAU * i / 16.0 + t) * 120.0, true)
		"aimed":
			for i in 3:
				shoot(dir.rotated((i - 1) * 0.16) * 180.0, true)
		"fan":
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.14) * 185.0, true)
		"spiral":
			spiral_time = 2.0
		"dash":
			_dash(dir, 0.8)
		"blink":
			_blink()
		"slam":
			slam(aim, 52.0, 1.0)
			if randf() < 0.5:
				slam(aim + Vector2.from_angle(randf() * TAU) * 90.0, 52.0, 1.0)
		_:
			if name.begins_with("summon_"):
				var what: String = {"summon_popup": "popup", "summon_spy": "spyware", "summon_bug": "bug", "summon_trojan": "trojan",
					"summon_botnet": "botnet", "summon_kernel": "rootkit"}.get(name, "bug")
				for i in (4 if what in ["popup", "bug"] else 2):
					minion(what, pos)
				burst(pos, Global.C_MAGENTA, 10, 180.0)


## Charge in a straight line; windup > 0 shows the game's own telegraph first (botnet line, boss dash line).
func _dash(dir: Vector2, windup: float) -> void:
	dash_dir = dir
	creature.dash_dir = dir
	if windup > 0.0:
		mode = "windup"
		mode_time = windup
		creature.state = "windup"
	else:
		mode = "dash"
		mode_time = 0.3
		creature.state = "dash"


func _blink() -> void:
	burst(creature.position, col, 12, 200.0)
	creature.position = _rand_point(_inner())
	trail.clear()
	burst(creature.position, col, 12, 200.0)


func shoot(vel: Vector2, heavy := false):
	if bullets.size() >= MAX_BULLETS:
		return null
	var b = BulletScript.new()
	b.position = creature.position
	b.velocity = vel
	b.color = col.lightened(0.3) if heavy else col
	b.heavy = heavy
	b.scale = Vector2.ONE * (0.9 if heavy else 0.75)
	world.add_child(b)
	b.player = target   # after _ready; the target is never alive, so the shot hits nothing
	bullets.append(b)
	return b


func _tick_bullets() -> void:
	var r := Rect2(-W / 2.0, -H / 2.0, W, H).grow(-4.0)
	for b in bullets.duplicate():
		if not is_instance_valid(b):
			bullets.erase(b)
		elif not r.has_point(b.position):
			burst(b.position.clamp(r.position, r.end), b.color, 4, 80.0, 3.0, 0.25)   # fizzles on the bars
			b.queue_free()
			bullets.erase(b)


func minion(kind: String, at: Vector2) -> void:
	if minions.size() >= MAX_MINIONS:
		return
	var e = EnemyScript.new()
	e.setup(kind, 0.0, false)
	e.scale = Vector2.ONE * ENEMY_SIZE * 0.55 / e.radius
	var inner := Rect2(-W / 2.0 + 14.0, -H / 2.0 + 14.0, W - 28.0, H - 28.0)
	e.position = (at + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 50.0)).clamp(inner.position, inner.end)
	world.add_child(e)
	e.player = target
	minions.append([e, randf_range(2.5, 4.0), _rand_point(inner)])


func _tick_minions(delta: float) -> void:
	var inner := Rect2(-W / 2.0 + 14.0, -H / 2.0 + 14.0, W - 28.0, H - 28.0)
	for m in minions.duplicate():
		var e = m[0]
		if not is_instance_valid(e):
			minions.erase(m)
			continue
		m[1] -= delta
		if m[1] <= 0.0:
			burst(e.position, e.color, 8, 140.0)
			e.queue_free()
			minions.erase(m)
			continue
		var to: Vector2 = m[2] - e.position
		if to.length() < 6.0:
			m[2] = _rand_point(inner)
		e.position = (e.position + to.normalized() * clampf(e.speed * 0.9, 50.0, 140.0) * delta).clamp(inner.position, inner.end)


func burst(pos: Vector2, c: Color, count := 10, speed := 200.0, size := 4.0, life := 0.5) -> void:
	var b = BurstScript.new()
	b.setup(count, c, speed, size, life)
	b.position = pos
	world.add_child(b)


func ring(pos: Vector2, c: Color, radius := 80.0, life := 0.4, width := 5.0) -> void:
	var r = RingScript.new()
	r.color = c
	r.max_radius = radius
	r.life = life
	r.width = width
	r.position = pos
	world.add_child(r)


func slam(pos: Vector2, radius: float, delay: float) -> void:
	var sl := Slam.new()
	sl.position = pos
	sl.radius = radius
	sl.delay = delay
	sl.color = col
	sl.cage = self
	world.add_child(sl)
