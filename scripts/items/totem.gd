extends Node2D
## TOTEM: every 15s a totem drops at your feet and pulses damage around it for 6s.

const Pix = preload("res://scripts/fx/pix.gd")
const ItemArt = preload("res://scripts/fx/item_art.gd")

var player
var timer := 3.0
var totems := []   # [pos, life, tick]
var t := 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 0   # was -1: under the floor game.gd draws at z 0


func radius() -> float:
	return 120.0 * player.area()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	timer -= delta
	if timer <= 0.0:
		timer = 15.0 * player.item_cd()
		totems.append([player.global_position, 6.0 * player.duration_mult, 0.0])
		Global.game.ifx("drop", player.global_position, Global.C_RED, radius(), 0.7)
		Sfx.play("it_totem_drop", 1.0, -3.0, 0.0)
	var r := radius()
	for tm in totems.duplicate():
		tm[1] -= delta
		tm[2] -= delta
		if tm[2] <= 0.0:
			tm[2] = 0.5
			Global.game.ifx("pulse", tm[0], Global.C_RED, r, 0.4)
			Sfx.play("it_totem_pulse", 1.0, -8.0)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(tm[0]) < r + e.radius:
					var d = player.calc_damage(5.0 + 1.5 * player.level, "totem", e)
					e.take_damage(d[0], (e.global_position - tm[0]).normalized() * 40.0, d[1])
		if tm[1] <= 0.0:
			totems.erase(tm)


func _draw() -> void:
	var r := radius()
	for tm in totems:
		var p: Vector2 = tm[0]
		var fade := clampf(tm[1], 0.0, 1.0)
		var flash := clampf(tm[2] / 0.5, 0.0, 1.0)   # 1 right after a pulse
		ItemArt.zone(self, p, r, Global.C_RED, fade, t, 14, 0.07 + 0.08 * flash)
		ItemArt.shadow(self, p + Vector2(0, 14), 14.0, 0.4 * fade)
		var bob := roundf(sin(t * 3.0 + p.x) * 1.0) * 2.0
		if not ItemArt.icon(self, "totem", p + Vector2(0, bob - 10.0), 2.0, Color(1, 1, 1, fade)):
			Pix.rect(self, p + Vector2(-9, -2), Vector2(18, 14), Color(0.2, 0.05, 0.08))
			Pix.rect(self, p + Vector2(-6, -16), Vector2(12, 14), Global.C_RED)
		if flash > 0.5:   # a white flash across the carving right after each pulse
			Pix.dither_disc(self, p + Vector2(0, -14.0), 16.0, Color(Color.WHITE, (flash - 0.5) * 1.2))
		ItemArt.motes(self, p + Vector2(0, -26.0), Global.C_RED, fade, t + p.x * 0.01, p.x, 5, 12.0, 34.0)


## HUD: 0 = about to drop, 1 = just dropped.
func cd_frac() -> float:
	return clampf(timer / (15.0 * player.item_cd()), 0.0, 1.0)
