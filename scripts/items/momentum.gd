extends Node
## MOMENTUM: your combo grows your crit chance (+1% per 10 combo). HOT STREAK is its luck twin.
## This is the template for combo-synergy items: any item script may define combo_bonus(combo) and
## return a Dictionary with any of the keys "xp", "data", "crit", "luck" (fractions, e.g. 0.01 = +1%).
## The game adds these to the combo tier rewards and re-evaluates them several times a second.


func combo_bonus(combo: int) -> Dictionary:
	var k := floorf(combo / 10.0) * 0.01
	return {"crit": k}
