extends Node
## TROPHY CACHE: every 100 kills after picking it up adds +3% damage, up to +45% (15 stacks).

const PER_STACK := 3.0
const MAX_STACKS := 15

var player
var count := 0
var stacks := 0


func _ready() -> void:
	player = get_parent()


func on_kill(_e = null) -> void:
	if stacks >= MAX_STACKS:
		return
	count += 1
	if count < 100:
		return
	count = 0
	stacks += 1
	player.add_bonus("dmg", PER_STACK)
	Global.game.float_text(player.global_position + Vector2(0, -50), "+%d%% DMG" % int(PER_STACK), Global.C_GOLD, 24, 1.0)


## HUD: progress towards the next stack (0 = just stacked, full = far away); 0 when maxed.
func cd_frac() -> float:
	return 0.0 if stacks >= MAX_STACKS else 1.0 - count / 100.0
