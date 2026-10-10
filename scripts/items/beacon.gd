extends Node2D
## REPAIR BEACON: every 25s a beacon drops and heals you while you stand near it.

const Pix = preload("res://scripts/fx/pix.gd")
const ItemArt = preload("res://scripts/fx/item_art.gd")

var player
var timer := 6.0
var beacons := []   # [pos, life]
var t := 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 0   # was -1: under the floor game.gd draws at z 0


func radius() -> float:
	return 150.0 * player.area()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	timer -= delta
	if timer <= 0.0:
		timer = 25.0 * player.item_cd()
		beacons.append([player.global_position, 8.0 * player.duration_mult])
		Global.game.ifx("drop", player.global_position, Global.C_GREEN, radius(), 0.7)
		Sfx.play("it_beacon_drop", 1.0, -3.0, 0.0)
	var r := radius()
	for b in beacons.duplicate():
		b[1] -= delta
		if player.global_position.distance_to(b[0]) < r:
			player.heal(player.max_hp * 0.015 * delta)
		if b[1] <= 0.0:
			beacons.erase(b)


func _draw() -> void:
	var r := radius()
	for b in beacons:
		var p: Vector2 = b[0]
		var fade := clampf(b[1], 0.0, 1.0)
		var near: bool = player.global_position.distance_to(p) < r
		ItemArt.zone(self, p, r, Global.C_GREEN, fade, t, 10, 0.06 + (0.05 if near else 0.0))
		ItemArt.shadow(self, p + Vector2(0, 14), 12.0, 0.4 * fade)
		if not ItemArt.icon(self, "beacon", p + Vector2(0, -8.0), 2.0, Color(1, 1, 1, fade)):
			Pix.rect(self, p + Vector2(-3, -12), Vector2(6, 24), Global.C_GREEN)
			Pix.rect(self, p + Vector2(-12, -3), Vector2(24, 6), Global.C_GREEN)
		# a slow pixel scan ring climbing the mast, and plus signs rising while the player stands in it
		Pix.ring(self, p + Vector2(0, -22.0), 6.0 + fposmod(t * 8.0, 10.0), Color(Global.C_GREEN, (1.0 - fposmod(t * 8.0, 10.0) / 10.0) * 0.7 * fade), 2.0)
		if near:
			for i in 3:
				var ph := fposmod(t * 0.8 + i * 0.33, 1.0)
				var q: Vector2 = player.global_position + Vector2((i - 1) * 12.0, -18.0 - ph * 34.0)
				var pa := (1.0 - ph) * fade
				Pix.rect(self, to_local(q) + Vector2(-1, -3), Vector2(2, 6), Color(Color.WHITE, pa))
				Pix.rect(self, to_local(q) + Vector2(-3, -1), Vector2(6, 2), Color(Global.C_GREEN, pa))


## HUD: 0 = about to drop, 1 = just dropped.
func cd_frac() -> float:
	return clampf(timer / (25.0 * player.item_cd()), 0.0, 1.0)
