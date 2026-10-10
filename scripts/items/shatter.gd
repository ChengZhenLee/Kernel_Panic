extends Node
## COLD SNAP: threats that die frozen shatter, freezing and damaging everything around them. +10% freeze chance.

const CHAIN_LIMIT := 5

var player
var recent := 0.0
var chain := 0


func _ready() -> void:
	player = get_parent()
	player.status_chance["freeze"] += 10.0


func _process(delta: float) -> void:
	recent = maxf(0.0, recent - delta)
	if recent <= 0.0:
		chain = 0


func on_kill(e) -> void:
	if not e.status.has("freeze") or chain >= CHAIN_LIMIT:
		return
	chain += 1
	recent = 1.0
	var pos: Vector2 = e.global_position
	var r: float = 150.0 * player.area()
	Global.game.ifx("shatter", pos, Color(0.5, 0.9, 1.0), r, 0.5)
	Sfx.play("it_shatter", 1.0 + randf() * 0.2, -9.0, 0.09)
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == e or not is_instance_valid(o):
			continue
		if o.global_position.distance_to(pos) < r + o.radius:
			var d = player.calc_damage(12.0 + 3.5 * player.level, "shatter", o)
			o.take_damage(d[0], Vector2.ZERO, d[1])
			if is_instance_valid(o) and o.has_method("apply_status"):
				o.apply_status("freeze", d[0])
