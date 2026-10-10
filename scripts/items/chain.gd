extends Node
## CHAIN REACTION: critical hits arc lightning to nearby threats.

var player
var cooldown := 0.0
var busy := false


func _ready() -> void:
	player = get_parent()


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


func on_crit(target) -> void:
	if busy or cooldown > 0.0 or not is_instance_valid(target):
		return
	busy = true
	cooldown = 0.2 * player.item_cd()
	var points := [target.global_position]
	var hit := [target]
	var cur = target
	for j in 3:
		var best = null
		var best_d := 220.0 * 220.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit.has(e):
				continue
			var d: float = e.global_position.distance_squared_to(cur.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		hit.append(best)
		points.append(best.global_position)
		cur = best
	if hit.size() > 1:
		Global.game.lightning(points, Color(0.7, 0.5, 1.0))
		Sfx.play("it_chain", 1.0 + randf() * 0.2, -8.0, 0.08)
		for i in range(1, points.size()):
			Global.game.ifx("block", points[i], Color(0.75, 0.55, 1.0), 24.0, 0.25)
		for i in range(1, hit.size()):
			var e = hit[i]
			if is_instance_valid(e):
				var d = player.calc_damage(12.0 + 3.0 * player.level, "chain", e)
				e.take_damage(d[0], Vector2.ZERO, d[1])
	busy = false
