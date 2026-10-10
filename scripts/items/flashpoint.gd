extends Node
## FLASHPOINT: threats that die while burning explode, igniting everything around them. +10% burn chance.

const CHAIN_LIMIT := 5   # explosions per second, so burning crowds cannot chain forever

var player
var recent := 0.0
var chain := 0


func _ready() -> void:
	player = get_parent()
	player.status_chance["burn"] += 10.0


func _process(delta: float) -> void:
	recent = maxf(0.0, recent - delta)
	if recent <= 0.0:
		chain = 0


func on_kill(e) -> void:
	if not e.status.has("burn") or chain >= CHAIN_LIMIT:
		return
	chain += 1
	recent = 1.0
	var pos: Vector2 = e.global_position
	var r: float = 140.0 * player.area()
	Global.game.ifx("blast", pos, Global.C_ORANGE, r, 0.45)
	Sfx.play("it_flashpoint", 1.0 + randf() * 0.2, -9.0, 0.09)
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == e or not is_instance_valid(o):
			continue
		if o.global_position.distance_to(pos) < r + o.radius:
			var d = player.calc_damage(14.0 + 3.0 * player.level, "flashpoint", o)
			o.take_damage(d[0], (o.global_position - pos).normalized() * 200.0, d[1])
			if is_instance_valid(o) and o.has_method("apply_status"):
				o.apply_status("burn", d[0])
