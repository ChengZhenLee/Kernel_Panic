extends Node
## SWARM SHIELD: armor grows with the number of threats close to you (up to +8).

var player
var timer := 0.0
var applied := 0.0


func _ready() -> void:
	player = get_parent()


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = 0.25
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_squared_to(player.global_position) < 240.0 * 240.0:
			n += 1
	var bonus := minf(8.0, n / 5.0)
	if absf(bonus - applied) > 0.05:
		player.armor += bonus - applied
		applied = bonus
