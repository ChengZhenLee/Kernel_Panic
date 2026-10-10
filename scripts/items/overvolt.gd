extends Node
## OVERVOLT: shocked threats arc lightning to their neighbours, spreading the shock. +10% shock chance.

var player
var timer := 1.0


func _ready() -> void:
	player = get_parent()
	player.status_chance["shock"] += 10.0


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	var shocked := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.status.has("shock") and e.global_position.distance_to(player.global_position) < 560.0:
			shocked.append(e)
	if shocked.is_empty():
		return
	timer = 1.1 * player.item_cd()
	shocked.shuffle()
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in shocked.slice(0, 3):
		if not is_instance_valid(e):
			continue
		var best = null
		var best_d := 200.0 * 200.0
		for o in enemies:
			if o == e or not is_instance_valid(o) or o.status.has("shock"):
				continue
			var d: float = o.global_position.distance_squared_to(e.global_position)
			if d < best_d:
				best_d = d
				best = o
		var pts := [e.global_position]
		if best != null:
			pts.append(best.global_position)
		Global.game.lightning(pts if pts.size() > 1 else [e.global_position, e.global_position + Vector2(0, -50)], Color(1.0, 0.95, 0.3))
		Sfx.play("it_chain", 1.2 + randf() * 0.2, -11.0, 0.12)
		Global.game.ifx("block", e.global_position, Color(1.0, 0.95, 0.3), 22.0, 0.25)
		var d = player.calc_damage(14.0 + 4.0 * player.level, "overvolt", e)
		e.take_damage(d[0], Vector2.ZERO, d[1])
		if best != null and is_instance_valid(best) and best.has_method("apply_status"):
			best.apply_status("shock", d[0])
