extends Node2D
const SpriteFx = preload("res://scripts/fx/sprite_fx.gd")
## PING.EXE: chain lightning that jumps between nearby enemies.

var level := 1
var timer := 0.5
var player


func _ready() -> void:
	player = get_parent()


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	var candidates := []
	for e in enemies:
		if e.global_position.distance_to(player.global_position) < 430.0 and Global.game.can_hit(player.global_position, e):
			candidates.append(e)
	if candidates.is_empty():
		return
	timer = maxf(0.4, 1.6 - 0.1 * level) * player.cooldown_mult

	var current = candidates.pick_random()
	var points := [player.global_position, current.global_position]
	var hit := [current]
	var jumps: int = 2 + level + player.extra_proj
	for j in jumps:
		var best = null
		var best_d := 170.0 * 170.0
		for e in enemies:
			if hit.has(e):
				continue
			var d: float = e.global_position.distance_squared_to(current.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		hit.append(best)
		points.append(best.global_position)
		current = best

	Global.game.lightning(points, Color(0.55, 0.85, 1.0), "ping")
	for e in hit:
		SpriteFx.play("ping_hit", e.global_position)
		var d = player.calc_damage(9.0 + 4.0 * level, "zap", e)
		e.take_damage(d[0], Vector2.ZERO, d[1])
	Sfx.play("weapon_ping", randf_range(0.95, 1.08))
