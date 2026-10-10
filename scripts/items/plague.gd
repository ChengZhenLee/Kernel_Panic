extends Node
## PLAGUE VECTOR: threats that die poisoned infect everything near them with poison. +10% poison chance.

var player
var ring_cd := 0.0


func _ready() -> void:
	player = get_parent()
	player.status_chance["poison"] += 10.0


func on_kill(e) -> void:
	if not e.status.has("poison"):
		return
	var pos: Vector2 = e.global_position
	var r: float = 170.0 * player.area()
	var now := Time.get_ticks_msec() / 1000.0
	if now >= ring_cd:
		ring_cd = now + 0.15
		Global.game.ifx("spore", pos, Color(0.5, 1.0, 0.3), r, 0.55)
		Sfx.play("it_plague", 1.0 + randf() * 0.2, -9.0, 0.1)
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == e or not is_instance_valid(o) or not o.has_method("apply_status"):
			continue
		if o.global_position.distance_to(pos) < r + o.radius:
			for i in 2:
				o.apply_status("poison", 16.0 + 3.0 * player.level)
