extends Node
## BACKFIRE: getting hit releases a damaging shockwave around you.

var player
var cooldown := 0.0
var cooldown_total := 1.0


func _ready() -> void:
	player = get_parent()


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


func on_hurt(_arg = null) -> void:
	if cooldown > 0.0:
		return
	cooldown_total = 1.0 * player.item_cd()
	cooldown = cooldown_total
	var pos: Vector2 = player.global_position
	var r: float = 210.0 * player.area()
	Global.game.ifx("shock", pos, Global.C_ORANGE, r, 0.5)
	Sfx.play("it_backfire", 1.0, -4.0, 0.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		var off: Vector2 = e.global_position - pos
		if off.length() < r + e.radius:
			var d = player.calc_damage(25.0 + 5.0 * player.level, "backfire", e)
			e.take_damage(d[0], off.normalized() * 450.0, d[1])


## HUD: 0 = ready, 1 = just used.
func cd_frac() -> float:
	return clampf(cooldown / cooldown_total, 0.0, 1.0)
