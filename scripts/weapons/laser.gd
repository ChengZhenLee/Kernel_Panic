extends Node2D
## PACKET GUN: fires data bolts at the nearest threat. More bolts and pierce per level.

const ProjectileScript = preload("res://scripts/projectile.gd")
const RANGE := 620.0

var level := 1
var timer := 0.0
var player


func _ready() -> void:
	player = get_parent()


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	var target = _nearest_enemy()
	if target == null:
		return
	timer = maxf(0.18, 0.95 - 0.07 * level) * player.cooldown_mult

	var count: int = 1 + int(level / 3.0) + player.extra_proj
	var base_dir: Vector2 = (target.global_position - player.global_position).normalized()
	for i in count:
		var p = ProjectileScript.new()
		p.position = player.global_position
		p.velocity = base_dir.rotated((i - (count - 1) / 2.0) * 0.16) * 560.0 * player.proj_speed
		p.base_damage = 8.0 + 3.5 * level
		p.weapon_id = "laser"
		p.pierce = 1 + int(level / 4.0) + player.extra_pierce
		p.size = player.proj_size()
		player.get_parent().add_child(p)
	Sfx.play("shoot", randf_range(0.95, 1.1))   # weapon_packet.wav


func _nearest_enemy():
	var best = null
	var best_d := RANGE * RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_squared_to(player.global_position)
		if d < best_d and Global.game.can_hit(player.global_position, e):
			best_d = d
			best = e
	return best
