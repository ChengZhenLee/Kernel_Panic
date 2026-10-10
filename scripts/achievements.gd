extends RefCounted
## One-off achievements. "life" ones fill a progress bar from Meta.lifetime; "run" ones are checked against a single run.
## Rewards are prestige points for now; weapon and class unlocks plug in here with the challenge system.
## Run stats: time, level, combo, victory, hits, overtime, weapons, kills.

const LIFE_LABELS := {"kills": "threats deleted", "runs": "runs", "bosses": "bosses defeated", "cured": "cures", "data": "DATA earned"}

const LIST := [
	{"id": "kills1", "name": "EXTERMINATOR", "desc": "Delete 1,000 threats in total", "type": "life", "stat": "kills", "target": 1000, "pp": 1},
	{"id": "kills2", "name": "PEST CONTROL", "desc": "Delete 10,000 threats in total", "type": "life", "stat": "kills", "target": 10000, "pp": 2},
	{"id": "kills3", "name": "EXTINCTION EVENT", "desc": "Delete 100,000 threats in total", "type": "life", "stat": "kills", "target": 100000, "pp": 4},
	{"id": "runs1", "name": "FIRST BOOT", "desc": "Finish 1 run", "type": "life", "stat": "runs", "target": 1, "pp": 1},
	{"id": "runs2", "name": "REGULAR", "desc": "Finish 10 runs", "type": "life", "stat": "runs", "target": 10, "pp": 1},
	{"id": "runs3", "name": "UPTIME ADDICT", "desc": "Finish 50 runs", "type": "life", "stat": "runs", "target": 50, "pp": 2},
	{"id": "boss1", "name": "BUG BOUNTY", "desc": "Defeat 10 bosses in total", "type": "life", "stat": "bosses", "target": 10, "pp": 1},
	{"id": "boss2", "name": "BOSS RUSH", "desc": "Defeat 50 bosses in total", "type": "life", "stat": "bosses", "target": 50, "pp": 2},
	{"id": "boss3", "name": "GIANT KILLER", "desc": "Defeat 200 bosses in total", "type": "life", "stat": "bosses", "target": 200, "pp": 4},
	{"id": "cure1", "name": "PATIENT ZERO", "desc": "Cure a device", "type": "life", "stat": "cured", "target": 1, "pp": 1},
	{"id": "cure2", "name": "SYSADMIN", "desc": "Cure devices 5 times", "type": "life", "stat": "cured", "target": 5, "pp": 2},
	{"id": "cure3", "name": "CHIEF SECURITY OFFICER", "desc": "Cure devices 20 times", "type": "life", "stat": "cured", "target": 20, "pp": 4},
	{"id": "data1", "name": "BYTE SIZED", "desc": "Earn 10,000 DATA in total", "type": "life", "stat": "data", "target": 10000, "pp": 1},
	{"id": "data2", "name": "DATA HOARDER", "desc": "Earn 1,000,000 DATA in total", "type": "life", "stat": "data", "target": 1000000, "pp": 2},
	{"id": "data3", "name": "BIG DATA", "desc": "Earn 100,000,000 DATA in total", "type": "life", "stat": "data", "target": 100000000, "pp": 4},
	{"id": "time1", "name": "STILL STANDING", "desc": "Survive 5 minutes in one run", "type": "run", "key": "time", "min": 300, "pp": 1},
	{"id": "time2", "name": "LONG UPTIME", "desc": "Survive 10 minutes in one run", "type": "run", "key": "time", "min": 600, "pp": 1},
	{"id": "time3", "name": "NINES", "desc": "Survive 15 minutes in one run", "type": "run", "key": "time", "min": 900, "pp": 2},
	{"id": "level1", "name": "UPGRADED", "desc": "Reach level 10 in one run", "type": "run", "key": "level", "min": 10, "pp": 1},
	{"id": "level2", "name": "FULLY PATCHED", "desc": "Reach level 20 in one run", "type": "run", "key": "level", "min": 20, "pp": 2},
	{"id": "combo1", "name": "ON A ROLL", "desc": "Reach a x50 combo", "type": "run", "key": "combo", "min": 50, "pp": 1},
	{"id": "combo2", "name": "UNSTOPPABLE", "desc": "Reach a x150 combo", "type": "run", "key": "combo", "min": 150, "pp": 2},
	{"id": "flawless", "name": "FLAWLESS", "desc": "Cure a device without taking a single hit", "type": "run", "key": "hits", "max": 0, "victory": true, "pp": 3},
	{"id": "armory", "name": "ARMORY", "desc": "Hold 5 weapons at once", "type": "run", "key": "weapons", "min": 5, "pp": 1},
	{"id": "minimal", "name": "MINIMALIST", "desc": "Cure a device holding only 1 weapon", "type": "run", "key": "weapons", "max": 1, "victory": true, "pp": 3},
	{"id": "ot1", "name": "OVERTIME", "desc": "Survive 3 minutes of overtime", "type": "run", "key": "overtime", "min": 180, "pp": 2},
	{"id": "ot2", "name": "DOUBLE SHIFT", "desc": "Survive 10 minutes of overtime", "type": "run", "key": "overtime", "min": 600, "pp": 4},
	{"id": "cls_sysadmin", "name": "ON CALL", "desc": "Cure a device as the SYSADMIN", "type": "run", "key": "time", "min": 0, "class": "sysadmin", "victory": true, "pp": 2},
	{"id": "cls_hacker", "name": "ZERO DAY", "desc": "Cure a device as the HACKER", "type": "run", "key": "time", "min": 0, "class": "hacker", "victory": true, "pp": 2},
	{"id": "cls_architect", "name": "BLUEPRINT", "desc": "Cure a device as the ARCHITECT", "type": "run", "key": "time", "min": 0, "class": "architect", "victory": true, "pp": 2},
	{"id": "cls_ghost", "name": "NO TRACE", "desc": "Cure a device as the GHOST", "type": "run", "key": "time", "min": 0, "class": "ghost", "victory": true, "pp": 2},
	{"id": "cls_analyst", "name": "DEEP DIVE", "desc": "Cure a device as the ANALYST", "type": "run", "key": "time", "min": 0, "class": "analyst", "victory": true, "pp": 2},
	{"id": "cls_pacifist", "name": "SIT-IN", "desc": "Survive 5 minutes as the PACIFIST", "type": "run", "key": "time", "min": 300, "class": "pacifist", "pp": 2},
	{"id": "hard1", "name": "NO MERCY", "desc": "Cure a device on HARD", "type": "run", "key": "time", "min": 0, "flag": "hard", "victory": true, "pp": 3},
	{"id": "speed1", "name": "OVERCLOCKED", "desc": "Cure a device in SPEED RUN", "type": "run", "key": "time", "min": 0, "flag": "speed", "victory": true, "pp": 2},
	{"id": "net1", "name": "SURFING", "desc": "Survive 15 minutes on THE INTERNET", "type": "run", "key": "time", "min": 900, "flag": "internet", "pp": 3},
]


static func by_id(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {}


## Current / target for a progress bar (life achievements track the lifetime totals).
static func progress(a: Dictionary, life: Dictionary) -> Array:
	if a["type"] == "life":
		return [float(life.get(a["stat"], 0)), float(a["target"])]
	return [0.0, 1.0]


static func run_met(a: Dictionary, run: Dictionary) -> bool:
	if a["type"] != "run" or not run.has(a["key"]):
		return false
	if a.get("victory", false) and not run.get("victory", false):
		return false
	if a.has("class") and run.get("class", "") != a["class"]:
		return false
	if a.has("flag") and not run.get(a["flag"], false):
		return false
	var v: float = run[a["key"]]
	if a.has("min"):
		return v >= a["min"]
	return v <= a["max"]
