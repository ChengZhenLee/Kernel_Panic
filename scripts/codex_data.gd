extends RefCounted
## Codex entries. Key format used in Meta.codex: "enemy:<kind>", "affix:<NAME>", "boss:<id>".
## Each entry: key, name, desc, color, sides (icon polygon). Unseen entries are blacked out until first met in a run.

const ENEMIES := [
	{"key": "enemy:bug", "name": "BUG", "desc": "Fast and fragile. Zig-zags straight at you.", "color": Color(1.0, 0.25, 0.75), "sides": 3},
	{"key": "enemy:worm", "name": "WORM", "desc": "A segmented body that steadily chases you.", "color": Color(0.35, 1.0, 0.45), "sides": 5},
	{"key": "enemy:adware", "name": "ADWARE", "desc": "Splits into POPUPs when it is deleted.", "color": Color(1.0, 0.88, 0.25), "sides": 4},
	{"key": "enemy:popup", "name": "POPUP", "desc": "Small and quick. Spawned by Adware and some bosses.", "color": Color(1.0, 0.88, 0.25), "sides": 4},
	{"key": "enemy:trojan", "name": "TROJAN", "desc": "Slow and tanky. Soaks up a lot of damage.", "color": Color(1.0, 0.55, 0.15), "sides": 6},
	{"key": "enemy:spyware", "name": "SPYWARE", "desc": "Keeps its distance and shoots at you.", "color": Color(0.92, 0.95, 1.0), "sides": 3},
	{"key": "enemy:botnet", "name": "BOTNET", "desc": "Winds up, then dashes. Sidestep the telegraph.", "color": Color(0.35, 0.55, 1.0), "sides": 5},
	{"key": "enemy:ransom", "name": "RANSOMWARE", "desc": "A padlock brute with huge health and a big XP payout.", "color": Color(1.0, 0.22, 0.3), "sides": 4},
	{"key": "enemy:mite", "name": "MITE", "desc": "Tiny and very fast. Always comes in packs of 5 or more. Up close it crouches and lunges, then latches onto you for a second, slowing you and biting twice, then vanishes. Dies to anything.", "color": Color(0.6, 1.0, 0.2), "sides": 6},
	{"key": "enemy:miner", "name": "MINER", "desc": "A crypto-miner that wanders aimlessly, busy with its own work. Plenty of health and a rich XP payout; it only hurts if you bump into it.", "color": Color(0.95, 0.75, 0.2), "sides": 4},
	{"key": "enemy:leech", "name": "LEECH", "desc": "Up close it crouches and lunges, then latches onto you for a second, slowing you and healing itself with every bite. It also slowly regenerates on its own. Burst it down before it feeds.", "color": Color(0.85, 0.15, 0.35), "sides": 6},
	{"key": "enemy:sentry", "name": "SENTRY", "desc": "A turret that never walks. It warps to within range of you (watch for the crosshair), bolts down and fires three-shot fans until you leave its sight.", "color": Color(0.3, 0.9, 0.85), "sides": 4},
	{"key": "enemy:zipbomb", "name": "ZIP BOMB", "desc": "Rushes you, then stops close by and arms: a ring shows the blast filling up for about a second before it explodes for heavy damage. Kill it first to defuse it, or step out of the ring. It never hurts on touch and leaves nothing behind when it goes off.", "color": Color(1.0, 0.72, 0.15), "sides": 8},
	{"key": "enemy:nanobot", "name": "NANOBOT", "desc": "Keeps its distance. It stops and paints a red sight line on you, which locks just before it fires a red laser beam for big damage. Sidestep once the line goes solid; walls cut the beam short.", "color": Color(0.55, 0.8, 1.0), "sides": 4},
	{"key": "enemy:ram", "name": "RAM", "desc": "Rears back behind a red lane, then charges straight down it. A charge that hits deals extra damage and throws you back. Step out of the lane.", "color": Color(0.85, 0.6, 0.35), "sides": 5},
	{"key": "enemy:rootkit", "name": "ROOTKIT", "desc": "Cloaked. Teleports close to you without warning.", "color": Color(0.7, 0.3, 1.0), "sides": 8},
]

const AFFIXES := [
	{"key": "affix:SWIFT", "name": "SWIFT", "desc": "Moves 60% faster.", "color": Color(0.4, 1.0, 0.9), "sides": 0},
	{"key": "affix:ARMORED", "name": "ARMORED", "desc": "Takes half damage.", "color": Color(0.6, 0.8, 1.0), "sides": 0},
	{"key": "affix:VAMPIRIC", "name": "VAMPIRIC", "desc": "Slowly heals itself.", "color": Color(1.0, 0.2, 0.3), "sides": 0},
	{"key": "affix:SUMMONER", "name": "SUMMONER", "desc": "Calls in Bugs every few seconds.", "color": Color(1.0, 0.3, 0.8), "sides": 0},
	{"key": "affix:VOLATILE", "name": "VOLATILE", "desc": "Bursts when it dies.", "color": Color(1.0, 0.5, 0.1), "sides": 0},
]

const BOSSES := [
	{"key": "boss:megaworm", "name": "MEGAWORM", "desc": "Summons Bugs and dashes; its whole body hurts.", "color": Color(0.35, 1.0, 0.45), "sides": 10},
	{"key": "boss:locker", "name": "THE LOCKER", "desc": "Radial and aimed shots, calls Trojans.", "color": Color(1.0, 0.22, 0.3), "sides": 10},
	{"key": "boss:hive", "name": "BOTNET HIVE", "desc": "Dashes and summons Botnets.", "color": Color(0.35, 0.55, 1.0), "sides": 10},
	{"key": "boss:popupking", "name": "POP-UP KING", "desc": "Floods the screen with Popups.", "color": Color(1.0, 0.88, 0.25), "sides": 10},
	{"key": "boss:keylogger", "name": "KEYLOGGER", "desc": "Kites you, fires fans and blinks around.", "color": Color(0.9, 0.95, 1.0), "sides": 10},
	{"key": "boss:phisher", "name": "PHISHER", "desc": "Dashes, slams and summons Bugs.", "color": Color(0.2, 0.9, 0.8), "sides": 10},
	{"key": "boss:kernel", "name": "ROOT KERNEL", "desc": "Final boss of the Smart Fridge. Spirals, rings and Kernel minions.", "color": Color(1.0, 0.25, 0.75), "sides": 12},
	{"key": "boss:baseband", "name": "BASEBAND", "desc": "Final boss of the Smartphone. Spirals, fans, spies and blinks.", "color": Color(0.3, 0.9, 1.0), "sides": 12},
	{"key": "boss:bluescreen", "name": "BLUE SCREEN", "desc": "Final boss of the Gaming Laptop. Heavy slams, rings and Popups.", "color": Color(0.25, 0.45, 1.0), "sides": 12},
]

## Songs of the secret rooms, found in a run and then playable here ("music:<id>" -> assets/audio/music/music_<id>.wav).
const MUSIC := [
	{"key": "music:truth", "name": "THE TRUTH", "desc": "A song that was never meant to be heard. Title stage 3. A snippet is found by repeating the melody in the MUSIC app of the smartphone.", "color": Color(1.0, 0.6, 0.9), "sides": 0},
]

const SECTIONS := [["ENEMIES", ENEMIES], ["MODIFIERS", AFFIXES], ["BOSSES", BOSSES]]


## Every class, greyed out until found (that includes the secret evolution classes: the silhouette is the only hint).
static func classes() -> Array:
	var Classes = preload("res://scripts/classes.gd")
	var out := [{"key": "class:", "name": "BASIC", "desc": "Starts with the PACKET GUN and has no bonuses. The PURGE ability recharges every 60s.", "color": Global.C_CYAN, "icon": ""}]
	for c in Classes.LIST:
		var weapon: String = "NO WEAPON" if c["weapon"] == "" else (preload("res://scripts/evolutions.gd").by_id(c["weapon"])["name"] if String(c["weapon"]).begins_with("evo_") else String(c["weapon"]).to_upper())
		out.append({"key": "class:" + c["id"], "name": c["name"], "color": c["color"], "icon": c["icon"],
			"desc": "Starts with %s. Passive: %s.\nAbility %s: %s." % [weapon, c["passive_text"], c["ability_name"], c["ability_text"]]})
	return out


## One entry per device hazard (hazards.gd), blacked out until a run has had that hazard.
static func hazards() -> Array:
	var out := []
	var hz = preload("res://scripts/hazards.gd")
	for h in hz.TYPES + [hz.THUNDER]:
		out.append({"key": "hazard:" + h["id"], "name": h["name"], "desc": h["text"] + ".", "color": h["color"], "sides": 0})
	return out


## The four status effects and their combos (numbers mirror the constants in enemy.gd). Blacked out until one lands on an enemy.
const STATUS_EFFECTS := [
	{"key": "status:burn", "name": "BURN", "desc": "Sets the target on fire for 3s: it takes 45% of the hit that lit it every second. Re-applying keeps the stronger fire.", "color": Color(1.0, 0.5, 0.1), "icon": "burn"},
	{"key": "status:poison", "name": "POISON", "desc": "Lasts 5s and stacks up to 5 times. Each stack deals 12% of the hit per second, so it shines on tough enemies.", "color": Color(0.5, 1.0, 0.3), "icon": "poison"},
	{"key": "status:freeze", "name": "FREEZE", "desc": "Slows movement to 55% for 2s. Bosses are immune. The setup for SHATTER and MELTDOWN.", "color": Color(0.5, 0.9, 1.0), "icon": "freeze"},
	{"key": "status:shock", "name": "SHOCK", "desc": "For 3s the target takes 25% more damage from everything, and it is stunned for 0.8s (bosses are never stunned, but still take the extra damage).", "color": Color(1.0, 0.95, 0.3), "icon": "shock"},
]

## Combos: the new status reacts with one already on the target, consumes it and deals extra damage as a share of the hit.
const STATUS_COMBOS := [
	{"key": "combo:shatter", "name": "SHATTER", "desc": "SHOCK on a FROZEN target. The ice breaks for 80% of the hit as extra damage, and the freeze is gone.", "color": Color(1.0, 0.95, 0.3), "parts": ["freeze", "shock"]},
	{"key": "combo:meltdown", "name": "MELTDOWN", "desc": "BURN on a FROZEN target. The ice melts for 60% of the hit as extra damage, and the freeze thaws.", "color": Color(1.0, 0.5, 0.1), "parts": ["freeze", "burn"]},
	{"key": "combo:toxicflare", "name": "TOXIC FLARE", "desc": "BURN on a POISONED target. The fumes ignite for 35% of the hit per poison stack, clearing the poison.", "color": Color(0.8, 0.8, 0.2), "parts": ["poison", "burn"]},
]


static func status_pages() -> Array:
	var out := []
	for e in STATUS_EFFECTS:
		out.append(e)
	for e in STATUS_COMBOS:
		out.append(e)
	return out


## The eight base weapons (moved here from the UNLOCKS page): name, what it does, page colour.
const WEAPON_ORDER := ["laser", "firewall", "orbit", "zap", "mines", "scanner", "quarantine", "backdoor"]
const WEAPON_INFO := {
	"laser": ["PACKET GUN", "Fires data bolts at the nearest threat.", Color(0.25, 1.0, 0.9)],
	"firewall": ["FIREWALL", "A burning ring that damages every threat inside.", Color(1.0, 0.55, 0.15)],
	"orbit": ["ENCRYPTION KEYS", "Crystal shards orbit you and shred threats.", Color(0.72, 0.4, 1.0)],
	"zap": ["PING.EXE", "Chain lightning jumps between threats.", Color(1.0, 0.95, 0.3)],
	"mines": ["LOGIC MINE", "Drops proximity mines that blow up crowds.", Color(1.0, 0.22, 0.3)],
	"scanner": ["SCANNER", "Radar beams sweep around you.", Color(0.35, 1.0, 0.45)],
	"quarantine": ["QUARANTINE", "Freezing zones slow and damage groups.", Color(0.5, 0.9, 1.0)],
	"backdoor": ["BACKDOOR", "Opens a door behind a threat; a boomerang flies out and hits it in the back.", Color(1.0, 0.25, 0.75)],
}


## Base weapons, then the evolutions. Key "weapon:<id>" (evolutions keep their "evo_" id); Meta.codex counts the kills of each.
static func weapons() -> Array:
	var out := []
	for id in WEAPON_ORDER:
		var w: Array = WEAPON_INFO[id]
		out.append({"key": "weapon:" + id, "name": w[0], "desc": w[1], "color": w[2], "icon": id})
	var Items = preload("res://scripts/items.gd")
	for r in preload("res://scripts/evolutions.gd").LIST:
		out.append({"key": "weapon:" + r["id"], "name": r["name"], "color": r["color"], "icon": r["id"], "evo": true,
			"desc": "%s\nEVOLUTION: %s + %s + the %s item, both weapons at LV %d. Replaces the two weapons and frees a slot.\nOnce found it stays in your ARSENAL for good (no purchase), but it only ever appears again as an EVOLVE card once a run meets the recipe." % [
				r["desc"], WEAPON_INFO[r["weapons"][0]][0], WEAPON_INFO[r["weapons"][1]][0], Items.ITEMS[r["item"]]["title"], r["lvl"]]})
	return out


## True for an id that gets a WEAPONS page (base weapon or evolution), so kills from items and hazards are not counted.
static func is_weapon(id: String) -> bool:
	return WEAPON_INFO.has(id) or id.begins_with("evo_")


static func sections() -> Array:
	return SECTIONS + [["HAZARDS", hazards()], ["STATUS", status_pages()], ["WEAPONS", weapons()], ["CLASSES", classes()], ["MUSIC", MUSIC]]
