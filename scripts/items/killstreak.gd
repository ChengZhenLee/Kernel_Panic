extends Node
## KILLSTREAK: every 50th kill sends out a powerful shockwave.

var player
var count := 0


func _ready() -> void:
	player = get_parent()


func on_kill(_e = null) -> void:
	count += 1
	if count < 50:
		return
	count = 0
	var pos: Vector2 = player.global_position
	var r: float = 340.0 * player.area()
	Global.game.ifx("nova", pos, Global.C_GOLD, r, 0.7, 4.0)
	Global.game.shake(0.3)
	Sfx.play("it_killstreak", 1.0, -3.0, 0.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_boss:
			continue
		var off: Vector2 = e.global_position - pos
		if off.length() < r + e.radius:
			var d = player.calc_damage(40.0 + 8.0 * player.level, "killstreak", e)
			e.take_damage(d[0], off.normalized() * 500.0, d[1])


## HUD: kills left until the next shockwave, as a fraction.
func cd_frac() -> float:
	return 1.0 - count / 50.0
