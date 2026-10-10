extends Node
## RECYCLER: kills have a 2% chance to drop a repair patch.


func on_kill(e = null) -> void:
	if e != null and randf() < 0.02:
		Global.game._drop("heal", e.global_position, 1)
