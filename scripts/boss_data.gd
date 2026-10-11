extends RefCounted
## Boss catalogue. The first three bosses of a run are picked at random from MID; the final boss
## is unique to the device (FINALS, cycling for devices beyond the list).
## Regular boss health, damage and rewards scale by SLOT (1st/2nd/3rd boss), not by which boss it is, so any
## boss can appear in any slot; the boss's identity changes how it moves, attacks and looks.
## To add a boss: add an entry here, plus a draw arm named after its id in boss.gd (_draw).
## Attack entries are [name, interval seconds, first delay]. Attack names live in boss.gd (_attack).

const SLOT_HP := [3200.0, 9500.0, 19000.0]
const SLOT_DMG := [18.0, 26.0, 30.0]
const SLOT_XP := [60, 120, 200]

const MID := {
	"megaworm": {"name": "MEGAWORM", "color": Color(0.35, 1.0, 0.45), "radius": 90.0, "speed": 105.0, "hp": 1.0, "dmg": 1.0,
		"attacks": [["summon_bug", 6.0, 3.0], ["dash", 7.0, 5.0]]},
	"locker": {"name": "THE LOCKER", "color": Color(1.0, 0.22, 0.3), "radius": 138.0, "speed": 45.0, "hp": 1.2, "dmg": 1.0,
		"attacks": [["radial", 3.2, 2.0], ["aimed", 2.2, 1.0], ["summon_trojan", 9.0, 6.0]]},
	"hive": {"name": "BOTNET HIVE", "color": Color(0.35, 0.55, 1.0), "radius": 112.0, "speed": 70.0, "hp": 1.0, "dmg": 1.0,
		"attacks": [["dash", 5.0, 3.0], ["summon_botnet", 8.0, 4.0], ["aimed", 2.6, 1.5]]},
	"popupking": {"name": "POP-UP KING", "color": Color(1.0, 0.88, 0.25), "radius": 114.0, "speed": 55.0, "hp": 1.1, "dmg": 1.0,
		"attacks": [["summon_popup", 5.0, 3.0], ["aimed", 2.4, 1.0], ["radial", 5.5, 4.0]]},
	"keylogger": {"name": "KEYLOGGER", "color": Color(0.9, 0.95, 1.0), "radius": 96.0, "speed": 75.0, "hp": 0.9, "dmg": 1.0, "kite": true,
		"attacks": [["fan", 2.6, 1.5], ["blink", 7.0, 4.0], ["aimed", 1.8, 1.0]]},
	"phisher": {"name": "PHISHER", "color": Color(0.2, 0.9, 0.8), "radius": 108.0, "speed": 85.0, "hp": 1.0, "dmg": 1.0,
		"attacks": [["dash", 4.5, 3.0], ["summon_bug", 7.0, 5.0], ["slam", 5.0, 3.0]]},
}

## Mini-bosses of the secret rooms (not part of any lineup). Stats scale like slot 0 bosses.
const SECRET := {
	"golem": {"id": "golem", "name": "ICE CUBE GOLEM", "color": Color(0.55, 0.9, 1.0), "radius": 100.0, "speed": 60.0, "hp": 0.6, "dmg": 0.8,
		"attacks": [["radial", 3.5, 2.0], ["slam", 5.0, 3.0]]},
	"intern": {"id": "intern", "name": "THE INTERN", "color": Color(0.4, 0.55, 0.95), "radius": 40.0, "speed": 95.0, "hp": 0.02, "dmg": 0.05, "kite": true,
		"attacks": []},
	"alien": {"id": "alien", "name": "THE VISITOR", "color": Color(0.5, 1.0, 0.6), "radius": 120.0, "speed": 65.0, "hp": 1.6, "dmg": 1.0,
		"attacks": [["radial", 3.0, 2.0], ["aimed", 2.0, 1.0], ["summon_bug", 8.0, 5.0]]},
	"kbd": {"id": "kbd", "name": "KEYBOARD WARRIOR", "color": Color(1.0, 0.5, 0.3), "radius": 100.0, "speed": 70.0, "hp": 1.0, "dmg": 1.0,
		"attacks": [["aimed", 1.8, 1.0], ["fan", 3.0, 2.0]]},
	"clicker": {"id": "clicker", "name": "THE CLICKER", "color": Color(0.9, 0.9, 0.5), "radius": 80.0, "speed": 110.0, "hp": 0.7, "dmg": 0.8,
		"attacks": [["dash", 3.5, 2.0], ["aimed", 2.4, 1.0]]},
	"webcam": {"id": "webcam", "name": "THE WATCHER", "color": Color(0.6, 0.9, 1.0), "radius": 90.0, "speed": 55.0, "hp": 0.8, "dmg": 0.8,
		"attacks": [["radial", 3.5, 2.0], ["aimed", 2.0, 1.0]]},
	"headset": {"id": "headset", "name": "STATIC", "color": Color(0.8, 0.5, 1.0), "radius": 90.0, "speed": 60.0, "hp": 0.8, "dmg": 0.8,
		"attacks": [["spiral", 6.0, 2.0], ["aimed", 2.2, 1.0]]},
	"window": {"id": "window", "name": "NOT RESPONDING", "color": Color(0.7, 0.8, 1.0), "radius": 96.0, "speed": 55.0, "hp": 0.6, "dmg": 0.8,
		"attacks": [["aimed", 2.0, 1.0], ["summon_popup", 7.0, 4.0]]},
}

const FINALS := [
	{"id": "kernel", "name": "ROOT KERNEL", "color": Color(1.0, 0.25, 0.75), "radius": 168.0, "speed": 60.0, "hp": 45000.0, "dmg": 32.0, "xp": 400,
		"attacks": [["spiral", 7.0, 3.0], ["radial", 4.0, 2.0], ["summon_kernel", 14.0, 8.0], ["dash", 9.0, 6.0]]},
	{"id": "baseband", "name": "BASEBAND", "color": Color(0.3, 0.9, 1.0), "radius": 156.0, "speed": 52.0, "hp": 45000.0, "dmg": 30.0, "xp": 400,
		"attacks": [["spiral", 6.0, 2.0], ["fan", 3.0, 1.5], ["summon_spy", 12.0, 7.0], ["blink", 10.0, 6.0]]},
	{"id": "bluescreen", "name": "BLUE SCREEN", "color": Color(0.25, 0.45, 1.0), "radius": 168.0, "speed": 38.0, "hp": 50000.0, "dmg": 34.0, "xp": 400,
		"attacks": [["slam", 2.6, 1.5], ["radial", 4.5, 3.0], ["summon_popup", 10.0, 5.0], ["spiral", 9.0, 6.0]]},
]


static func final_for(device: int) -> Dictionary:
	return FINALS[device % FINALS.size()].duplicate()


## One random regular boss (overtime bosses).
static func random_mid() -> Dictionary:
	var ids: Array = MID.keys()
	var id: String = ids.pick_random()
	var d: Dictionary = MID[id].duplicate()
	d["id"] = id
	return d


## Three distinct random bosses followed by the device's final boss.
static func pick_lineup(device: int) -> Array:
	var ids: Array = MID.keys()
	ids.shuffle()
	var out := []
	for i in 3:
		var d: Dictionary = MID[ids[i]].duplicate()
		d["id"] = ids[i]
		out.append(d)
	out.append(final_for(device))
	return out
