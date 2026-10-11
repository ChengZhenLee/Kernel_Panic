extends RefCounted
## Character classes. Each has a starting weapon (replaces the PACKET GUN), a passive and one active ability
## (on-screen button, or Space / Q). Classes are bought in the CLASSES research tree and, like weapons, must be bought
## again after every reformat. How a class becomes available is in Meta.CLASS_SOURCE.
## Passive keys are applied in game._apply_class(): hp, regen, crit, critdmg, area, duration, speed, dodge, xp, luck.

const NONE := {"id": "", "name": "BASIC", "weapon": "laser", "passive_text": "-", "ability_name": "", "ability_text": "", "cd": 0.0}

## The button for players without a class: no cooldown, usable only with stored charges (from caches).
const GENERIC := {"id": "", "name": "SYSTEM", "color": Color(1.0, 0.82, 0.2), "icon": "bomb", "ability": "purge", "ability_name": "PURGE",
	"ability_text": "Wipe every threat on screen (not bosses). Recharges in 60s", "cd": 60.0}

const LIST := [
	{"id": "sysadmin", "name": "SYSADMIN", "weapon": "firewall", "color": Color(0.35, 1.0, 0.45), "icon": "vitality",
		"passive": {"hp": 25.0, "regen": 0.3}, "passive_text": "+25 max HP, +0.3 HP per second",
		"ability": "restore", "ability_name": "RESTORE", "ability_text": "Heal 30% max HP and shrug off hits for 1.5s", "cd": 60.0},
	{"id": "hacker", "name": "HACKER", "weapon": "backdoor", "color": Color(1.0, 0.88, 0.25), "icon": "crit",
		"passive": {"crit": 0.10, "critdmg": 0.2}, "passive_text": "+10% crit chance, +20% crit damage",
		"ability": "overclock", "ability_name": "OVERCLOCK", "ability_text": "+50% weapon speed for 6s", "cd": 45.0},
	{"id": "architect", "name": "ARCHITECT", "weapon": "mines", "color": Color(0.35, 0.55, 1.0), "icon": "area",
		"passive": {"area": 0.2, "duration": 0.2}, "passive_text": "+20% weapon area, +20% effect duration",
		"ability": "lockdown", "ability_name": "LOCKDOWN", "ability_text": "Slow every nearby threat for 4s and hit them", "cd": 60.0},
	{"id": "ghost", "name": "GHOST", "weapon": "zap", "color": Color(0.7, 0.3, 1.0), "icon": "speed",
		"passive": {"speed": 10.0, "dodge": 0.08}, "passive_text": "+10% move speed, +8% dodge",
		"ability": "phase", "ability_name": "PHASE", "ability_text": "Dash forward through walls and turn invisible: threats ignore you for 1.5s", "cd": 20.0},
	{"id": "analyst", "name": "ANALYST", "weapon": "scanner", "color": Color(0.2, 0.9, 0.8), "icon": "xp",
		"passive": {"xp": 0.25, "luck": 8.0}, "passive_text": "+25% XP, +8% luck",
		"ability": "deepscan", "ability_name": "DEEP SCAN", "ability_text": "Every threat on screen takes +25% damage for 8s", "cd": 40.0},
	# starts with no weapon at all: free, always owned. Win with the first cards and the PAUSE ability.
	{"id": "pacifist", "name": "PACIFIST", "weapon": "", "color": Color(0.9, 0.95, 1.0), "icon": "haste",
		"passive": {"xp": 0.3, "luck": 10.0}, "passive_text": "+30% XP, +10% luck",
		"ability": "pause", "ability_name": "PAUSE", "ability_text": "Stop time for 4s: threats, shots and spawns freeze", "cd": 60.0},
	# SECRET classes: each starts with an evolved weapon. They are never listed until the player finds them (Meta.SECRET_CLASSES).
	{"id": "railgunner", "name": "RAILGUNNER", "weapon": "evo_railgun", "color": Color(1.0, 0.9, 0.4), "icon": "evo_railgun",
		"passive": {"crit": 0.15, "critdmg": 0.3}, "passive_text": "+15% crit chance, +30% crit damage",
		"ability": "railstrike", "ability_name": "RAIL STRIKE", "ability_text": "Fire a rail beam ahead that pierces every threat and wall in its line for a guaranteed heavy crit", "cd": 30.0},
	{"id": "arsonist", "name": "ARSONIST", "weapon": "evo_inferno", "color": Color(1.0, 0.45, 0.15), "icon": "evo_inferno",
		"passive": {"area": 0.25, "duration": 0.25}, "passive_text": "+25% weapon area, +25% effect duration",
		"ability": "wildfire", "ability_name": "WILDFIRE", "ability_text": "Set every nearby threat ablaze with a strong 6s burn (sets off TOXIC FLARE and MELTDOWN)", "cd": 50.0},
	{"id": "stormcaller", "name": "STORMCALLER", "weapon": "evo_tesla", "color": Color(0.6, 0.9, 1.0), "icon": "evo_tesla",
		"passive": {"speed": 10.0, "xp": 0.2}, "passive_text": "+10% move speed, +20% XP",
		"ability": "thunderstorm", "ability_name": "THUNDERSTORM", "ability_text": "For 6s, lightning strikes a nearby threat every 0.35s, hitting and shocking it", "cd": 45.0},
	{"id": "cryomancer", "name": "CRYOMANCER", "weapon": "evo_blizzard", "color": Color(0.7, 0.92, 1.0), "icon": "evo_blizzard",
		"passive": {"hp": 30.0, "dodge": 0.05}, "passive_text": "+30 max HP, +5% dodge",
		"ability": "deepfreeze", "ability_name": "DEEP FREEZE", "ability_text": "Freeze every nearby threat solid for 3s (bosses are slowed); shattering them deals bonus damage", "cd": 55.0},
]


static func by_id(id: String) -> Dictionary:
	for c in LIST:
		if c["id"] == id:
			return c
	return NONE
