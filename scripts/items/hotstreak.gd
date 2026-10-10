extends Node
## HOT STREAK: your combo grows your luck (+1% per 10 combo). Split from MOMENTUM, which keeps the crit half.
## See momentum.gd for how combo_bonus() works.


func combo_bonus(combo: int) -> Dictionary:
	var k := floorf(combo / 10.0) * 0.01
	return {"luck": k}
