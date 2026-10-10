extends Node2D
## The antivirus core. WASD / arrows to move; weapons fire on their own.
## Base stats are boosted by research (Meta) when the run starts.

signal leveled_up
signal died

const IconArt = preload("res://scripts/icon_art.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const BASE_SPEED := 210.0
var class_id := ""                   # id of the chosen class, "" = the base class (picks the pixel avatar)
var class_icon := ""                 # the chosen class (see game._apply_class); "" = the base pointer
var class_color := Global.C_CYAN
const MAX_SPEED_MULT := 2.0
const BASE_PICKUP := 85.0

var speed := 210.0
var max_hp := 70.0
var hp := 70.0
var regen := 0.0
var armor := 0.0
var thorns := 0.0
var iframe := 0.5
var radius := 13.0
var pickup_radius := 85.0
var damage_mult := 1.0
var cooldown_mult := 1.0
var abilcd := 0.0            # -% ability cooldown (HOT SWAP: research plus cards, capped in game)
var area_mult := 1.0
var extra_proj := 0
var knockback_mult := 1.0    # how far hits push threats
var heal_mult := 1.0         # all healing received
var lifesteal := 0.0         # fraction of damage dealt returned as healing (rate-limited)
var dodge := 0.0             # chance to ignore a hit completely
var hazard_speed := 1.0       # set by the device hazard (hazards.gd)
const LATCH_SLOW := 0.55      # move speed multiplier while a mite is latched on (enemy.gd, does not stack)
var latch_timer := 0.0        # kept above 0 by latched mites
var hazard_push := Vector2.ZERO
var knock_vel := Vector2.ZERO   # a shove from a RAM charge (see knock), fades fast
var hazard_cd := 1.0
var proj_speed := 1.0        # speed of bolts and discs
var leech_budget := 0.0
const KNOCKBACK_CAP := 3.0
const HEAL_CAP := 2.0
const LIFESTEAL_CAP := 0.025
const DODGE_CAP := 0.4
const COOLDOWN_FLOOR := 0.2   # weapon and item cooldown multipliers never go below this
const STATUS_CAP := 60.0            # max chance (%) for each status effect
const STATUS_POTENCY_CAP := 150.0   # max bonus (%) to status damage and duration

## Status effects: each hit rolls these chances (in %). VIRULENCE raises status damage and duration (see enemy.gd).
var status_chance := {"burn": 0.0, "poison": 0.0, "freeze": 0.0, "shock": 0.0}
var status_potency := 0.0
var status_chance_mult := 1.0       # INFECTION TRANSMISSION: scales every status chance, including weapons' own
var status_duration_mult := 1.0     # TOXIC PERSISTENCE: scales how long statuses last (on top of VIRULENCE)
var guard := 0.0            # damage reduction (fraction) against elites and bosses, from research
const PROJ_SPEED_CAP := 2.5
var duration_mult := 1.0     # lifetime of zones, totems, beacons, decoys and mines
var item_cooldown_mult := 1.0 # item timers; weapon cooldown still applies on top (see item_cd())
var extra_pierce := 0
var crit_chance := 0.05
var crit_mult := 2.0
var boss_mult := 1.0
var xp_mult := 1.0
var weapon_dmg := {}
var revives := 0
var combo_xp := 0.0     # bonuses from the current combo (set by the game)
var combo_crit := 0.0
var combo_luck := 0.0
var luck_run := 0.0           # upgrade rarity luck gained from cards this run (percent)
var items := {}               # special items owned: id -> behavior node (or true)
var damage_taken_mult := 1.0
var shield_level := 0
var shield_ready := false
var shield_timer := 0.0

var xp := 0.0
var level := 1
var xp_to_next := 5

var weapons := {}
var facing := Vector2.RIGHT
var invuln := 0.0
var ghost_time := 0.0   # GHOST PHASE: invisible (threats lose track of you) and able to walk through walls
var alive := true
var spin := 0.0
var trail := []
var level_glow := 0.0


func _ready() -> void:
	add_to_group("player")


# Percent bonuses ADD together (research + prestige + in-run upgrades) instead of multiplying.
var pct := {"speed": 0.0, "dmg": 0.0, "haste": 0.0, "magnet": 0.0, "itemcd": 0.0}

const AREA_CAP := 2.5   # weapon area (zones, rings, blasts and reach) counts up to this, whatever the stat says
const PROJ_SIZE_CAP := 2.0   # weapon area grows bolts and discs up to this size, so big builds stay readable


func status_mult() -> float:
	return 1.0 + status_potency / 100.0


## Duration multiplier for statuses: VIRULENCE times TOXIC PERSISTENCE.
func status_time_mult() -> float:
	return status_mult() * status_duration_mult


func recalc() -> void:
	speed = BASE_SPEED * (1.0 + pct["speed"] / 100.0)
	pickup_radius = BASE_PICKUP * (1.0 + pct["magnet"] / 100.0)
	damage_mult = 1.0 + pct["dmg"] / 100.0
	cooldown_mult = maxf(COOLDOWN_FLOOR, 1.0 - pct["haste"] / 100.0) * hazard_cd   # hazard applied after the floor so haste cannot cancel it
	item_cooldown_mult = maxf(0.3, 1.0 - pct["itemcd"] / 100.0)


## Weapon area as every weapon and item uses it: the stat itself can keep growing but never counts past AREA_CAP.
func area() -> float:
	return clampf(area_mult, 1.0, AREA_CAP)


## Size multiplier for projectiles: weapon area, capped lower still so big builds stay readable.
func proj_size() -> float:
	return clampf(area(), 1.0, PROJ_SIZE_CAP)


## Item timer multiplier: the item cooldown stat times the weapon cooldown stat (floor x0.2).
func item_cd() -> float:
	return maxf(COOLDOWN_FLOOR, item_cooldown_mult * cooldown_mult)


func add_bonus(key: String, amount: float) -> void:
	pct[key] += amount
	recalc()


func apply_research() -> void:
	pct["speed"] += Meta.stat("move")
	max_hp += Meta.stat("hp")
	hp = max_hp
	regen += Meta.stat("regen")
	armor += Meta.stat("armor")
	thorns += Meta.stat("thorns")
	iframe += Meta.stat("iframe")
	pct["magnet"] += Meta.stat("magnet")
	pct["dmg"] += Meta.stat("dmg") + Meta.root_damage_bonus() * 100.0
	pct["haste"] += Meta.stat("cd")
	pct["itemcd"] += Meta.stat("itemcd")
	abilcd = minf(Meta.stat("abilcd"), 50.0)
	recalc()
	area_mult += Meta.stat("area") / 100.0
	extra_proj = int(Meta.stat("proj"))
	extra_pierce = int(Meta.stat("pierce"))
	crit_chance += Meta.stat("crit") / 100.0
	crit_mult += Meta.stat("critdmg") / 100.0
	boss_mult += Meta.stat("bossdmg") / 100.0
	xp_mult += Meta.stat("xp") / 100.0
	knockback_mult = minf(knockback_mult + Meta.stat("knockback") / 100.0, KNOCKBACK_CAP)
	heal_mult = minf(heal_mult + Meta.stat("healing") / 100.0, HEAL_CAP)
	lifesteal = minf(lifesteal + Meta.stat("lifesteal") / 100.0, LIFESTEAL_CAP)
	dodge = minf(dodge + Meta.stat("dodge") / 100.0, DODGE_CAP)
	proj_speed = minf(proj_speed + Meta.stat("projspeed") / 100.0, PROJ_SPEED_CAP)
	for k in status_chance:
		status_chance[k] = minf(status_chance[k] + Meta.stat(k), STATUS_CAP)
	status_potency = minf(status_potency + Meta.stat("potency"), STATUS_POTENCY_CAP)
	status_chance_mult = 1.0 + Meta.stat("statchance") / 100.0
	status_duration_mult = 1.0 + Meta.stat("statusdur") / 100.0
	guard = minf(Meta.stat("guard") / 100.0, 0.6)
	revives = int(Meta.stat("revive"))
	shield_level = int(Meta.stat("shield"))
	shield_ready = shield_level > 0
	for id in ["laser", "firewall", "orbit", "zap", "mines", "scanner", "quarantine", "backdoor"]:
		weapon_dmg[id] = 1.0 + (Meta.stat("wdmg_" + id) + Meta.stat("wdmg_all")) / 100.0


func shield_cooldown() -> float:
	return 30.0 - 6.0 * (shield_level - 1)


func _process(delta: float) -> void:
	queue_redraw()
	spin += delta * 1.5
	level_glow = maxf(0.0, level_glow - delta * 1.5)
	if not alive:
		return
	invuln = maxf(0.0, invuln - delta)
	ghost_time = maxf(0.0, ghost_time - delta)
	leech_budget = minf(max_hp * 0.015, leech_budget + max_hp * 0.015 * delta)
	hp = minf(max_hp, hp + regen * delta)
	if shield_level > 0 and not shield_ready:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shield_ready = true
			Sfx.play("heal", 1.8)

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): dir.y += 1.0
	dir += Global.joystick_vec
	dir = dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		facing = facing.lerp(dir.normalized(), minf(1.0, delta * 14.0)).normalized()
	latch_timer = maxf(0.0, latch_timer - delta)
	var latch_mult := LATCH_SLOW if latch_timer > 0.0 else 1.0
	var before := position
	position += dir * minf(speed, BASE_SPEED * MAX_SPEED_MULT) * hazard_speed * latch_mult * delta + hazard_push * delta + knock_vel * delta
	if knock_vel != Vector2.ZERO:
		knock_vel = knock_vel.move_toward(Vector2.ZERO, 1800.0 * delta)
		if Global.game and Global.game.arena != null:
			position = Global.game.arena.clip_move(before, position, radius)   # never thrown through a wall
	if Global.game and Global.game.arena != null:
		if ghost_time <= 0.0:
			position = Global.game.arena.push_out(position, radius)
		else:   # a ghost drifts through walls (the first frame after it ends pushes it out) but never off the map
			position = Global.game.arena.clamp_to_bounds(position, radius)

	trail.push_front(global_position)
	if trail.size() > 10:
		trail.pop_back()


## Weapons that apply a status of their own: weapon id -> [status, base chance %, extra % per weapon level].
const WEAPON_STATUS := {"firewall": ["burn", 8.0, 2.0], "quarantine": ["freeze", 8.0, 2.0], "zap": ["shock", 8.0, 2.0],
	"orbit": ["poison", 8.0, 2.0], "evo_inferno": ["burn", 25.0, 2.0], "evo_tesla": ["shock", 25.0, 2.0], "evo_blizzard": ["freeze", 25.0, 2.0]}


## Returns [damage, is_crit] for a hit from weapon_id on target.
func calc_damage(base: float, weapon_id := "", target = null) -> Array:
	var dmg: float = base * damage_mult * weapon_dmg.get(weapon_id, 1.0) * randf_range(0.9, 1.1)
	if target != null and "hit_src" in target:
		target.hit_src = weapon_id
	if target != null and WEAPON_STATUS.has(weapon_id) and weapons.has(weapon_id) and target.has_method("apply_status"):
		var ws: Array = WEAPON_STATUS[weapon_id]
		if randf() * 100.0 < (ws[1] + ws[2] * weapons[weapon_id].level) * status_chance_mult:
			target.apply_status(ws[0], dmg)
	if target != null and (target.elite or target.is_boss):
		dmg *= boss_mult
	# crit chance above 100% adds extra crit tiers; each tier adds another (crit_mult - 1) of bonus damage
	var total_crit := crit_chance + combo_crit
	var tiers := int(total_crit)
	if randf() < total_crit - tiers:
		tiers += 1
	if tiers > 0:
		dmg *= 1.0 + (crit_mult - 1.0) * tiers
		if target != null and Global.game:
			Global.game._item_event("on_crit", target)
	return [dmg, tiers]


func add_weapon(id: String, script: Script, start_level := 1) -> void:
	var w = script.new()
	w.level = start_level
	add_child(w)
	weapons[id] = w


func take_damage(amount: float, attacker = null, heavy := false) -> void:
	if not alive:
		return
	if attacker != null and thorns > 0.0 and is_instance_valid(attacker):
		attacker.take_damage(thorns * damage_mult)
	if invuln > 0.0:
		return
	if dodge > 0.0 and randf() < minf(dodge, DODGE_CAP):
		if Global.game:
			Global.game.float_text(global_position + Vector2(0, -34), "DODGE", Global.C_CYAN, 22, 0.6)
		return
	if shield_ready:
		shield_ready = false
		shield_timer = shield_cooldown()
		invuln = 0.6
		Sfx.play("select", 0.6)
		if Global.game:
			Global.game.ring(global_position, Global.C_CYAN, 90.0, 0.35, 6.0)
		return
	if heavy or (attacker != null and is_instance_valid(attacker) and (attacker.elite or attacker.is_boss)):
		amount *= 1.0 - guard   # BLAST DOORS: elites, bosses and boss shots
	hp -= maxf(1.0, amount - armor) * damage_taken_mult
	invuln = iframe
	Sfx.play("hurt")
	if Global.game:
		Global.game.on_player_hurt()
	if hp <= 0.0:
		if revives > 0:
			revives -= 1
			hp = max_hp * 0.5
			invuln = 2.5
			if Global.game:
				Global.game.on_player_revived()
			return
		hp = 0.0
		alive = false
		died.emit()


## Throws the player back (RAM charges). Does not stack: the stronger shove wins.
func knock(v: Vector2) -> void:
	if v.length() > knock_vel.length():
		knock_vel = v


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount * heal_mult)


## Lifesteal: called for every hit the player's weapons land. Healing is limited to 1.5% max HP per second
## (with up to one second banked) so huge late-game hits cannot make the player immortal.
func on_damage_dealt(amount: float) -> void:
	if lifesteal <= 0.0 or not alive:
		return
	var h := minf(amount * lifesteal, leech_budget)
	leech_budget -= h
	heal(h)


func add_xp(amount: float) -> void:
	xp += amount * (xp_mult + combo_xp)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.16) + 4
		level_glow = 1.0
		leveled_up.emit()


func _draw() -> void:
	if not alive:
		return
	modulate.a = 0.4 if ghost_time > 0.0 else 1.0
	var col := class_color
	if invuln > 0.0 and int(invuln * 24.0) % 2 == 0:
		col = Global.C_RED

	for i in range(trail.size() - 1, 0, -1):
		var p: Vector2 = trail[i] - global_position
		draw_circle(p, radius * (1.0 - i / 12.0), Color(col, 0.05 * (10 - i) / 10.0))

	var avatar: Texture2D = PixelArt.class_run_tex(class_id)
	if shield_ready:
		draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 32, Color(0.5, 0.9, 1.0, 0.55 + 0.2 * sin(spin * 4.0)), 2.5)

	if avatar == null:   # no pixel avatar: the old ring and spinning hexagon (with the art in, the sprite stands alone)
		Global.glow_circle(self, Vector2.ZERO, radius + 2.0, col, 1.4 + level_glow * 3.0)
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(Vector2.from_angle(spin + TAU * i / 6.0) * (radius + 4.0))
		draw_colored_polygon(hex, Color(col, 0.15))
		hex.append(hex[0])
		draw_polyline(hex, col, 2.5)

	var f := facing
	var s := f.orthogonal()
	if avatar != null:   # the class's pixel avatar stands in the ring; the pointer keeps the facing readable
		var blink := Color(1.0, 0.45, 0.45) if col == Global.C_RED else Color.WHITE
		PixelArt.draw_class(self, avatar, Vector2(0.0, -3.0), 42.0, Time.get_ticks_msec() / 1000.0, facing.x < 0.0, blink)
		draw_colored_polygon(PackedVector2Array([f * (radius + 13.0), f * (radius + 6.0) + s * 4.0, f * (radius + 6.0) - s * 4.0]), Color(0.9, 1.0, 1.0))
	elif class_icon == "":
		draw_colored_polygon(PackedVector2Array([f * 11.0, -f * 6.0 + s * 7.0, -f * 2.0, -f * 6.0 - s * 7.0]), Color(0.9, 1.0, 1.0))
	else:   # a class shows its icon inside the hexagon, with a small pointer so the facing stays readable
		IconArt.draw_icon(self, class_icon, Vector2.ZERO, radius * 0.7, col, spin)
		draw_colored_polygon(PackedVector2Array([f * (radius + 9.0), f * (radius + 2.0) + s * 4.0, f * (radius + 2.0) - s * 4.0]), Color(0.9, 1.0, 1.0))
	if avatar == null:
		draw_circle(Vector2.from_angle(-spin * 2.2) * (radius + 10.0), 2.5, col)

	var w := 40.0
	var y := radius + 12.0
	draw_rect(Rect2(-w / 2.0 - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2.0, y, w, 5), Color(0.3, 0.05, 0.08))
	var hp_col := Global.C_GREEN.lerp(Global.C_RED, 1.0 - hp / max_hp)
	draw_rect(Rect2(-w / 2.0, y, w * hp / max_hp, 5), hp_col)
	for i in revives:
		draw_circle(Vector2(-w / 2.0 + 4 + i * 8, y + 11), 2.5, Global.C_GOLD)
