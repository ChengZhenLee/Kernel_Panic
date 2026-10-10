extends RefCounted
## Opt-in challenges, picked on the device map. Each applies a rule to the run, has a goal (checked live during the run),
## and pays its reward once. Today that is prestige points; a reward of "weapon:id" instead gives permission to buy that weapon (it still has to be bought again after every reformat).
## Rules (applied in game.gd): "laser_only" offers no other weapons; "glass" cuts max HP to 35%.
## Goal keys match game._run_stats(): time (seconds) or bosses (defeated this run).

const LIST := [
	{"id": "laser_only", "name": "SINGLE THREAD", "rule": "laser_only", "rule_text": "Only the PACKET GUN",
		"goal_key": "time", "goal_min": 360.0, "goal_text": "Survive 6 minutes", "reward": "class:analyst", "reward_text": "the ANALYST class (then buy it in the CLASSES tree)"},
	{"id": "glass", "name": "GLASS CANNON", "rule": "glass", "rule_text": "Max HP is 35%",
		"goal_key": "bosses", "goal_min": 2.0, "goal_text": "Defeat 2 bosses", "reward": "class:ghost", "reward_text": "the GHOST class (then buy it in the CLASSES tree)"},
	{"id": "incognito", "name": "INCOGNITO MODE", "rule": "incognito", "rule_text": "You only see as far as your weapon area (the area card widens it); no minimap or damage numbers",
		"goal_key": "time", "goal_min": 360.0, "goal_text": "Survive 6 minutes", "reward": "weapon:backdoor", "reward_text": "the BACKDOOR weapon (then buy it in the ARSENAL tree)"},
]

## Evolution trials are gone: evolutions are no longer starting weapons (kept for a future class that starts with one).
const EVO_TIME := 480.0
const EVO_CHALLENGES := []

const ALL := LIST + EVO_CHALLENGES


static func by_id(id: String) -> Dictionary:
	for c in ALL:
		if c["id"] == id:
			return c
	return {}


static func goal_met(c: Dictionary, run: Dictionary) -> bool:
	if c.has("evo") and not run.get("evolved", []).has(c["evo"]):
		return false
	return float(run.get(c["goal_key"], 0.0)) >= c["goal_min"]
