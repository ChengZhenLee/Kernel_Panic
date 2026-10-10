extends Node2D
const FD = preload("res://scripts/fx/fd.gd")
## Game root: spawning, bosses, upgrades with rarities, DATA economy and effects.
## Timeline: new malware every ~45-90s, elites every 60s, slowing to 100s late, swarms every 60s,
## bosses at 3:00 / 6:00 / 9:00 and the final ROOT KERNEL at 12:00 (defeat it to cure the device).

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const CodexData = preload("res://scripts/codex_data.gd")
const BossScript = preload("res://scripts/boss.gd")
const BulletScript = preload("res://scripts/enemy_bullet.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const HudScript = preload("res://scripts/hud.gd")
const CameraScript = preload("res://scripts/camera.gd")
const BurstScript = preload("res://scripts/fx/burst.gd")
const TextScript = preload("res://scripts/fx/float_text.gd")
const RingScript = preload("res://scripts/fx/ring.gd")
const LightningScript = preload("res://scripts/fx/lightning.gd")
const FloorTileScript = preload("res://scripts/fx/floor_tile.gd")
const AbilityFxScript = preload("res://scripts/fx/ability_fx.gd")
const TimeClockScript = preload("res://scripts/fx/time_clock.gd")
const ItemData = preload("res://scripts/items.gd")
const BossData = preload("res://scripts/boss_data.gd")
const TelegraphScript = preload("res://scripts/fx/telegraph.gd")

const MAX_ENEMIES := 150
const BOSS_ADD_CAP := 24   # most enemies summoned by bosses that may be alive at once
const SWARM_EXTRA := 50         # swarms (and the rest of a mite pack) may go this far over the cap
const ELITE_EXTRA := 15         # elites too; bosses always spawn
const LEVEL_GAIN := [1, 2, 2, 3]
const PURGE_ELITE_CHANCE := 0.04   # chance an elite drops a System Purge pickup
const PURGE_CHANCE := 0.0006        # chance any other kill drops one
const PURGE_ELITE_PCT := 0.15      # share of an elite's max HP a System Purge removes, times the player's damage
const PATCH_HEAL := 22.0            # HP a repair patch restores, before HOT PATCH research and healing received
const ARMOR_CAP := 12.0        # upgrade cards stop offering armor at this total
const PIERCE_CARD_CAP := 6      # ...and pierce at this many extra pierce (keeps weapon counts sane on phones)
const PROJ_CAP := 4             # extra projectiles never go above this (phone performance)
const ITEMCD_CAP := 50.0        # item cooldown cards stop at -50%
const DURATION_ITEMS := ["totem", "decoy", "beacon"]
# Combos: +1 per kill, then they bleed away continuously (faster the bigger they are), so they stay in a
# sane range even in huge swarms. Getting hit costs a quarter of the combo.
const COMBO_DECAY := 0.6          # base fraction lost per second
const HOLD_BUFFER_TIME := 1.5   # HOLD BUFFER item
const CHERRY_LUCK := 3.0        # CHERRY PICK item: extra rarity luck on every offer (+300%)
const COMBO_SOFT := 400.0         # extra decay grows with combo / this
const COMBO_TIERS := [10, 20, 40, 80]
const COMBO_REWARDS := [          # per tier: fractional bonuses
	{"xp": 0.10, "data": 0.05, "crit": 0.0, "luck": 0.0},
	{"xp": 0.20, "data": 0.10, "crit": 0.05, "luck": 0.0},
	{"xp": 0.30, "data": 0.20, "crit": 0.10, "luck": 0.10},
	{"xp": 0.50, "data": 0.30, "crit": 0.20, "luck": 0.20},
]
const CACHE_CHANCE := 0.3       # chance an elite drops a cache with no luck (bosses always do)
const CACHE_CHANCE_MAX := 0.6   # the chance luck pushes it towards
const BOSS_TIMES := [180.0, 360.0, 540.0, 720.0]
const MITE_PACK_MIN := 5   # mites always spawn in packs of at least this many (see _spawn_mite_pack)
const MITE_PACK_MAX := 8
# malware types in the order a run introduces them (minute column is legacy, unused; see ROSTER_*), and their spawn weight (mite is low because one pick spawns a whole pack)
const SPAWN_TABLE := [["bug", 0.0, 40.0], ["worm", 0.0, 30.0], ["mite", 0.0, 7.0], ["adware", 0.75, 20.0], ["trojan", 1.5, 16.0],
	["miner", 2.0, 12.0], ["zipbomb", 2.0, 10.0], ["spyware", 2.25, 10.0], ["sentry", 2.75, 10.0], ["leech", 3.0, 12.0],
	["nanobot", 3.0, 10.0], ["botnet", 3.5, 12.0], ["ram", 4.0, 10.0], ["ransom", 4.5, 7.0], ["rootkit", 6.0, 9.0]]
## Each device draws its regular enemies from its own pool, so no two devices feel the same (THE INTERNET and unlisted tiers use every kind).
const DEVICE_POOLS := [
	["bug", "worm", "mite", "adware", "trojan", "spyware", "ransom"],               # SMART FRIDGE
	["bug", "mite", "adware", "zipbomb", "spyware", "sentry", "nanobot", "ram", "rootkit"],          # SMARTPHONE
	["bug", "worm", "trojan", "miner", "zipbomb", "leech", "ram", "ransom", "rootkit"],              # GAMING LAPTOP
	["bug", "worm", "trojan", "miner", "sentry", "nanobot", "leech", "botnet", "rootkit"],           # OFFICE SERVER
	["worm", "mite", "spyware", "miner", "zipbomb", "sentry", "leech", "nanobot", "ransom"],         # DATA CENTER
	["bug", "mite", "adware", "zipbomb", "sentry", "leech", "nanobot", "ram", "rootkit", "ransom"],   # SATELLITE UPLINK
	["worm", "trojan", "spyware", "miner", "zipbomb", "nanobot", "botnet", "ram", "rootkit", "ransom"],  # MAINFRAME
]
## Staggered roster: a run starts with the device pool's first ROSTER_START types (SPAWN_TABLE order).
## Every ROSTER_STEP minutes the next type arrives and the oldest live one stops spawning, so only
## ROSTER_LIVE types are ever in rotation. Once the pool runs out it wraps around (long runs, overtime).
const ROSTER_START := 3
const ROSTER_STEP := 2.0
const ROSTER_LIVE := 3
const MOD_CHANCE_DEVICE := 0.06   # chance a regular enemy carries a modifier, per device after the first
const MOD_CHANCE_THREAT := 0.03   # ... and per threat level
const MOD_CHANCE_MAX := 0.45

var WEAPONS := {
	"laser": {"title": "PACKET GUN", "script": preload("res://scripts/weapons/laser.gd"),
		"desc": "Fires data bolts at the nearest threat."},
	"firewall": {"title": "FIREWALL", "script": preload("res://scripts/weapons/firewall.gd"),
		"desc": "A burning ring that damages every threat inside."},
	"orbit": {"title": "ENCRYPTION KEYS", "script": preload("res://scripts/weapons/orbit.gd"),
		"desc": "Crystal shards orbit you and shred threats."},
	"zap": {"title": "PING.EXE", "script": preload("res://scripts/weapons/zap.gd"),
		"desc": "Chain lightning jumps between threats."},
	"mines": {"title": "LOGIC MINE", "script": preload("res://scripts/weapons/mines.gd"),
		"desc": "Drops proximity mines that blow up crowds."},
	"scanner": {"title": "SCANNER", "script": preload("res://scripts/weapons/scanner.gd"),
		"desc": "Radar beams sweep around you."},
	"quarantine": {"title": "QUARANTINE", "script": preload("res://scripts/weapons/quarantine.gd"),
		"desc": "Freezing zones slow and damage groups."},
	"backdoor": {"title": "BACKDOOR", "script": preload("res://scripts/weapons/backdoor.gd"),
		"desc": "Opens a door behind a threat; a boomerang flies out and hits it in the back."},
	"evo_railgun": {"title": "RAILGUN", "script": preload("res://scripts/weapons/evo_railgun.gd"),
		"desc": "Fires a piercing beam through everything in a line."},
	"evo_inferno": {"title": "SCORCHED EARTH", "script": preload("res://scripts/weapons/evo_inferno.gd"),
		"desc": "A huge burning ring that ignites and erupts."},
	"evo_tesla": {"title": "TESLA GRID", "script": preload("res://scripts/weapons/evo_tesla.gd"),
		"desc": "Lightning hits many threats at once and shocks them."},
	"evo_blizzard": {"title": "ABSOLUTE ZERO", "script": preload("res://scripts/weapons/evo_blizzard.gd"),
		"desc": "A pulsing frost aura freezes everything around you."},
}
const ArenaScript = preload("res://scripts/arena.gd")
const EndlessScript = preload("res://scripts/endless_field.gd")
const HazardScript = preload("res://scripts/hazards.gd")
const SWARM_ELITE_CAP := 2   # most elites a single swarm wave may carry
const EVO_CHANCE := 0.5   # chance a ready evolution is offered as the first card of any offer (a normal Legendary is far rarer)

var STATS := {
	"speed": {"title": "OVERCLOCK", "base": 8.0, "desc": "+%s%% move speed"},
	"vitality": {"title": "REDUNDANCY", "base": 15.0, "desc": "+%s max HP and repair it"},
	"magnet": {"title": "BANDWIDTH", "base": 25.0, "desc": "+%s%% pickup range"},
	"might": {"title": "ROOT ACCESS", "base": 8.0, "desc": "+%s%% damage"},
	"haste": {"title": "MULTITHREAD", "base": 6.0, "desc": "-%s%% weapon cooldowns"},
	"crit": {"title": "EXPLOIT", "base": 4.0, "desc": "+%s%% critical hit chance"},
	"regen": {"title": "SELF-REPAIR", "base": 0.4, "desc": "Regenerate %s HP per second"},
	"area": {"title": "AMPLIFIER", "base": 6.0, "desc": "+%s%% weapon area"},
	"luck": {"title": "FORTUNE", "base": 6.0, "desc": "+%s%% upgrade rarity luck"},
	"critdmg": {"title": "LETHALITY", "base": 12.0, "desc": "+%s%% critical damage"},
	"armor": {"title": "HARDENING", "base": 0.6, "desc": "+%s armor"},
	"pierce": {"title": "PENETRATION", "base": 1.0, "int": true, "desc": "Bolts pierce %s more threats"},
	"knockback": {"title": "IMPACT", "base": 15.0, "desc": "+%s%% knockback"},
	"healing": {"title": "BIO-ENHANCE", "base": 12.0, "desc": "+%s%% healing received"},
	"lifesteal": {"title": "LEECH", "base": 0.4, "desc": "Heal %s%% of damage you deal"},
	"dodge": {"title": "EVASION", "base": 4.0, "desc": "+%s%% chance to dodge a hit"},
	"projspeed": {"title": "PROJECTILE SPEED", "base": 10.0, "desc": "+%s%% projectile speed"},
	"xp": {"title": "MACHINE LEARNING", "base": 6.0, "desc": "+%s%% XP gain"},
	"proj": {"title": "PROJECTILE COUNT", "base": 1.0, "int": true, "desc": "+%s projectile count"},
	"duration": {"title": "PERSISTENCE", "base": 8.0, "desc": "+%s%% effect duration"},
	"abilcd": {"title": "HOT SWAP", "base": 6.0, "desc": "-%s%% ability cooldown"},
	"itemcd": {"title": "SCHEDULER", "base": 6.0, "desc": "-%s%% item cooldowns"},
	"burn": {"title": "IGNITION", "base": 8.0, "desc": "+%s%% chance to set threats on fire"},
	"poison": {"title": "TOXIN", "base": 8.0, "desc": "+%s%% chance to poison threats (stacks)"},
	"freeze": {"title": "CRYOGEN", "base": 8.0, "desc": "+%s%% chance to freeze threats (slows them)"},
	"shock": {"title": "STATIC SHOCK", "base": 8.0, "desc": "+%s%% chance to shock threats (stuns them and they take more damage)"},
	"potency": {"title": "VIRULENCE", "base": 15.0, "desc": "+%s%% status effect damage and duration"},
}

var player
var camera
var hud
var pickup_layer: Node2D
var enemy_layer: Node2D
var bullet_layer: Node2D
var fx_layer: Node2D
var ability_fx_layer: Node2D   # ability FX: above enemies, always below the player
var text_layer: Node2D

var elapsed := 0.0
var spawn_timer := 0.0
var elite_timer := 45.0
var swarm_timer := 45.0
var kills := 0
var combo := 0.0
var combo_hold := 0.0   # HOLD BUFFER: seconds left before the combo starts fading again
var combo_eval := 0.0
var combo_bonus := {"xp": 0.0, "data": 0.0, "crit": 0.0, "luck": 0.0}
var combo_data := 0.0
var combo_tier_seen := 0
var combo_announce_cd := 0.0
var best_combo := 0
var pickup_chain := 0
var pickup_chain_timer := 0.0
var pending_drops := 0   # drops spawned this frame (added deferred, so not in the group yet)

var raw_data := 0.0
var bosses_defeated := 0
var next_boss := 0
var boss_warning := -1.0
var current_boss = null
var victory := false
var real_elapsed := 0.0      # wall-clock seconds this run; elapsed runs faster in speed-run mode
var challenge := {}          # the challenge picked on the map for this run (empty = none)
var challenge_clock := 0.0
var fog_rect: ColorRect       # INCOGNITO MODE: everything beyond your weapon area is black
const FOG_BASE := 190.0       # vision radius in pixels at area x1.0; the area card and area stats widen it
var shock_kills := 0         # threats that died while shocked / frozen this run (secret weapons)
var freeze_kills := 0
var hits_taken := 0          # hits this run (for the FLAWLESS achievement)
var new_achievements := []   # achievements completed this run (shown on the results screen)
var cure_record := false     # fastest cure so far in this mode
var pp_gained := 0           # prestige points this run's cure paid
var cashed_out := false      # left through CASH OUT (after the final boss) rather than by dying
var first_cure := false        # this run's cure was the device's first
var start_best_boss := 0       # Meta.best_boss when the run began (for the 'new ring' note)
var overtime := false          # playing on after the final boss
var overtime_start := 0.0
var overtime_bosses := 0
var next_ot_boss := 0.0
var ot_boss_def := {}
const OT_BOSS_EVERY := 180.0   # a boss every 3 minutes of overtime
var run_over := false
var rerolls := 0
var bans_left := 0
var banned := {}   # ban key -> label; "id:tier" for one rarity of a card, "item:id" for a whole item (never saved)
const FREE_BANS := 1
const MAX_WEAPON_SLOTS := 5   # hard cap: base slots + research + prestige can never exceed this
var choices := 3
var max_weapons := 4
const BASE_WEAPON_LEVEL := 10
var max_weapon_level := BASE_WEAPON_LEVEL

var offer_queue := []
var offer_open := false
var current_offer := {}
var announced_kinds := {}
var roster_order := []     # this run's pool in arrival order (built on first use)
var roster_announced := 0  # last roster step announced
var swarm_wave := 0
var boss_lineup := []   # this run's four bosses: 3 random bosses, then the device's final boss
var evolved := []           # evolution ids reached this run
var evo_ready_told := {}
var hazards: Node2D
var main_arena: Node2D        # the device arena; arena points at the boss room while a boss fight is on
var room_arena: Node2D
var in_room := false
var room_return := Vector2.ZERO
var arena: Node2D              # the fixed walled arena (null on THE INTERNET)
var internet := false          # THE INTERNET: no final boss, overtime starts at 12:00 and never ends
var cls := {}              # the active class (empty = none)
var ability_cd := 0.0
var abil := {}              # the ability on the button: the class's, or the generic PURGE (charges only)
var charges := 0
var sweet_t := -1.0         # seconds since the last cast while the sweet-spot ring runs (-1 = closed)
var sweet_done := false
var overclock_extra := 0.0
var storm_t := 0.0          # THUNDERSTORM: seconds of storm left
var storm_tick := 0.0
var storm_m := 1.0          # 1.5 while a SUPER storm runs
var super_casts := 0
const MAX_CHARGES := 3
const ABILCD_CAP := 50.0    # ability cooldown cards and research stop at -50%
var max_charges := MAX_CHARGES
const SWEET_LEN := 1.4      # the ring shrinks for this long
const SWEET_START_BASE := 0.85   # the sweet spot (a second tap here is a SUPER cast)
const SWEET_END_BASE := 1.35
var SWEET_START: float:
	get: return SWEET_START_BASE - Meta.stat("supwin")
var SWEET_END: float:
	get: return minf(SWEET_LEN, SWEET_END_BASE + Meta.stat("supwin") * 0.4)
var ability_active := 0.0
var time_stop := 0.0        # PAUSE ability: threats, enemy shots, hazards and spawns freeze while this runs
var swarm_alive := {}   # swarm wave number -> enemies still alive (clearing a whole wave drops a Purge)
var purging := false
var frame := 0

# Each swarm wave is bigger and nastier. [label, kinds...]; later waves cycle the last entries.
const SWARM_WAVES := [
	["BUG SWARM", "bug"],
	["WORM NEST", "bug", "worm"],
	["POP-UP STORM", "popup", "adware"],
	["TROJAN HORDE", "trojan", "worm", "bug"],
	["BOTNET RAID", "botnet", "popup"],
	["SPY RING", "spyware", "trojan"],
	["RANSOM WAVE", "ransom", "botnet", "trojan"],
	["ROOTKIT OUTBREAK", "rootkit", "spyware", "botnet"],
	["ZERO-DAY BREACH", "rootkit", "ransom", "botnet", "spyware"],
]
const FORMATIONS := ["RING", "DOUBLE RING", "PINCER", "SPIRAL", "WALL"]


func _ready() -> void:
	Global.game = self
	Music.play_gameplay()
	start_best_boss = Meta.best_boss
	Meta.latch_modes()
	boss_lineup = BossData.pick_lineup(Meta.run_tier())
	internet = Meta.run_internet()
	if internet:   # THE INTERNET: an endless floor with walls scattered chunk by chunk
		arena = EndlessScript.new()
		arena.setup(Meta.device_palette())
		add_child(arena)
	else:   # every device has a fixed walled arena
		arena = ArenaScript.new()
		arena.setup(Meta.selected_device, Meta.device_palette())
		add_child(arena)
		main_arena = arena
		room_arena = ArenaScript.new()
		room_arena.setup(Meta.selected_device, Meta.device_palette(), true, Vector2(0, arena.bounds.end.y + 2200.0))
		add_child(room_arena)
		room_arena.set_active(false)
	pickup_layer = _layer(0)   # was -1: under the opaque floor, pickups were invisible (art-v2)
	enemy_layer = _layer(0)
	ability_fx_layer = _layer(0)   # added before the player at the same z, so the player always draws over ability FX
	bullet_layer = _layer(5)

	player = PlayerScript.new()
	if arena != null:
		player.position = arena.start
	add_child(player)
	player.apply_research()
	hazards = HazardScript.new()
	add_child(hazards)
	move_child(hazards, 0)   # below the player, enemies and pickups
	camera = CameraScript.new()
	player.add_child(camera)
	if arena != null and arena.bounded:
		camera.limit_left = int(arena.bounds.position.x)
		camera.limit_top = int(arena.bounds.position.y)
		camera.limit_right = int(arena.bounds.end.x)
		camera.limit_bottom = int(arena.bounds.end.y)
	player.leveled_up.connect(func(): queue_offer({"title": "LEVEL UP!", "color": Global.C_CYAN, "luck": 0.0, "decrypt": false}))
	player.died.connect(_on_player_died)

	rerolls = int(Meta.stat("reroll"))
	bans_left = FREE_BANS + int(Meta.stat("ban"))
	choices = 3 + int(Meta.stat("choices"))
	max_weapons = mini(4 + int(Meta.stat("slots")), MAX_WEAPON_SLOTS)   # also trims old saves that bought 6-7 slots
	max_weapon_level = BASE_WEAPON_LEVEL + int(Meta.stat("maxwlvl"))
	challenge = Meta.Challenges.by_id(Meta.active_challenge)
	if not challenge.is_empty() and not Meta.challenge_available(challenge):
		challenge = {}   # its reward needs a device that has not been cured yet
	_apply_class()
	if Meta.run_speed():
		player.xp_mult *= Meta.SPEED_XP
	if challenge.get("rule", "") == "glass":
		player.max_hp *= 0.35
		player.hp = player.max_hp

	fx_layer = _layer(10)
	text_layer = _layer(60)

	hud = HudScript.new()
	add_child(hud)
	hud.option_chosen.connect(_on_option_chosen)
	hud.reroll_requested.connect(_on_reroll)
	hud.ban_requested.connect(_on_ban)
	hud.ability_requested.connect(use_ability)
	abil = cls if not cls.is_empty() else Meta.Classes.GENERIC
	max_charges = MAX_CHARGES + int(Meta.stat("maxcharge"))
	hud.setup_ability(abil)
	hud.setup_map(arena, player)
	if challenge.get("rule", "") == "incognito":
		hud.minimap.visible = false
		if fog_rect == null:
			_make_fog()
	hud.refresh_loadout(self)
	hud.announce("MAP: THE INTERNET" if internet else "INFECTED DEVICE: %s" % Meta.device_name(), Global.C_CYAN)
	if not internet:
		hud.announce("MAP: %s" % Meta.MapsData.name_of(Meta.selected_device), Global.C_CYAN)
	hud.announce("HAZARD: %s. %s" % [hazards.kind["name"], hazards.kind["text"]], hazards.kind["color"])

	for i in int(Meta.stat("startlevels")):
		offer_queue.append({"title": "BOOTSTRAP", "color": Global.C_GREEN, "luck": 0.5, "decrypt": false})
	if not offer_queue.is_empty():
		_open_next_offer.call_deferred(false)


func _layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	return n


func _exit_tree() -> void:
	Meta.unlatch_modes()
	if Global.game == self:
		Global.game = null
	Engine.time_scale = 1.0


func on_back() -> void:
	hud.back_pressed()


func luck_bonus() -> float:
	return (Meta.stat("luck") + player.luck_run) / 100.0 + player.combo_luck + (CHERRY_LUCK if player.items.has("cherrypick") else 0.0)


## Cards per offer. CHERRY PICK takes one away, never below two.
func offer_size() -> int:
	return maxi(2, choices - 1) if player.items.has("cherrypick") else choices


## Elite cache drop chance: rises with luck along the same curve as card rarity.
func cache_chance() -> float:
	return lerpf(CACHE_CHANCE, CACHE_CHANCE_MAX, Global.luck_curve(luck_bonus()))


func weapon_unlocked(id: String) -> bool:
	return Meta.weapon_owned(id) or (player != null and player.weapons.has(id))


## The chosen class (only if bought this cycle; the SINGLE THREAD challenge ignores classes): starting weapon and passive.
func _apply_class() -> void:
	var c: Dictionary = Meta.Classes.by_id(Meta.selected_class)
	if c["id"] == "" or not Meta.class_owned(c["id"]) or challenge.get("rule", "") == "laser_only":
		c = Meta.Classes.NONE
	else:
		cls = c
		player.class_id = c["id"]
		player.class_icon = c["icon"]    # the in-game avatar wears the class colour and icon, like the menu avatar
		player.class_color = c["color"]
	var wid: String = c["weapon"]
	var start_lv := 1 + int(Meta.stat("startlvl"))
	if wid.begins_with("evo_"):   # the secret classes start with an evolved weapon
		start_lv = Meta.Evolutions.START_LEVEL + int(Meta.stat("startlvl"))
		evolved.append(wid)
	if wid != "":
		player.add_weapon(wid, WEAPONS[wid]["script"], start_lv)
	if cls.is_empty():
		return
	var ps: Dictionary = cls["passive"].duplicate()
	var train := 1.0 + Meta.stat("cpass_" + String(cls["id"])) / 100.0   # CLASS TRAINING research scales every passive bonus
	for k in ps:
		ps[k] = ps[k] * train
	player.max_hp += ps.get("hp", 0.0)
	player.hp = player.max_hp
	player.regen += ps.get("regen", 0.0)
	player.crit_chance += ps.get("crit", 0.0)
	player.crit_mult += ps.get("critdmg", 0.0)
	player.area_mult += ps.get("area", 0.0)
	player.duration_mult += ps.get("duration", 0.0)
	player.dodge = minf(player.dodge + ps.get("dodge", 0.0), player.DODGE_CAP)
	player.xp_mult += ps.get("xp", 0.0)
	player.luck_run += ps.get("luck", 0.0)
	if ps.has("speed"):
		player.add_bonus("speed", ps["speed"])


## Cooldown length of the ability after the HOT SWAP stat (cards plus research, capped).
func ability_cd_len() -> float:
	return float(abil["cd"]) * (1.0 - minf(player.abilcd, ABILCD_CAP) / 100.0)


## Weapons cannot aim through walls: true when nothing solid is between the point and the threat.
func can_hit(from: Vector2, e) -> bool:
	return arena == null or arena.has_los(from, e.global_position)


func ability_frac() -> float:
	if abil["cd"] <= 0.0:
		return 0.0 if charges > 0 else 1.0
	return clampf(ability_cd / maxf(0.1, ability_cd_len()), 0.0, 1.0)


## Adds a stored ability charge (a charge lets you use the ability again without waiting for its cooldown).
func add_charge(n := 1) -> void:
	if charges >= max_charges:
		return
	charges = mini(max_charges, charges + n)
	hud.announce("+1 ABILITY CHARGE (%d)" % charges, abil["color"])


func use_ability() -> void:
	if not player.alive or run_over or hud.busy:
		return
	if sweet_t >= SWEET_START and sweet_t <= SWEET_END and not sweet_done:
		sweet_done = true
		_run_ability(true)
		return
	if sweet_t >= 0.0:
		# while the ring runs, a tap outside the sweet spot (too early or too late) only spoils the SUPER window:
		# it never casts again or spends a charge, so an early tap can't burn a second cast by accident
		if not sweet_done:
			sweet_done = true
			hud.announce("SUPER MISSED", Color(0.7, 0.75, 0.82))
		Sfx.play("deny")
		return
	if abil["cd"] > 0.0 and ability_cd <= 0.0:
		ability_cd = ability_cd_len()
	elif charges > 0:
		charges -= 1
	else:
		Sfx.play("deny")
		return
	sweet_t = 0.0
	sweet_done = false
	_run_ability(false)


## Casts the ability. A super cast (second tap in the sweet spot) is a stronger second cast with extra invulnerability,
## half the cooldown back and a gold flash.
func _run_ability(sup: bool) -> void:
	var m := 1.5 if sup else 1.0
	var pos: Vector2 = player.global_position
	var cast_snd := "ab_" + str(abil["ability"])   # every ability has its own cast sound; the generic jingle is only the fallback
	if not Sfx.streams.has(cast_snd):
		cast_snd = "legendary" if sup else "levelup"
	var rail: bool = abil["ability"] == "railstrike"   # the railgun winds up first; the beam, impact and cast sound come after the delay
	if rail:
		Sfx.play("charge_rail_s" if sup else "charge_rail", 1.0, 0.0, 0.0)
		ring(pos, Global.C_GOLD if sup else abil["color"], 90.0, 0.8 if sup else 0.4, 3.0)
	else:
		Sfx.play(cast_snd, 0.92 if sup else 1.0, 0.0, 0.0)
	if sup:
		Sfx.play("ab_super", 1.0, -1.0, 0.0)
	hud.announce(("SUPER " if sup else "") + abil["ability_name"], Global.C_GOLD if sup else abil["color"])
	if rail:
		_rail_release(sup, m)
	else:
		_ability_impact(pos, Global.C_GOLD if sup else abil["color"], sup)
	match abil["ability"]:
		"restore":
			player.heal(player.max_hp * 0.3 * m)
			player.invuln = maxf(player.invuln, 1.5 * m)
			afx("heal", pos, abil["color"], 130.0 * m, 1.1, 4.0, 22 if sup else 14, sup)
			burst(pos, Color.WHITE, 8, 120.0, 3.0, 0.5)
		"overclock":
			if ability_active <= 0.0:
				player.add_bonus("haste", 50.0)
			if sup and overclock_extra <= 0.0:
				overclock_extra = 25.0
				player.add_bonus("haste", overclock_extra)
			ability_active = 6.0 * m
			afx("clock", pos, abil["color"], 190.0 * m, 0.7, 3.0)
		"lockdown":
			afx("lock", pos, abil["color"], 420.0 * m, 0.9, 3.0, 8, sup)
			for e in _all_enemies():
				if e.global_position.distance_to(pos) < 420.0 * m:
					e.slow(4.0 * m)
					e.take_damage((30.0 + 4.0 * elapsed / 60.0) * player.damage_mult * m)
		"phase":
			var dir: Vector2 = player.facing if player.facing.length() > 0.1 else Vector2.RIGHT
			var dash_to: Vector2 = player.global_position + dir.normalized() * 260.0 * m
			player.global_position = arena.clamp_to_bounds(dash_to, player.radius) if arena != null else dash_to   # a ghost dashes through walls, not off the map
			player.ghost_time = maxf(player.ghost_time, 1.5 * m)   # invisible: threats ignore it until it ends
			player.invuln = maxf(player.invuln, 1.5 * m)
			# afterimage trail along the dash, then a burst where you land
			var ph = afx("phase", pos, abil["color"], 0.0, 0.8, 3.0, 10, sup)
			if ph != null:
				ph.from = pos
				ph.to = player.global_position
		"deepscan":
			afx("scan", pos, abil["color"], 460.0 * m, 0.9, 3.0)
			for e in _all_enemies():
				e.status["shock"] = 8.0 * m
			ability_active = 8.0 * m
		"purge":
			_system_purge()
		"railstrike":
			pass   # fired by _rail_release after its wind-up
		"wildfire":
			var fire: float = (40.0 + 6.0 * elapsed / 60.0) * player.damage_mult * m
			for e in _all_enemies():
				if e.global_position.distance_to(pos) < 480.0 * m:
					var at: Vector2 = e.global_position
					e.take_damage(fire * 0.5)
					if is_instance_valid(e) and e.hp > 0.0:
						e.apply_status("burn", fire)
						if e.status.has("burn"):
							e.status["burn"] = maxf(e.status["burn"], 6.0 * m)
					burst(at, Color(1.0, 0.5, 0.1), 6, 160.0, 4.0, 0.5)
			afx("fire", pos, Color(1.0, 0.45, 0.1), 480.0 * m, 1.6, 4.0, 16, sup)
		"thunderstorm":
			storm_t = 6.0 * m
			storm_tick = 0.0
			storm_m = m
			ability_active = storm_t
			afx("storm", pos, Color(0.6, 0.9, 1.0), 520.0 * m, 1.4, 4.0, 16, sup)
		"deepfreeze":
			var chill: float = (25.0 + 3.0 * elapsed / 60.0) * player.damage_mult * m
			for e in _all_enemies():
				if e.global_position.distance_to(pos) < 450.0 * m:
					e.slow(3.0 * m)
					if not e.is_boss:
						e.apply_status("freeze", chill)
						if e.hp > 0.0 and e.status.has("freeze"):
							e.status["freeze"] = maxf(e.status["freeze"], 3.0 * m)
					if is_instance_valid(e) and e.hp > 0.0:
						e.take_damage(chill)
			hud.flash(Color(0.7, 0.92, 1.0), 0.4)
			afx("ice", pos, Color(0.85, 0.97, 1.0), 450.0 * m, 1.8, 4.0, 16, sup)
		"pause":
			time_stop = 4.0 * m
			afx("pause", pos, Color(0.75, 0.9, 1.0), 260.0 * m, 1.0, 4.0, 12, sup)   # the moment freezing: rolling rings, a pause glyph
			ability_active = time_stop
			if is_instance_valid(_pause_clock):   # a SUPER PAUSE clock takes over from the smaller one still running
				_pause_clock.dismiss()
			var clk = TimeClockScript.new()   # the persistent bronze clockwork with a seconds-left readout for the whole freeze
			clk.life = time_stop
			clk.radius = 170.0 * m
			clk.target = player
			clk.position = pos + Vector2(0, -20)
			ability_fx_layer.add_child(clk)
			_pause_clock = clk
			hud.flash(Color(0.75, 0.9, 1.0), 0.5)
	if sup:
		player.invuln = maxf(player.invuln, 2.0)
		ability_cd = maxf(0.0, ability_cd - ability_cd_len() * 0.5)
		hud.flash(Global.C_GOLD, 0.5)
		Input.vibrate_handheld(60)
		super_casts += 1


## Railgunner's wind-up: waits 0.4s (0.8s for a SUPER cast), then fires at the player's current position and facing.
func _rail_release(sup: bool, m: float) -> void:
	await get_tree().create_timer(0.8 if sup else 0.4, true, false, false).timeout
	if run_over or not player.alive or not is_inside_tree():
		return
	var pos: Vector2 = player.global_position
	Sfx.play("ab_railstrike", 0.92 if sup else 1.0, 0.0, 0.0)
	_ability_impact(pos, Global.C_GOLD if sup else abil["color"], sup)
	_rail_strike(pos, m)


## The OOMPF at the moment an ability lands: a white-hot flash ring, a coloured shockwave, a spray of sparks, a thump,
## a hard camera kick and a brief hit-stop. A SUPER cast does all of it bigger.
func _ability_impact(pos: Vector2, col: Color, sup: bool) -> void:
	var m := 1.5 if sup else 1.0
	hud.flash(Color(col, 0.6), 0.25 if sup else 0.15)
	shake(1.0 if sup else 0.7)
	Sfx.play("impact_s" if sup else "impact", 1.0, -7.0, 0.0)   # under the ability's own cast sound
	slow_mo(0.15, 0.09 if sup else 0.06)


## RAIL STRIKE: one straight beam along the facing direction. Pierces walls and every threat on the line, always crits.
func _rail_strike(pos: Vector2, m: float) -> void:
	var dir: Vector2 = player.facing.normalized() if player.facing.length() > 0.1 else Vector2.RIGHT
	var length := 1400.0 * m
	var half_w := 45.0 * m
	var end := pos + dir * length
	var dmg: float = (90.0 + 14.0 * elapsed / 60.0) * player.damage_mult * player.crit_mult * m
	for e in _all_enemies():
		var rel: Vector2 = e.global_position - pos
		var along := rel.dot(dir)
		if along < 0.0 or along > length:
			continue
		if absf(rel.cross(dir)) > half_w + e.radius:
			continue
		e.take_damage(dmg, dir * 380.0, 2)
	var rf = afx("rail", pos, Color(1.0, 0.9, 0.4), 0.0, 1.1 if m > 1.0 else 0.9, 4.0, 10, m > 1.0)
	if rf != null:
		rf.from = pos
		rf.to = end
	shake(0.5)


## THUNDERSTORM: while it runs, a bolt hits a random threat near the player every 0.35s and shocks it.
func _tick_storm(delta: float) -> void:
	if storm_t <= 0.0:
		return
	storm_t -= delta
	storm_tick -= delta
	if storm_tick > 0.0:
		return
	storm_tick = 0.35
	var pos: Vector2 = player.global_position
	var near := []
	for e in _all_enemies():
		if e.global_position.distance_to(pos) < 560.0:
			near.append(e)
	if near.is_empty():
		return
	var e = near.pick_random()
	var at: Vector2 = e.global_position
	var bolt: float = (45.0 + 6.0 * elapsed / 60.0) * player.damage_mult * storm_m
	Sfx.play("thunder_bolt_%d" % (randi() % 3), randf_range(0.9, 1.1), -4.0, 0.0)
	e.take_damage(bolt)
	if is_instance_valid(e) and e.hp > 0.0:
		e.apply_status("shock", bolt)
	afx("strike", at, Color(0.6, 0.9, 1.0), 0.0, 0.8, 4.0, 8)


func _all_enemies() -> Array:
	var list := []
	for e in enemy_layer.get_children():
		if is_instance_valid(e) and e.has_method("slow"):
			list.append(e)
	if is_instance_valid(current_boss):
		list.append(current_boss)
	return list


## One shared list of the live threats per frame, built the first time a weapon, item or bolt asks (they all run after the threats
## have moved this frame, so the positions are exactly what each would have read). Replaces ~40 scripts each calling
## get_nodes_in_group("enemies") and reading e.global_position / e.radius on every threat, every frame.
var enemy_nodes: Array = []
var enemy_pos := PackedVector2Array()
var enemy_rad := PackedFloat64Array()
var _enemy_frame := -1


func refresh_enemies() -> void:
	var f := Engine.get_process_frames()
	if f == _enemy_frame:
		return
	_enemy_frame = f
	enemy_nodes = get_tree().get_nodes_in_group("enemies")
	var n := enemy_nodes.size()
	enemy_pos.resize(n)
	enemy_rad.resize(n)
	for i in n:
		var e = enemy_nodes[i]
		enemy_pos[i] = e.global_position
		enemy_rad[i] = e.radius


func _tick_ability(delta: float) -> void:
	if charges <= 0:   # the cooldown is frozen while stored charges are left: it only runs once they are used up
		ability_cd = maxf(0.0, ability_cd - delta)
	if sweet_t >= 0.0:
		sweet_t += delta
		if sweet_t > SWEET_LEN:
			sweet_t = -1.0
	var bt = hud.ability_button
	bt.frac = ability_frac()
	bt.active = ability_active > 0.0
	bt.charges = charges
	bt.sweet = -1.0 if (sweet_t < 0.0 or sweet_done) else sweet_t / SWEET_LEN
	bt.sweet_hot = sweet_t >= SWEET_START and sweet_t <= SWEET_END and not sweet_done
	time_stop = maxf(0.0, time_stop - delta)
	_tick_storm(delta)
	if ability_active > 0.0:
		ability_active -= delta
		if ability_active <= 0.0 and abil["ability"] == "overclock":
			player.add_bonus("haste", -50.0 - overclock_extra)
			overclock_extra = 0.0
	_set_aura(ability_active > 0.0)


func data_earned() -> float:
	return raw_data * Meta.data_mult()


func _make_fog() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5   # above the arena, below the HUD (layer 10)
	add_child(cl)
	fog_rect = ColorRect.new()
	fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec2 center = vec2(0.0);
uniform float radius = 190.0;
uniform float soft = 50.0;
void fragment() {
	float d = distance(FRAGCOORD.xy, center);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(radius - soft, radius, d));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	fog_rect.material = mat
	cl.add_child(fog_rect)


func _update_fog() -> void:
	if fog_rect == null or player == null:
		return
	var vp := get_viewport()
	var xf: Transform2D = vp.get_canvas_transform()
	var scale: float = xf.get_scale().x
	var screen: Vector2 = xf * player.global_position   # canvas pixels -> window pixels
	var win: Vector2 = vp.get_visible_rect().size
	var px: Vector2 = DisplayServer.window_get_size() if win.x <= 0.0 else Vector2(DisplayServer.window_get_size()) / win
	var m := fog_rect.material as ShaderMaterial
	m.set_shader_parameter("center", screen * px)
	m.set_shader_parameter("radius", FOG_BASE * player.area() * scale * px.x)
	m.set_shader_parameter("soft", 50.0 * scale * px.x)


func _process(delta: float) -> void:
	pending_drops = 0
	queue_redraw()
	_update_fog()
	if not player.alive or run_over:
		return
	elapsed += delta * (Meta.SPEED_TIME if Meta.run_speed() else 1.0)
	real_elapsed += delta
	challenge_clock += delta
	if challenge_clock >= 1.0:
		challenge_clock = 0.0
		_check_challenge()
		_check_evolution_ready()
	raw_data += delta * 0.5
	_tick_ability(delta)

	if combo_hold > 0.0:
		combo_hold -= delta
	elif combo > 0.0:
		combo -= combo * (COMBO_DECAY + combo / COMBO_SOFT) * delta
		if combo < 0.5:
			combo = 0.0
	combo_announce_cd = maxf(0.0, combo_announce_cd - delta)
	_update_combo(delta)
	pickup_chain_timer -= delta
	if pickup_chain_timer <= 0.0:
		pickup_chain = 0

	var minutes := elapsed / 60.0
	var boss_alive := is_instance_valid(current_boss)

	if time_stop > 0.0:
		return   # PAUSE: no new threats, elites or swarms while time is stopped
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var spawn_mult := 1.0 + Meta.THREAT_SPAWN * Meta.run_threat()
		var batch := 1 + int(minutes * 2.0 * spawn_mult)
		if boss_alive:
			batch = maxi(1, batch / 2)
		for i in batch:
			var pk := _pick_kind(minutes)
			var pack := [_spawn_enemy(pk, minutes)] if pk != "mite" else _spawn_mite_pack(minutes)
			for ne in pack:
				if ne != null and randf() < modifier_chance():
					ne.apply_affix(EnemyScript.AFFIXES.pick_random())
					Meta.codex_see("affix:" + ne.affix)
		spawn_timer = maxf(0.22, 0.85 - minutes * 0.09) / sqrt(spawn_mult)

	var step := _roster_step(minutes)
	if step > roster_announced:
		roster_announced = step
		var live := live_kinds(minutes)
		var arrived: String = live[-1][0]
		var label := "THREAT RETURNS" if announced_kinds.has(arrived) else "NEW THREAT"
		announced_kinds[arrived] = true
		hud.announce("%s: %s" % [label, EnemyScript.NAMES[arrived]], Global.C_ORANGE)
		Sfx.announce("incoming_new_enemy")

	if not in_room:
		elite_timer -= delta
	if elite_timer <= 0.0 and not in_room:
		# late game: fewer, rarer elites so caches (and the charges and offers they bring) do not pile up
		elite_timer = 60.0 if minutes < 8.0 else (80.0 if minutes < 14.0 else 100.0)
		spawn_elite_near(null)
		hud.announce("! ELITE THREAT DETECTED !", Global.C_GOLD)
		if not Sfx.announce("incoming_elite"):
			Sfx.play("alarm")

	if not in_room:
		swarm_timer -= delta
	if swarm_timer <= 0.0 and not in_room:
		swarm_timer = maxf(30.0, 55.0 - swarm_wave * 3.0)
		_spawn_swarm(minutes)

	if overtime:
		hud.set_overtime(elapsed - overtime_start, Global.overtime_dmg_mult(minutes))
		if not boss_alive and boss_warning < 0.0 and elapsed >= next_ot_boss - 3.0:
			boss_warning = 3.0
			ot_boss_def = BossData.random_mid()
			hud.boss_warning(ot_boss_def["name"], false)
			if not Sfx.announce("warning_incoming_boss"):
				Sfx.play("boss")
			shake(0.4)

	# bosses
	if internet and not overtime and not boss_alive and boss_warning < 0.0 and elapsed >= BOSS_TIMES[BOSS_TIMES.size() - 1]:
		_start_internet_overtime()
	if next_boss < BOSS_TIMES.size() - (1 if internet else 0) and not boss_alive and boss_warning < 0.0 and elapsed >= BOSS_TIMES[next_boss] - 3.0:
		boss_warning = 3.0
		hud.boss_warning(boss_lineup[next_boss]["name"], next_boss == 3)
		if not Sfx.announce("warning_incoming_boss"):
			Sfx.play("boss_final" if next_boss == 3 and Sfx.streams.has("boss_final") else "boss")
		shake(0.4)
	if boss_warning >= 0.0:
		boss_warning -= delta
		if boss_warning < 0.0:
			if overtime:
				if ot_boss_def.is_empty():
					ot_boss_def = BossData.random_mid()
				_spawn_boss_def(ot_boss_def, 2, minutes).overtime = true
				ot_boss_def = {}
				next_ot_boss = elapsed + OT_BOSS_EVERY
			else:
				_spawn_boss(next_boss, minutes)
				next_boss += 1

	frame += 1
	_separate_enemies()
	hud.update_stats(player, elapsed, kills, data_earned(), current_boss)


# ---------- spawning ----------

func _in_pool(kind: String) -> bool:
	var tier := Meta.run_tier()
	return Meta.run_internet() or tier >= DEVICE_POOLS.size() or DEVICE_POOLS[tier].has(kind)


## Chance that a regular enemy spawns with a modifier: later devices and a higher threat level make it likelier.
func modifier_chance() -> float:
	var tier := Meta.run_tier()
	var c := MOD_CHANCE_DEVICE * maxf(0.0, tier - 1.0) + MOD_CHANCE_THREAT * Meta.run_threat()
	return clampf(c, 0.0, MOD_CHANCE_MAX)


func _roster() -> Array:
	if roster_order.is_empty():
		for row in SPAWN_TABLE:
			if _in_pool(row[0]):
				roster_order.append(row)
		for i in mini(ROSTER_START, roster_order.size()):
			announced_kinds[roster_order[i][0]] = true
	return roster_order


func _roster_step(m: float) -> int:
	return int(m / ROSTER_STEP)


## Types spawning right now as [kind, weight, minute it arrived], oldest first (the newest arrival is last).
func live_kinds(m: float) -> Array:
	var order := _roster()
	var newest := ROSTER_START - 1 + _roster_step(m)
	var out := []
	for i in range(maxi(0, newest - ROSTER_LIVE + 1), newest + 1):
		var row: Array = order[i % order.size()]
		var since := 0.0 if i < ROSTER_START else (i - ROSTER_START + 1) * ROSTER_STEP
		out.append([row[0], row[2], since])
	return out


func _pick_kind(m: float) -> String:
	var total := 0.0
	var options := []
	for row in live_kinds(m):
		var w: float = row[1] * (1.0 + maxf(0.0, m - row[2]) * 0.15)
		options.append([row[0], w])
		total += w
	var roll := randf() * total
	for o in options:
		roll -= o[1]
		if roll <= 0.0:
			return o[0]
	return "bug"


func max_enemies() -> int:
	return MAX_ENEMIES


## Distance just beyond the edge of the screen (works for any phone aspect ratio).
func offscreen_radius() -> float:
	return get_viewport_rect().size.length() / 2.0 + 70.0


func _spawn_enemy(kind: String, minutes: float, elite := false, pos = null, swarm := false):
	var cap := max_enemies() + (SWARM_EXTRA if swarm else 0) + (ELITE_EXTRA if elite else 0)
	if enemy_layer.get_child_count() >= cap:
		return null
	if in_room and enemy_layer.get_child_count() >= 26 and not elite:
		return null   # boss rooms are small: keep the adds manageable
	var e = EnemyScript.new()
	e.setup(kind, minutes, elite)
	Meta.codex_see("enemy:" + kind)
	if elite:
		Meta.codex_see("affix:" + e.affix)
	if pos == null:
		var r := offscreen_radius()
		if arena != null:
			e.position = arena.random_open_point(player.position, r, r + 100.0)
		else:
			e.position = player.position + Vector2.from_angle(randf() * TAU) * randf_range(r, r + 100.0)
	else:
		e.position = arena.nearest_open(pos) if arena != null else pos
	enemy_layer.add_child(e)
	return e


## Mites never come alone: a pack of MITE_PACK_MIN to MITE_PACK_MAX spawns together around one point just off screen.
func _spawn_mite_pack(minutes: float) -> Array:
	var r := offscreen_radius()
	var center: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * (r + 50.0)
	if arena != null:
		center = arena.random_open_point(player.position, r, r + 100.0)
	return _mite_pack_at(center, minutes, randi_range(MITE_PACK_MIN, MITE_PACK_MAX))


## Spawns n mites around center. Only the first one checks the enemy cap, so a pack is never cut short.
func _mite_pack_at(center: Vector2, minutes: float, n: int) -> Array:
	var pack := []
	for i in n:
		var e = _spawn_enemy("mite", minutes, false, center + Vector2.from_angle(TAU * i / n + randf() * 0.5) * randf_range(10.0, 34.0), i > 0)
		if e == null:
			break
		pack.append(e)
	return pack


func spawn_elite_near(pos) -> void:
	var m := elapsed / 60.0
	var kinds := []
	for row in live_kinds(m):
		if row[0] != "bug":
			kinds.append(row[0])
	if kinds.is_empty():
		kinds = [live_kinds(m)[-1][0]]
	var e = _spawn_enemy(kinds[-1] if randf() < 0.5 else kinds.pick_random(), m, true, pos)
	if e:
		ring(e.position, Global.C_GOLD, 120.0, 0.6, 6.0)
		if e.kind == "mite":
			_mite_pack_at(e.position, m, MITE_PACK_MIN - 1)   # an elite mite brings its pack along


## Boss adds are tagged so a summoner boss cannot flood the enemy cap: at most BOSS_ADD_CAP of them alive at once.
func summon(kind: String, pos: Vector2, count: int, spread: float) -> void:
	var alive := 0
	for c in enemy_layer.get_children():
		if c.has_meta("boss_add"):
			alive += 1
	count = mini(count, BOSS_ADD_CAP - alive)
	for i in count:
		var p := pos + Vector2.from_angle(TAU * i / count + randf()) * spread
		var e = _spawn_enemy(kind, elapsed / 60.0, false, p)
		if e != null:
			e.set_meta("boss_add", true)
	burst(pos, Global.C_MAGENTA, 10, 180.0)


func _spawn_swarm(minutes: float) -> void:
	swarm_wave += 1
	var w := swarm_wave
	var entry: Array = SWARM_WAVES[mini(w - 1, SWARM_WAVES.size() - 1)]
	var kinds := entry.slice(1)
	var formation: String = FORMATIONS[0] if w == 1 else FORMATIONS.pick_random()
	# size grows every wave; members get tougher every wave on top of normal time scaling
	var count := 30 + w * 14 + int(minutes * 4.0)
	var toughness := 1.0 + 0.18 * (w - 1)
	var elites := clampi((w - 2) / 2, 0, SWARM_ELITE_CAP)
	var extra := ("  +%d ELITE%s" % [elites, "S" if elites > 1 else ""]) if elites > 0 else ""
	hud.announce("SWARM WAVE %d: %s  [%s]%s" % [w, entry[0], formation, extra], Global.C_MAGENTA)
	if not Sfx.announce("incoming_swarm"):
		Sfx.play("alarm", 1.2)
	shake(0.25)

	var center: Vector2 = player.position
	var r := minf(offscreen_radius() - 40.0, 620.0)
	var points := []
	match formation:
		"RING":
			for i in count:
				points.append(center + Vector2.from_angle(TAU * i / count) * r)
		"DOUBLE RING":
			for i in count:
				var outer := i % 2 == 0
				points.append(center + Vector2.from_angle(TAU * i / count) * (r if outer else r * 0.72))
		"PINCER":
			var a := randf() * TAU
			for i in count:
				var side := 1.0 if i % 2 == 0 else -1.0
				var spread := (randf() - 0.5) * 1.3
				points.append(center + Vector2.from_angle(a + spread) * r * side + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
		"SPIRAL":
			for i in count:
				var k := float(i) / count
				points.append(center + Vector2.from_angle(k * TAU * 2.0) * lerpf(r * 1.35, r * 0.75, k))
		"WALL":
			var dir := Vector2.from_angle(randf() * TAU)
			var side_v := dir.orthogonal()
			for i in count:
				var row := i % 3
				var lane := (float(i / 3) / maxf(1.0, count / 3.0) - 0.5) * r * 2.6
				points.append(center + dir * (r + row * 40.0) + side_v * lane)

	for i in points.size():
		var kind: String = kinds[i % kinds.size()]
		var e = _spawn_enemy(kind, minutes, false, points[i], true)
		if e:
			_tag_swarm(e, w)
			e.max_hp *= toughness
			e.hp = e.max_hp
			e.damage *= 1.0 + 0.08 * (w - 1)
			e.speed *= 1.0 + 0.03 * (w - 1)
	for i in elites:
		var p: Vector2 = points[(i * points.size()) / maxi(1, elites)] if not points.is_empty() else center + Vector2(r, 0)
		var el = _spawn_enemy(kinds[0] if kinds[0] != "bug" else "worm", minutes, true, p, true)
		if el:
			_tag_swarm(el, w)
			el.max_hp *= toughness
			el.hp = el.max_hp


func _spawn_boss(index: int, minutes: float) -> void:
	_spawn_boss_def(boss_lineup[index], index, minutes)


## Overtime bosses reuse the last boss slot's stats (slot 2); time scaling takes it from there.
func _spawn_boss_def(def: Dictionary, slot: int, minutes: float):
	var b = BossScript.new()
	b.setup_boss(def, slot, minutes)
	Meta.codex_see("boss:" + def["id"])
	# half of the player's damage bonus is added to boss health so stacked builds cannot trivialize bosses
	b.max_hp *= 1.0 + 0.5 * maxf(0.0, player.damage_mult - 1.0)
	b.hp = b.max_hp
	if arena != null and room_arena != null and slot == 3:   # only final bosses get a boss room
		_enter_boss_room()
		b.position = arena.random_open_point(player.position, 450.0, 650.0)
	else:
		b.position = player.position + Vector2.from_angle(randf() * TAU) * 480.0
		if arena != null:
			b.position = arena.nearest_open(b.position)
	enemy_layer.add_child(b)
	current_boss = b
	if slot == 3:
		Music.play_boss()   # the final boss fight has its own track
	ring(b.position, b.color, 400.0, 1.0, 14.0)
	burst(b.position, b.color, 80, 500.0, 6.0, 1.0)
	shake(0.8)
	Sfx.play("explode", 0.5)
	return b


## BOSS ROOM: the field is cleared and the player and boss fight in the device's sealed side arena.
func _enter_boss_room() -> void:
	room_return = player.global_position
	in_room = true
	for e in enemy_layer.get_children():
		e.queue_free()
	for bl in bullet_layer.get_children():
		bl.queue_free()
	main_arena.set_active(false)
	room_arena.set_active(true)
	arena = room_arena
	player.global_position = arena.start
	player.invuln = maxf(player.invuln, 1.5)
	_arena_changed()
	hud.announce("BOSS ROOM", Global.C_RED, true)


func _leave_boss_room() -> void:
	if not in_room:
		return
	in_room = false
	var back: Vector2 = main_arena.nearest_open(room_return)
	for p in pickup_layer.get_children():   # leftover drops come along
		if room_arena.bounds.has_point(p.position):
			p.position = back + Vector2(randf_range(-70, 70), randf_range(-70, 70))
	for e in enemy_layer.get_children():
		e.queue_free()
	for bl in bullet_layer.get_children():
		bl.queue_free()
	room_arena.set_active(false)
	main_arena.set_active(true)
	arena = main_arena
	player.global_position = back
	player.invuln = maxf(player.invuln, 1.5)
	_arena_changed()
	ring(back, Global.C_CYAN, 300.0, 0.6, 8.0)


func _arena_changed() -> void:
	camera.limit_left = int(arena.bounds.position.x)
	camera.limit_top = int(arena.bounds.position.y)
	camera.limit_right = int(arena.bounds.end.x)
	camera.limit_bottom = int(arena.bounds.end.y)
	camera.reset_smoothing()
	hud.setup_map(arena, player)
	if challenge.get("rule", "") == "incognito":
		hud.minimap.visible = false


func slam(pos: Vector2, radius: float, delay: float, dmg: float, col: Color) -> void:
	var s = TelegraphScript.new()
	s.position = pos
	s.radius = radius
	s.delay = delay
	s.damage = dmg
	s.color = col
	fx_layer.add_child(s)


## Returns the bullet (null when there are too many on screen).
func enemy_shot(pos: Vector2, vel: Vector2, dmg: float, col: Color, heavy := false):
	if bullet_layer.get_child_count() > 350:
		return null
	var b = BulletScript.new()
	b.position = pos
	b.velocity = vel
	b.damage = dmg
	b.color = col
	b.heavy = heavy
	bullet_layer.add_child(b)
	return b


func _separate_enemies() -> void:
	var cell := 40.0
	var grid := {}
	var enemies := enemy_layer.get_children()
	for e in enemies:
		var key := Vector2i(floori(e.position.x / cell), floori(e.position.y / cell))
		if grid.has(key):
			grid[key].append(e)
		else:
			grid[key] = [e]
	for e in enemies:
		if e.is_boss:
			continue
		var k := Vector2i(floori(e.position.x / cell), floori(e.position.y / cell))
		var push := Vector2.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var arr = grid.get(k + Vector2i(dx, dy))
				if arr == null:
					continue
				for o in arr:
					if o == e:
						continue
					var d: Vector2 = e.position - o.position
					var min_d: float = e.radius + o.radius
					var l2 := d.length_squared()
					if l2 < min_d * min_d and l2 > 0.01:
						var l := sqrt(l2)
						push += d / l * (min_d - l)
		e.position += push.limit_length(6.0) * 0.5


# ---------- combat callbacks ----------

func on_enemy_killed(e) -> void:
	kills += 1
	if e.status.has("shock"):
		shock_kills += 1
	if e.status.has("freeze"):
		freeze_kills += 1
	for k in e.status:   # status codex entries count threats that died under the effect
		Meta.codex_kill("status:" + k)
	if CodexData.is_weapon(e.kill_src):   # the weapon that landed the last direct hit (or the DoT it left) gets the kill
		Meta.codex_kill("weapon:" + e.kill_src)
	if not e.is_boss:
		Meta.codex_kill("enemy:" + e.kind)
		if e.affix != "":
			Meta.codex_kill("affix:" + e.affix)
	_item_event("on_kill", e)
	if e.has_meta("swarm"):
		_swarm_enemy_down(e)
	combo += 1.0
	if player.items.has("holdbuffer"):
		combo_hold = HOLD_BUFFER_TIME
	best_combo = maxi(best_combo, int(combo))
	hud.pop_combo()

	var pos: Vector2 = e.global_position
	raw_data += e.xp_value * 0.25 * (1.0 + combo_data)
	burst(pos, e.color, 8 + int(e.radius / 2.0), 240.0, 4.0, 0.45)
	Sfx.play("kill", randf_range(0.85, 1.25), -6.0, 0.05)

	if e.is_boss:
		_on_boss_killed(e)
		return
	if e.elite:
		var bonus: float = (15.0 + 5.0 * elapsed / 60.0) * (1.0 + Meta.stat("elitedata") / 100.0)
		raw_data += bonus
		burst(pos, Global.C_GOLD, 60, 420.0, 6.0, 1.0)
		ring(pos, Global.C_GOLD, 220.0, 0.6, 8.0)
		shake(0.45)
		Sfx.play("explode")
		float_text(pos + Vector2(0, -40), "+%d DATA" % int(bonus * Meta.data_mult()), Global.C_GOLD, 30, 1.4)
		if randf() < cache_chance():
			_drop("cache", pos, 1)
		if randf() < PURGE_ELITE_CHANCE:
			_drop_purge(pos + Vector2(14, 0))
		if e.affix == "VOLATILE":
			_volatile_blast(pos, e.damage * 1.5)
	elif e.kind == "ransom":
		ring(pos, e.color, 90.0, 0.35, 5.0)
		shake(0.12)
	if e.affix == "VOLATILE" and not e.elite:
		_volatile_blast(pos, e.damage * 1.5)
	if e.kind == "adware":
		for i in 2:
			_spawn_enemy("popup", elapsed / 60.0, false, pos + Vector2.from_angle(randf() * TAU) * 14.0)

	_drop_xp(pos, e.xp_value)
	var r := randf()
	if r < 0.0025 * (1.0 + Meta.stat("healdrop") / 100.0):
		_drop("heal", pos + Vector2(10, 0), 1)
	elif randf() < 0.0012 * (1.0 + Meta.stat("magdrop") / 100.0):
		_drop("magnet", pos + Vector2(10, 0), 1)
	if randf() < PURGE_CHANCE:
		_drop_purge(pos + Vector2(-10, 0))


func _volatile_blast(pos: Vector2, dmg: float) -> void:
	ring(pos, Color(1.0, 0.5, 0.1), 130.0, 0.6, 6.0)
	await get_tree().create_timer(0.6, false).timeout
	if not is_inside_tree():
		return
	ring(pos, Color(1.0, 0.4, 0.1), 130.0, 0.3, 14.0)
	burst(pos, Color(1.0, 0.5, 0.1), 40, 400.0, 6.0, 0.6)
	Sfx.play("explode", 1.2)
	if player.alive and player.position.distance_to(pos) < 130.0:
		player.take_damage(dmg)


func _on_boss_killed(b) -> void:
	Meta.codex_kill("boss:" + b.boss_id)
	if b.overtime:
		overtime_bosses += 1
	else:
		bosses_defeated += 1
	current_boss = null
	hud.boss_defeated()
	var pos: Vector2 = b.global_position
	var bonus: float = 250.0 * (b.boss_index + 1) * (1.0 + Meta.stat("bossdata") / 100.0)
	raw_data += bonus
	hud.announce("%s DELETED" % b.display_name, Global.C_GOLD, true)
	hud.flash(Color.WHITE, 0.7)
	float_text(pos + Vector2(0, -70), "+%d DATA" % int(bonus * Meta.data_mult()), Global.C_GOLD, 40, 2.0)
	shake(1.0)
	Sfx.play("boss_defeat", 1.0, 0.0, 0.0)
	Sfx.announce("boss_defeated", 0.9)
	for i in 4:
		burst(pos + Vector2.from_angle(TAU * i / 4.0) * 40.0, [b.color, Global.C_GOLD, Color.WHITE, Global.C_CYAN][i], 60, 600.0, 7.0, 1.4)
	ring(pos, Global.C_GOLD, 700.0, 1.2, 16.0)
	ring(pos, b.color, 450.0, 0.9, 10.0)
	for i in 30:
		_drop_xp(pos + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 120.0), 6 + b.boss_index * 4)
	_drop("cache", pos, 1)
	for bl in bullet_layer.get_children():
		bl.queue_free()
	slow_mo(0.25, 1.0)
	camera.push_in(0.12, 1.6)
	if in_room:
		get_tree().create_timer(2.2).timeout.connect(_leave_boss_room)
	if b.boss_index == 3:
		_on_victory()


func _tag_swarm(e, wave: int) -> void:
	e.set_meta("swarm", wave)
	swarm_alive[wave] = swarm_alive.get(wave, 0) + 1


## A threat that leaves without being killed (a mite after its latch): no kill, no drops, but it still counts toward clearing its swarm.
func on_enemy_vanished(e) -> void:
	burst(e.global_position, e.color, 6, 160.0, 3.0, 0.3)
	if e.has_meta("swarm"):
		_swarm_enemy_down(e)


func _swarm_enemy_down(e) -> void:
	var wave: int = e.get_meta("swarm")
	swarm_alive[wave] = swarm_alive.get(wave, 1) - 1
	if swarm_alive[wave] <= 0:
		swarm_alive.erase(wave)
		if not purging:   # a Purge that wipes a swarm does not hand out another Purge
			hud.announce("SWARM CLEARED", Global.C_GREEN)
			Sfx.announce("swarm_defeated")
			if randf() < 0.5:
				_drop_purge(e.global_position)


func _drop_purge(pos: Vector2) -> void:
	_drop("purge", pos, 1)
	ifx("nova", pos, Global.C_GOLD, 80.0, 0.6, 3.0)
	float_text(pos + Vector2(0, -26), "PURGE", Global.C_GOLD, 28, 1.2)
	Sfx.play("pk_purge", 1.0, -6.0, 0.0)


func _drop_xp(pos: Vector2, value: int) -> void:
	if get_tree().get_nodes_in_group("pickups").size() + pending_drops >= Meta.MAX_PICKUPS:
		var best = null   # map is full: fold this XP into the nearest gem still lying around
		var best_d := INF
		for g in get_tree().get_nodes_in_group("gems"):
			if g.is_queued_for_deletion():
				continue
			var d: float = g.position.distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = g
		if best != null:
			best.value += value
			return
	_drop("xp", pos, value)


func _drop(kind: String, pos: Vector2, value: int) -> void:
	var p = PickupScript.new()
	p.kind = kind
	p.value = value
	p.position = arena.nearest_open(pos) if arena != null and arena.point_blocked(pos) else pos   # never inside a wall
	pickup_layer.call_deferred("add_child", p)
	pending_drops += 1


func on_pickup(p) -> void:
	match p.kind:
		"xp":
			pickup_chain += 1
			pickup_chain_timer = 0.5
			Sfx.play("pickup", 1.0 + minf(pickup_chain, 20) * 0.025, -5.0, 0.025)   # pitch climbs less, so long chains are not shrill
			player.add_xp(p.value)
		"heal":
			var patch: float = PATCH_HEAL * (1.0 + Meta.stat("patchheal") / 100.0)
			player.heal(patch)
			float_text(player.position + Vector2(0, -30), "+%d PATCHED" % roundi(patch * player.heal_mult), Global.C_GREEN, 30, 1.0)
			ifx("heal", player.position, Global.C_GREEN, 40.0, 0.8)
			Sfx.play("pk_heal", 1.0, -3.0, 0.0)
		"magnet":
			for g in get_tree().get_nodes_in_group("gems"):
				g.attracted = true
			hud.announce("DEFRAG: ALL DATA COLLECTED", Global.C_CYAN)
			ifx("suck", player.position, Global.C_CYAN, 260.0, 0.7)
			ring(player.position, Global.C_CYAN, 400.0, 0.6, 6.0)
			Sfx.play("pk_magnet", 1.0, -3.0, 0.0)
		"purge":
			_system_purge()
		"cache":
			ifx("cache", player.position, Global.C_GOLD, 46.0, 0.8)
			Sfx.play("pk_cache", 1.0, -3.0, 0.0)
			add_charge()
			queue_offer({"title": "CACHE DECRYPTED", "color": Global.C_GOLD, "luck": 0.8, "decrypt": true, "items": true})


func on_player_hurt() -> void:
	hits_taken += 1
	shake(0.4)
	hud.hurt_flash()
	burst(player.position, Global.C_RED, 12, 200.0)
	_item_event("on_hurt")
	combo *= 0.75   # getting hit costs a quarter of your combo


func on_player_revived() -> void:
	hud.announce("SYSTEM RESTORE", Global.C_GOLD, true)
	hud.flash(Global.C_GOLD, 0.6)
	Sfx.play("legendary", 1.0, 0.0, 0.0)
	ring(player.position, Global.C_GOLD, 500.0, 0.8, 12.0)
	for e in enemy_layer.get_children():
		if not e.is_boss and e.position.distance_to(player.position) < 500.0:
			e.take_damage(e.hp + 1.0, (e.position - player.position).normalized() * 400.0)
	for bl in bullet_layer.get_children():
		bl.queue_free()


# ---------- effects API ----------

func burst(pos: Vector2, color: Color, count := 10, speed := 220.0, size := 4.0, life := 0.5) -> void:
	if fx_layer.get_child_count() > 140:
		return
	var b = BurstScript.new()
	b.setup(count, color, speed, size, life)
	b.position = pos
	fx_layer.add_child(b)


var live_rings := 0


func ring(pos: Vector2, color: Color, radius := 120.0, life := 0.4, width := 6.0) -> void:
	if live_rings >= 12:
		return
	live_rings += 1
	var r = RingScript.new()
	r.color = color
	r.max_radius = radius
	r.life = life
	r.width = width
	r.position = pos
	r.tree_exited.connect(func(): live_rings -= 1)
	fx_layer.add_child(r)


## Pixel-snapped ability FX (see fx/ability_fx.gd). Skipped when the fx layer is already crowded; returns the node or null.
func afx(kind: String, pos: Vector2, color: Color, radius := 200.0, life := 0.5, size := 4.0, count := 16, sup := false):
	if ability_fx_layer.get_child_count() > 140:
		return null
	var f = AbilityFxScript.new()
	f.kind = kind
	f.color = color
	f.radius = radius
	f.life = life
	f.size = size
	f.count = count
	f.sup = sup
	f.position = pos
	ability_fx_layer.add_child(f)
	return f


const ItemFxScript = preload("res://scripts/fx/item_fx.gd")


## Pixel-snapped item / pickup FX (see fx/item_fx.gd). Skipped when the layer is crowded; returns the node or null.
func ifx(kind: String, pos: Vector2, color: Color, radius := 160.0, life := 0.5, size := 3.0):
	if ability_fx_layer.get_child_count() > 140:
		return null
	var f = ItemFxScript.new()
	f.kind = kind
	f.color = color
	f.radius = radius
	f.life = life
	f.size = size
	f.position = pos
	ability_fx_layer.add_child(f)
	return f


var _aura: Node2D = null
var _pause_clock: Node2D = null


## A small aura on the player while OVERCLOCK / DEEP SCAN / THUNDERSTORM is running.
func _set_aura(on: bool) -> void:
	if not on:
		if is_instance_valid(_aura):
			_aura.stop()
		_aura = null
		return
	if is_instance_valid(_aura):
		return
	var kind: String = {"overclock": "aura_overclock", "deepscan": "aura_scan", "thunderstorm": "aura_storm", "pause": "aura_pause"}.get(abil["ability"], "")
	if kind == "":
		return
	_aura = AbilityFxScript.new()
	_aura.kind = kind
	_aura.life = 1.0e9
	_aura.color = {"aura_overclock": Color(1.0, 0.75, 0.2), "aura_scan": abil["color"], "aura_storm": Color(0.6, 0.9, 1.0), "aura_pause": Color(0.75, 0.9, 1.0)}[kind]
	_aura.target = player
	_aura.position = player.global_position
	ability_fx_layer.add_child(_aura)


func lightning(points: Array, color: Color, style := "") -> void:
	var l = LightningScript.new()
	l.color = color
	l.style = style
	if style == "tesla":
		l.life = 0.32
	l.setup(points)
	fx_layer.add_child(l)


func float_text(pos: Vector2, text: String, color: Color, size := 24, life := 0.7) -> void:
	if text_layer.get_child_count() > 36:
		return
	var f = TextScript.new()
	f.text = text
	f.color = color
	f.font_size = size
	f.life = life
	f.position = pos
	text_layer.add_child(f)


func damage_number(pos: Vector2, amount: float, crit = 0) -> void:
	if not Global.damage_numbers or challenge.get("rule", "") == "incognito":
		return
	var tier := int(crit)
	if tier > 0:
		# more crit tiers = bigger, hotter numbers: gold, orange, magenta, white
		var cols := [Global.C_GOLD, Global.C_ORANGE, Global.C_MAGENTA, Color.WHITE]
		var k := mini(tier - 1, 3)
		float_text(pos, "%d%s" % [int(amount), "!".repeat(tier)], cols[k], 34 + 6 * k, 0.8 + 0.1 * k)
	elif text_layer.get_child_count() < 22:
		float_text(pos, str(int(amount)), Color(0.9, 0.95, 1.0), 24, 0.55)


func shake(amount: float) -> void:
	camera.add_trauma(amount)


func slow_mo(scale: float, real_seconds: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if player.alive:
		Engine.time_scale = 1.0


# ---------- upgrade offers ----------

func queue_offer(offer: Dictionary) -> void:
	if run_over:
		return
	offer_queue.append(offer)
	if not offer_open:
		_open_next_offer(true)


func _open_next_offer(with_intro: bool) -> void:
	while not offer_queue.is_empty() and _auto_offer(offer_queue[0]):
		offer_queue.pop_front()
	if offer_queue.is_empty():
		return
	offer_open = true
	hud.busy = true
	current_offer = offer_queue.pop_front()
	if with_intro:
		ring(player.position, current_offer["color"], 180.0, 0.5, 8.0)
		burst(player.position, current_offer["color"], 30, 300.0)
		ifx("levelup", player.position, current_offer["color"], 120.0, 0.7)
		Sfx.play("levelup")
		Engine.time_scale = 0.2
		await get_tree().create_timer(0.3, true, false, true).timeout
		Engine.time_scale = 1.0
		if not player.alive or run_over:
			return
	get_tree().paused = true
	hud.show_offer(current_offer["title"], current_offer["color"], _offer_options(current_offer), current_offer["decrypt"], rerolls)


## Bans are rarity-specific: banning a Rare Overclock leaves Common, Epic and Legendary Overclocks in the pool.
## Items have no rarity, so a banned item is gone entirely.
func _ban_key(opt: Dictionary) -> String:
	if opt.get("kind", "") == "item":
		return "item:" + opt["id"]
	return "%s:%d" % [opt["id"], opt["rarity"]["tier"]]


## A rarity roll for a card that skips banned rarities (null when all four are banned).
func _roll_unbanned(id: String, luck: float):
	for attempt in 24:
		var r: Dictionary = Global.roll_rarity(luck)
		if not banned.has("%s:%d" % [id, r["tier"]]):
			return r
	for r in Global.RARITIES:   # unlucky streak: take the most common rarity that is still allowed
		if not banned.has("%s:%d" % [id, r["tier"]]):
			return r
	return null


## Ban button on a card: the entry never appears again this run and the card is replaced by a fresh one.
func _on_ban(index: int) -> void:
	if bans_left <= 0 or index >= hud.current_options.size():
		return
	var opt: Dictionary = hud.current_options[index]
	if opt.get("kind", "") == "evolution":
		Sfx.play("deny")   # evolutions can never be banned
		return
	banned[_ban_key(opt)] = opt["title"] if opt.get("kind", "") == "item" else "%s %s" % [opt["rarity"]["name"], opt["title"]]
	bans_left -= 1
	Sfx.play("ban", 1.0, 0.0, 0.0)
	var shown := []
	for i in hud.current_options.size():
		if i != index:
			shown.append(hud.current_options[i]["id"])
	var rep = null   # a fresh card (new rarity roll, like a reroll) that is not already on screen
	for attempt in 6:
		for c in _offer_options(current_offer):
			if not shown.has(c["id"]):
				rep = c
				break
		if rep != null:
			break
	if rep != null:
		hud.replace_card(index, rep, bans_left)
	else:   # nothing left to replace it with: show the offer again with one card fewer
		var rest: Array = hud.current_options.duplicate()
		rest.remove_at(index)
		if rest.is_empty():
			rest = _build_options(0.0)   # last resort so the offer is never empty
		hud.show_offer(current_offer["title"], current_offer["color"], rest, false, rerolls)


func _on_reroll() -> void:
	if rerolls <= 0:
		return
	rerolls -= 1
	Sfx.play("card", 0.8)
	hud.show_offer(current_offer["title"], current_offer["color"], _offer_options(current_offer), false, rerolls)


func _build_options(luck: float) -> Array:
	var pool := []
	for id in WEAPONS:
		if not weapon_unlocked(id) or (challenge.get("rule", "") == "laser_only" and id != "laser"):
			continue
		if id.begins_with("evo_") and not player.weapons.has(id):
			continue   # an evolution only appears as its EVOLVE card, after the run itself meets the recipe (found ones are not offered as plain cards)
		if player.weapons.has(id):
			if player.weapons[id].level < max_weapon_level:
				pool.append(id)
		elif player.weapons.size() < max_weapons:
			pool.append(id)
	pool.append_array(STATS.keys())
	# caps: stop offering a stat once it is maxed so cards are never wasted
	if player.area_mult >= player.AREA_CAP - 0.005:
		pool.erase("area")   # stop offering AMPLIFIER once the cap is reached
	if player.armor >= ARMOR_CAP - 0.05:
		pool.erase("armor")
	if player.extra_pierce >= PIERCE_CARD_CAP:
		pool.erase("pierce")
	if player.extra_proj >= PROJ_CAP:
		pool.erase("proj")
	if player.knockback_mult >= player.KNOCKBACK_CAP - 0.01:
		pool.erase("knockback")
	if player.heal_mult >= player.HEAL_CAP - 0.01:
		pool.erase("healing")
	if player.lifesteal >= player.LIFESTEAL_CAP - 0.0001:
		pool.erase("lifesteal")
	if player.dodge >= player.DODGE_CAP - 0.001:
		pool.erase("dodge")
	for k in player.status_chance:
		if player.status_chance[k] >= player.STATUS_CAP - 0.01:
			pool.erase(k)
	if player.status_chance.values().max() <= 0.0 or player.status_potency >= player.STATUS_POTENCY_CAP - 0.01:
		pool.erase("potency")   # only offered once you have a status effect
	if player.proj_speed >= player.PROJ_SPEED_CAP - 0.01:
		pool.erase("projspeed")
	if not (player.weapons.has("laser") or player.weapons.has("backdoor")):
		pool.erase("projspeed")
	if abil.get("cd", 0.0) <= 0.0 or player.abilcd >= ABILCD_CAP - 0.01:
		pool.erase("abilcd")   # only offered with a class ability that has a cooldown
	# only offer item cooldown with an item that has a cooldown, and duration with something that lasts
	if player.items.is_empty() or player.pct["itemcd"] >= ITEMCD_CAP:
		pool.erase("itemcd")
	if not (player.weapons.has("quarantine") or player.weapons.has("mines") or DURATION_ITEMS.any(func(i): return player.items.has(i))):
		pool.erase("duration")
	pool.shuffle()

	var options := []
	for id in pool:
		if options.size() >= offer_size():
			break
		var rolled = _roll_unbanned(id, luck + luck_bonus())
		if rolled == null:
			continue   # every rarity of this card is banned
		var rarity: Dictionary = rolled
		var opt := {"id": id, "rarity": rarity, "icon": id}
		if WEAPONS.has(id):
			var w: Dictionary = WEAPONS[id]
			var gain: int = LEVEL_GAIN[rarity["tier"]]
			opt["title"] = w["title"]
			opt["desc"] = w["desc"]
			if player.weapons.has(id):
				var lv: int = player.weapons[id].level
				opt["to_level"] = mini(lv + gain, max_weapon_level)
				opt["level_text"] = "LV %d  >>  %d" % [lv, opt["to_level"]]
			else:
				opt["to_level"] = mini(gain, max_weapon_level)
				opt["level_text"] = "NEW!  LV %d" % opt["to_level"]
		else:
			var s: Dictionary = STATS[id]
			var amount: float = s["base"] * rarity["power"]
			if s.get("int", false):
				amount = roundf(amount)
			var amount_text := str(int(amount)) if s.get("int", false) else (("%.1f" % amount) if amount < 3.0 else str(int(round(amount))))
			opt["title"] = s["title"]
			opt["desc"] = s["desc"] % amount_text
			opt["amount"] = amount
			opt["level_text"] = "SYSTEM UPGRADE"
		options.append(opt)
	var evo := _ready_evolution()
	if not evo.is_empty() and randf() < EVO_CHANCE:
		options.insert(0, _evolution_option(evo))
		while options.size() > offer_size():
			options.pop_back()
	return options


# ---------- evolutions ----------

## A recipe whose conditions are met right now (both weapons at the required level, the item owned), or {}.
func _ready_evolution() -> Dictionary:
	if challenge.get("rule", "") == "laser_only":
		return {}
	for r in Meta.Evolutions.LIST:
		if player.weapons.has(r["id"]) or evolved.has(r["id"]) or banned.has(r["id"] + ":3"):
			continue
		var ok: bool = player.items.has(r["item"])
		for w in r["weapons"]:
			if not player.weapons.has(w) or player.weapons[w].level < r["lvl"]:
				ok = false
		if ok:
			return r
	return {}


func _evolution_option(r: Dictionary) -> Dictionary:
	var names := []
	for w in r["weapons"]:
		names.append(WEAPONS[w]["title"])
	return {"kind": "evolution", "id": r["id"], "recipe": r, "rarity": Global.EVOLUTION_RARITY, "icon": r["id"],
		"title": "EVOLVE: " + r["name"], "level_text": "%s + %s" % [names[0], names[1]],
		"desc": "%s (uses %s)" % [r["desc"], ItemData.ITEMS[r["item"]]["title"]]}


func _evolve(r: Dictionary) -> void:
	var lv := 1
	for w in r["weapons"]:
		if player.weapons.has(w):
			lv = maxi(lv, player.weapons[w].level)
			player.weapons[w].queue_free()
			player.weapons.erase(w)
	player.add_weapon(r["id"], WEAPONS[r["id"]]["script"], lv)
	evolved.append(r["id"])
	if Meta.discover_evolution(r["id"]):   # its ARSENAL node is granted: kept for good, but still only offered as an EVOLVE card once a run meets the recipe
		hud.announce("NEW EVOLUTION DISCOVERED: %s" % r["name"], r["color"], true)
	else:
		hud.announce("EVOLVED: %s" % r["name"], r["color"], true)
	ring(player.position, r["color"], 500.0, 0.8, 14.0)
	burst(player.position, r["color"], 60, 420.0, 5.0, 0.9)
	hud.flash(r["color"], 0.5)
	shake(0.4)
	Sfx.play("legendary", 1.0, 0.0, 0.0)


func _check_evolution_ready() -> void:
	var r := _ready_evolution()
	if not r.is_empty() and not evo_ready_told.has(r["id"]):
		evo_ready_told[r["id"]] = true
		hud.announce("EVOLUTION READY: %s" % r["name"], r["color"])


# ---------- special items ----------

func item_unlocked(_id: String) -> bool:
	return true   # prestige / challenge gating plugs in here later


# ---------- combos ----------

func combo_tier(n: int) -> int:
	var tier := 0
	for th in COMBO_TIERS:
		if n >= th:
			tier += 1
	return tier


## Total combo bonuses at combo n: the tier reward plus anything owned items add via combo_bonus(n).
func combo_bonuses(n: int) -> Dictionary:
	var out := {"xp": 0.0, "data": 0.0, "crit": 0.0, "luck": 0.0}
	var tier := combo_tier(n)
	if tier > 0:
		var r: Dictionary = COMBO_REWARDS[tier - 1]
		for k in out:
			out[k] += r[k]
	for v in player.items.values():
		if v is Node and is_instance_valid(v) and v.has_method("combo_bonus"):
			var extra: Dictionary = v.combo_bonus(n)
			for k in extra:
				if out.has(k):
					out[k] += extra[k]
	return out


func combo_text(b: Dictionary) -> String:
	var parts := []
	if b["xp"] > 0.0:
		parts.append("+%d%% XP" % int(round(b["xp"] * 100.0)))
	if b["data"] > 0.0:
		parts.append("+%d%% DATA" % int(round(b["data"] * 100.0)))
	if b["crit"] > 0.0:
		parts.append("+%d%% CRIT" % int(round(b["crit"] * 100.0)))
	if b["luck"] > 0.0:
		parts.append("+%d%% LUCK" % int(round(b["luck"] * 100.0)))
	return "  ".join(parts)


func _update_combo(delta: float) -> void:
	var n := int(combo)
	combo_eval -= delta
	if combo_eval <= 0.0:
		combo_eval = 0.2
		combo_bonus = combo_bonuses(n)
		player.combo_xp = combo_bonus["xp"]
		player.combo_crit = combo_bonus["crit"]
		player.combo_luck = combo_bonus["luck"]
		combo_data = combo_bonus["data"]
		var tier := combo_tier(n)
		if tier > combo_tier_seen and combo_announce_cd <= 0.0:
			hud.announce("COMBO TIER %d" % tier, [Global.C_CYAN, Global.C_GREEN, Global.C_GOLD, Global.C_MAGENTA][tier - 1])
			ifx("tier", player.position, [Global.C_CYAN, Global.C_GREEN, Global.C_GOLD, Global.C_MAGENTA][tier - 1], 90.0 + 12.0 * tier, 0.6, float(tier))
			Sfx.play("combo", 1.0 + 0.1 * tier, -3.0, 0.0)
			combo_announce_cd = 5.0
		combo_tier_seen = tier
	hud.set_combo(n, combo_text(combo_bonus), combo_tier(n))


func decoy_pos():
	var d = player.items.get("decoy")
	if d is Node and is_instance_valid(d) and d.active:
		return d.pos
	return null


func _item_event(ev: String, arg = null) -> void:
	for v in player.items.values():
		if v is Node and is_instance_valid(v) and v.has_method(ev):
			v.call(ev, arg)


## Cache offers: special items first (at most one trade-off per offer); any empty slots
## (pool exhausted or locked) are filled with boosted upgrade cards.
func _offer_options(offer: Dictionary) -> Array:
	if not offer.get("items", false):
		return _build_options(offer["luck"])
	var plain := []
	var risky := []
	for id in ItemData.ITEMS:
		if player.items.has(id) or not item_unlocked(id) or banned.has("item:" + id):
			continue
		if ItemData.ITEMS[id]["kind"] == "risky":
			risky.append(id)
		else:
			plain.append(id)
	plain.shuffle()
	risky.shuffle()
	var options := []
	var has_risky := false
	for i in offer_size():
		if not risky.is_empty() and not has_risky and (plain.is_empty() or randf() < 0.25):
			options.append(_item_option(risky.pop_back()))
			has_risky = true
		elif not plain.is_empty():
			options.append(_item_option(plain.pop_back()))
		else:
			break
	var fillers := _build_options(offer["luck"])
	while options.size() < offer_size() and not fillers.is_empty():
		options.append(fillers.pop_front())
	options.shuffle()
	return options


## AUTO-UPGRADE / AUTO-DECRYPT (prestige nodes, can be switched off in the prestige tree): the offer is resolved at once, the run never
## pauses and no cards show up. Returns false if the node is off (or there is nothing safe to pick), so the normal cards appear.
func _auto_offer(offer: Dictionary) -> bool:
	var key := "autocache" if offer["decrypt"] else "autolevel"
	if not Meta.auto_on(key):
		return false
	var safe := []
	for opt in _offer_options(offer):
		if opt.get("level_text", "") != "TRADE-OFF":
			safe.append(opt)
	if safe.is_empty():
		return false
	var pick: Dictionary = safe.pick_random()
	for opt in safe:   # an evolution is always worth taking
		if opt.get("kind", "") == "evolution":
			pick = opt
	_apply_option(pick)
	hud.refresh_loadout(self)
	hud.announce(("CACHE AUTO OPENED: %s" if offer["decrypt"] else "UPGRADE AUTO SELECTED: %s") % pick["title"], Global.C_GOLD if offer["decrypt"] else Global.C_CYAN)
	_celebrate(pick["rarity"]["tier"])
	return true


func _item_option(id: String) -> Dictionary:
	var it: Dictionary = ItemData.ITEMS[id]
	var risky: bool = it["kind"] == "risky"
	var rarity := {"name": "CORRUPTED" if risky else "ITEM", "color": Global.C_RED if risky else Global.C_GREEN, "tier": 1, "power": 1.0}
	return {"kind": "item", "id": id, "rarity": rarity, "icon": it["icon"], "title": it["title"],
		"level_text": "TRADE-OFF" if risky else "SPECIAL ITEM", "desc": it["desc"]}


func _give_item(id: String) -> void:
	var it: Dictionary = ItemData.ITEMS[id]
	if it.has("script"):
		var n = load(it["script"]).new()
		player.add_child(n)
		player.items[id] = n
	else:
		player.items[id] = true
		match id:
			"glasscannon":
				player.add_bonus("dmg", 60.0)
				player.max_hp = maxf(30.0, player.max_hp * 0.6)
				player.hp = minf(player.hp, player.max_hp)
			"adrenaline":
				player.add_bonus("speed", 35.0)
				player.damage_taken_mult += 0.25
			"heavyarmor":
				player.armor += 4.0
				player.add_bonus("speed", -25.0)
			"slowburn":
				player.add_bonus("dmg", 45.0)
				player.add_bonus("haste", -50.0)
			"berserker":
				player.crit_chance += 0.25
				player.damage_taken_mult += 0.2
			"backup":
				player.revives += 1
			"seedhack":
				rerolls += 3
			"blocklist":
				bans_left += 2
	hud.announce("ITEM: %s" % it["title"], Global.C_RED if it["kind"] == "risky" else Global.C_GREEN)
	hud.refresh_loadout(self)


func _on_option_chosen(opt: Dictionary) -> void:
	_apply_option(opt)
	hud.refresh_loadout(self)
	if offer_queue.size() > 0:
		_open_next_offer(false)
	else:
		hud.hide_offer()
		offer_open = false
		hud.busy = false
		get_tree().paused = false
	_celebrate(opt["rarity"]["tier"])


func _apply_option(opt: Dictionary) -> void:
	var id: String = opt["id"]
	if opt.get("kind", "") == "item":
		_give_item(id)
		return
	if opt.get("kind", "") == "evolution":
		_evolve(opt["recipe"])
		return
	if WEAPONS.has(id):
		if player.weapons.has(id):
			player.weapons[id].level = opt["to_level"]
		else:
			player.add_weapon(id, WEAPONS[id]["script"], opt["to_level"])
			if id.begins_with("evo_") and not evolved.has(id):
				evolved.append(id)   # a found evolution picked as a card counts as reached this run
		return
	var a: float = opt["amount"]
	match id:
		"speed":
			player.add_bonus("speed", a)
		"vitality":
			player.max_hp += a
			player.heal(a)
		"magnet":
			player.add_bonus("magnet", a)
		"might":
			player.add_bonus("dmg", a)
		"haste":
			player.add_bonus("haste", a)
		"crit":
			player.crit_chance += a / 100.0
		"regen":
			player.regen += a
		"area":
			player.area_mult += a / 100.0
		"luck":
			player.luck_run += a
		"critdmg":
			player.crit_mult += a / 100.0
		"armor":
			player.armor = minf(player.armor + a, ARMOR_CAP)
		"pierce":
			player.extra_pierce += int(a)
		"xp":
			player.xp_mult += a / 100.0
		"knockback":
			player.knockback_mult = minf(player.knockback_mult + a / 100.0, player.KNOCKBACK_CAP)
		"healing":
			player.heal_mult = minf(player.heal_mult + a / 100.0, player.HEAL_CAP)
		"lifesteal":
			player.lifesteal = minf(player.lifesteal + a / 100.0, player.LIFESTEAL_CAP)
		"dodge":
			player.dodge = minf(player.dodge + a / 100.0, player.DODGE_CAP)
		"projspeed":
			player.proj_speed = minf(player.proj_speed + a / 100.0, player.PROJ_SPEED_CAP)
		"proj":
			player.extra_proj = mini(player.extra_proj + int(a), PROJ_CAP)
		"duration":
			player.duration_mult += a / 100.0
		"abilcd":
			player.abilcd = minf(player.abilcd + a, ABILCD_CAP)
		"itemcd":
			player.add_bonus("itemcd", minf(a, ITEMCD_CAP - player.pct["itemcd"]))
		"burn", "poison", "freeze", "shock":
			player.status_chance[id] = minf(player.status_chance[id] + a, player.STATUS_CAP)
		"potency":
			player.status_potency = minf(player.status_potency + a, player.STATUS_POTENCY_CAP)


func _celebrate(tier: int) -> void:
	var pos: Vector2 = player.position
	match tier:
		0:
			ring(pos, Global.C_CYAN, 100.0, 0.35, 4.0)
		1:
			ring(pos, Global.RARITIES[1]["color"], 160.0, 0.45, 6.0)
			burst(pos, Global.RARITIES[1]["color"], 25, 260.0)
			ifx("rarity", pos, Global.RARITIES[1]["color"], 130.0, 0.5, 1.0)
		2:
			var col: Color = Global.RARITIES[2]["color"]
			hud.flash(col, 0.35)
			hud.announce("EPIC UPGRADE", col)
			ring(pos, col, 340.0, 0.6, 10.0)
			burst(pos, col, 50, 380.0, 5.0, 0.8)
			ifx("rarity", pos, col, 220.0, 0.8, 2.0)
			shake(0.3)
			Sfx.play("levelup", 1.2)
		3:
			hud.flash(Global.C_GOLD, 0.5)
			hud.announce("LEGENDARY UPGRADE", Global.C_GOLD, true)
			ring(pos, Global.C_GOLD, 480.0, 0.8, 14.0)
			ring(pos, Color.WHITE, 300.0, 0.5, 8.0)
			burst(pos, Global.C_GOLD, 80, 520.0, 6.0, 1.0)
			ifx("rarity", pos, Global.C_GOLD, 320.0, 1.1, 3.0)
			shake(0.5)
			Sfx.play("legendary_pick", 1.0, 0.0, 0.0)   # payoff sound when a Legendary is picked
			Sfx.play("explode", 0.8, -10.0)             # with a soft low boom underneath


func _system_purge() -> void:
	var pos: Vector2 = player.position
	purging = true
	hud.flash(Global.C_GOLD, 0.7)
	hud.announce("SYSTEM PURGE", Global.C_GOLD, true)
	Sfx.play("ab_purge", 1.0, 0.0, 0.0)   # same sound as the PURGE ability
	shake(1.0)
	afx("disc", pos, Global.C_GOLD, 950.0, 1.2, 6.0)
	# scales with the player's damage (research, items, level-ups) and the PURGE PAYLOAD research node
	var purge_mult: float = player.damage_mult * (1.0 + Meta.stat("purgedmg") / 100.0)
	for e in enemy_layer.get_children():
		if e.position.distance_to(pos) < 950.0:
			if e.is_boss:
				continue  # System Purge no longer hurts bosses
			elif e.elite:
				e.take_damage(e.max_hp * PURGE_ELITE_PCT * purge_mult, Vector2.ZERO, true)
			else:
				e.take_damage(e.hp + 1.0, (e.position - pos).normalized() * 500.0, true)
	purging = false
	slow_mo(0.35, 0.7)


# ---------- run end ----------

func _on_victory() -> void:
	victory = true
	run_over = true
	raw_data += 1500.0
	first_cure = not Meta.cured
	cure_record = Meta.record_cure_time(real_elapsed)
	pp_gained = Meta.record_cure()   # committed now, so dying later in overtime can never lose it
	_check_achievements()
	await get_tree().create_timer(2.5, true, false, true).timeout
	if not is_inside_tree():
		return
	Sfx.play("device_cure", 1.0, 0.0, 0.0)
	hud.show_cure_prompt(Meta.device_name())


## CONTINUE on the cure prompt: a clean slate, then overtime begins.
func continue_overtime() -> void:
	hud.hide_cure_prompt()
	Music.play_gameplay()
	get_tree().paused = false
	hud.busy = false
	for e in enemy_layer.get_children():
		e.queue_free()
	for bl in bullet_layer.get_children():
		bl.queue_free()
	player.heal(player.max_hp * 0.3)
	player.invuln = 2.0
	run_over = false
	overtime = true
	overtime_start = elapsed
	next_ot_boss = elapsed + OT_BOSS_EVERY
	hud.announce("OVERTIME", Global.C_GOLD, true)
	Sfx.play("legendary", 0.8, -4.0, 0.0)


## THE INTERNET: where the final boss would arrive, overtime simply begins. There is no cure and no end.
func _start_internet_overtime() -> void:
	next_boss = BOSS_TIMES.size()
	overtime = true
	overtime_start = elapsed
	next_ot_boss = elapsed + OT_BOSS_EVERY
	player.heal(player.max_hp * 0.3)
	hud.announce("NO END IN SIGHT: THREATS GROW EVERY MINUTE", Global.C_GOLD, true)
	Sfx.play("legendary", 0.8, -4.0, 0.0)


## CASH OUT on the cure prompt (or in the pause menu during overtime).
func cash_out() -> void:
	hud.hide_cure_prompt()
	cashed_out = true   # the results screen says DEVICE CURED and plays the winning jingle
	run_over = true
	_finish_run()


func _on_player_died() -> void:
	run_over = true
	hud.busy = true
	var pos: Vector2 = player.position
	burst(pos, Global.C_CYAN, 90, 450.0, 6.0, 1.4)
	burst(pos, Global.C_RED, 50, 300.0, 5.0, 1.2)
	ring(pos, Global.C_RED, 500.0, 1.0, 12.0)
	shake(1.0)
	hud.flash(Global.C_RED, 0.6)
	Sfx.play("player_death", 1.0, 0.0, 0.0)
	Engine.time_scale = 0.25
	await get_tree().create_timer(1.3, true, false, true).timeout
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	_finish_run()


func _run_stats() -> Dictionary:
	return {"time": real_elapsed, "bosses": bosses_defeated, "level": player.level, "combo": best_combo, "victory": victory, "hits": hits_taken,
		"overtime": (elapsed - overtime_start) if overtime else 0.0, "weapons": player.weapons.size(), "kills": kills, "evolved": evolved,
		"shock_kills": shock_kills, "freeze_kills": freeze_kills, "class": cls.get("id", ""), "hard": Meta.run_hard(), "speed": Meta.run_speed(), "internet": internet}


func _check_challenge() -> void:
	if challenge.is_empty() or Meta.challenges_done.has(challenge["id"]) or not Meta.Challenges.goal_met(challenge, _run_stats()):
		return
	if Meta.complete_challenge(challenge["id"]):
		new_achievements.append({"name": "CHALLENGE: %s (+%s)" % [challenge["name"], challenge["reward_text"]], "pp": 0})
		hud.announce("CHALLENGE COMPLETE: %s  -  %s" % [challenge["name"], challenge["reward_text"].to_upper()], Global.C_GREEN, true)
		Sfx.play("legendary", 1.0, 0.0, 0.0)


func _check_achievements() -> void:
	for w in Meta.check_secret_weapons(_run_stats()):
		var wn: String = Meta.by_id[Meta.unlock_node["weapon:" + w]]["name"]
		new_achievements.append({"name": "SECRET WEAPON FOUND: %s" % wn, "pp": 0})
		if not run_over or victory:
			hud.announce("SECRET WEAPON FOUND: %s" % wn, Global.C_GREEN, true)
			Sfx.play("achievement", 1.0, 0.0, 0.5)
	for c in Meta.check_secret_classes(_run_stats()):
		new_achievements.append({"name": "SECRET CLASS FOUND: %s" % c["name"], "pp": 0})
		if not run_over or victory:
			hud.announce("SECRET CLASS FOUND: %s" % c["name"], c["color"], true)
			Sfx.play("achievement", 1.0, 0.0, 0.5)
	for a in Meta.check_achievements(_run_stats()):
		new_achievements.append(a)
		if not run_over or victory:
			hud.announce("ACHIEVEMENT: %s  +%d PP" % [a["name"], a["pp"]], Global.C_GOLD)
			Sfx.play("achievement", 1.0, 0.0, 0.5)


func _finish_run() -> void:
	hud.busy = true
	var earned := data_earned()
	var mode := Meta.mode_key()
	if not internet and elapsed > float(Meta.device_best.get(Meta.selected_device, 0.0)):
		Meta.device_best[Meta.selected_device] = elapsed
	var record: bool = elapsed > Meta.mode_best.get(mode, 0.0)
	if record:
		Meta.mode_best[mode] = elapsed
		if mode == "normal":
			Global.best_time = elapsed
			Global.save()
	var ot_seconds := (elapsed - overtime_start) if overtime else 0.0
	var ot_record := ot_seconds > Global.best_overtime
	if ot_record:
		Global.best_overtime = ot_seconds
		Global.save()
	Meta.record_run(earned, bosses_defeated, kills)
	_check_challenge()
	_check_achievements()
	get_tree().paused = true
	hud.show_results({"time": elapsed, "level": player.level, "kills": kills, "combo": best_combo,
		"record": record, "data": earned, "victory": victory, "cashed_out": cashed_out, "first_cure": first_cure, "pp": pp_gained, "mode": Meta.mode_name(), "cure_time": real_elapsed if cure_record else 0.0,
		"bosses": bosses_defeated, "new_ring": bosses_defeated > start_best_boss,
		"overtime": ot_seconds, "overtime_bosses": overtime_bosses, "overtime_record": ot_record,
		"achievements": new_achievements.map(func(a): return a["name"])})


# ---------- background ----------

## Slow, subtle variation under the floor grid so long runs do not look flat: big drifting colour patches, a faint scanline
## sweep, and one animated layer per device (snow, rising icons, key flashes, data pulses, heat bands, stars, falling code, rings).
func _draw_backdrop(c: Vector2, half: Vector2, base: Color) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var tier := Meta.run_tier() % 8
	# 1) (removed) the 640 px colour patches: they showed as a big tinted grid over the floor and muddied the floor tiles
	# 2) a faint scanline band sweeping down the view
	# (anchored to the world, so moving does not drag it along with the player)
	var span := half.y * 2.0 + 200.0
	var sweep_y := (c.y - half.y - 100.0) + fposmod(t * 90.0 - (c.y - half.y - 100.0), span)
	draw_rect(Rect2(c.x - half.x, sweep_y, half.x * 2.0, 70.0), Color(base, 0.04))
	draw_rect(Rect2(c.x - half.x, sweep_y + 70.0, half.x * 2.0, 2.0), Color(base, 0.10))
	# 3) per-device animated layer (parallax particles wrap around the view)
	var n := 36
	var w := half.x * 2.0
	var h := half.y * 2.0
	var bright := base.lerp(Color.WHITE, 0.5)
	for i in n:
		var r1 := float(absi(hash(i * 7919 + tier)) % 1000) / 1000.0
		var r2 := float(absi(hash(i * 104729 + tier * 13)) % 1000) / 1000.0
		var r3 := float(absi(hash(i * 1299709 + 5)) % 1000) / 1000.0
		var par := 1.0   # world-fixed: particles only drift with their own motion, never with the player
		var vx := 0.0
		var vy := 0.0
		match tier:
			0: vy = 30.0 + 40.0 * r3; vx = 12.0 * sin(t * 0.7 + i)   # snow falls and sways
			1: vy = -20.0 - 30.0 * r3   # icons float up
			2: vx = 0.0
			3: vx = 70.0 + 80.0 * r3   # data pulses run along
			4: vx = 25.0 * r3
			5: vx = -6.0 * r3
			6: vy = 90.0 + 90.0 * r3   # falling code
			7: vx = 0.0
		var p := Vector2(
			fposmod(r1 * w + t * vx - c.x * par, w) - half.x + c.x,
			fposmod(r2 * h + t * vy - c.y * par, h) - half.y + c.y)
		var tw := 0.5 + 0.5 * sin(t * (1.0 + 2.0 * r3) + i)
		match tier:
			0:
				FD.circle(self, p, 1.5 + 2.0 * r3, Color(bright, 0.35))
			1:
				draw_rect(Rect2(p, Vector2(10, 10) * (0.8 + r3)), Color(bright, 0.12 + 0.1 * tw), false, 1.5)
			2:
				var pressed := fposmod(t * 0.8 + r1 * 5.0, 5.0) < 0.5   # a key "presses" now and then
				draw_rect(Rect2(p, Vector2(26, 26)), Color(bright, 0.22 if pressed else 0.05), pressed)
			3:
				draw_line(p, p - Vector2(30.0 + 30.0 * r3, 0), Color(bright, 0.3), 2.0)
				FD.circle(self, p, 2.5, Color(bright, 0.6))
			4:
				draw_rect(Rect2(p.x, p.y, 120.0 + 100.0 * r2, 6.0), Color(1.0, 0.6, 0.2, 0.05 + 0.04 * tw))   # heat band
				if i % 6 == 0:
					draw_arc(p, 40.0, t * 3.0, t * 3.0 + 4.0, 16, Color(bright, 0.18), 3.0)   # fan blades
			5:
				FD.circle(self, p, 1.0 + 1.6 * r3, Color(Color.WHITE, 0.2 + 0.6 * tw))
			6:
				draw_line(p, p + Vector2(0, 26), Color(bright, 0.2), 2.0)
				draw_rect(Rect2(p + Vector2(-2, 26), Vector2(4, 6)), Color(bright, 0.5))
			7:
				var rr := 8.0 + 40.0 * fposmod(t * 0.35 + r1, 1.0)
				draw_arc(p, rr, 0.0, TAU, 24, Color(bright, 0.3 * (1.0 - rr / 48.0)), 1.5)


func _draw() -> void:
	if player == null:
		return
	var c: Vector2 = player.global_position
	var cell := 64.0
	var half := get_viewport_rect().size / 2.0 + Vector2(120, 120)
	var x0 := floori((c.x - half.x) / cell)
	var x1 := ceili((c.x + half.x) / cell)
	var y0 := floori((c.y - half.y) / cell)
	var y1 := ceili((c.y + half.y) / cell)
	var base: Color = Meta.device_palette()
	if is_instance_valid(current_boss):
		base = base.lerp(current_boss.color, 0.5)
	# the per-device floor pattern is baked once into a 1024 px tile (see fx/floor_tile.gd) and just repeated here
	_ensure_floor_tile()
	if floor_tex != null:
		var fr := Rect2(Vector2(floori((c.x - half.x) / 1024.0), floori((c.y - half.y) / 1024.0)) * 1024.0, Vector2.ZERO)
		fr.size = Vector2((floori((c.x + half.x) / 1024.0) + 1) * 1024.0 - fr.position.x, (floori((c.y + half.y) / 1024.0) + 1) * 1024.0 - fr.position.y)
		draw_texture_rect(floor_tex, fr, true)
	_draw_backdrop(c, half, base)   # translucent colour patches and drifting particles over the floor


var floor_tex: Texture2D = null
var floor_vp: SubViewport = null


## Renders one 1024x1024 tile of this device's floor into a SubViewport once, then reuses the texture every frame
## (drawing ~400 cells of lines and circles every frame was far too slow on weaker GPUs).
func _ensure_floor_tile() -> void:
	if floor_vp != null:
		return
	floor_vp = SubViewport.new()
	floor_vp.size = Vector2i(1024, 1024)
	floor_vp.transparent_bg = false   # opaque: faint lines drawn on a transparent tile get blended twice and come out much dimmer
	floor_vp.disable_3d = true
	floor_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var ft = FloorTileScript.new()
	ft.tier = 8 if Meta.run_internet() else Meta.run_tier() % 8   # THE INTERNET has its own floor art set (8)
	ft.base = Meta.device_palette()
	floor_vp.add_child(ft)
	add_child(floor_vp)
	floor_tex = floor_vp.get_texture()
