extends RefCounted
## Weapon evolutions: two weapons at the required level plus a special item become one super weapon.
## They are discovered in a run: when the conditions are met a Legendary EVOLVE card is offered with a boosted chance (game.EVO_CHANCE).
## The evolved weapon replaces the two inputs. The first discovery grants its ARSENAL node for good (no purchase, kept through reformats):
## it gets a DATA mastery like every other weapon. A run only ever offers it as the EVOLVE card, once that run meets the recipe.

const LIST := [
	{"id": "evo_railgun", "name": "RAILGUN", "weapons": ["laser", "backdoor"], "item": "drone", "lvl": 10, "color": Color(1.0, 0.9, 0.4),
		"desc": "Fires a piercing beam that cuts through everything in a line."},
	{"id": "evo_inferno", "name": "SCORCHED EARTH", "weapons": ["firewall", "mines"], "item": "totem", "lvl": 10, "color": Color(1.0, 0.45, 0.15),
		"desc": "A huge burning ring that ignites threats and erupts every few seconds."},
	{"id": "evo_tesla", "name": "TESLA GRID", "weapons": ["zap", "scanner"], "item": "chain", "lvl": 10, "color": Color(0.6, 0.9, 1.0),
		"desc": "Lightning strikes many threats at once, shocking them and arcing on."},
	{"id": "evo_blizzard", "name": "ABSOLUTE ZERO", "weapons": ["quarantine", "orbit"], "item": "shatter", "lvl": 10, "color": Color(0.7, 0.92, 1.0),
		"desc": "A pulsing frost aura surrounds you, freezing and damaging everything in reach."},
]

## Evolved weapons used as a starting weapon begin at this level (plus START LEVEL research).
const START_LEVEL := 3


static func by_id(id: String) -> Dictionary:
	for e in LIST:
		if e["id"] == id:
			return e
	return {}


## The base icon each evolved weapon is drawn on (icon_art adds a gold star ring).
static func base_icon(id: String) -> String:
	var e := by_id(id)
	return e["weapons"][0] if not e.is_empty() else "laser"
