extends Node2D
## DRONE: a companion that orbits the player and shoots the nearest threat.

const ProjectileScript = preload("res://scripts/projectile.gd")
const Pix = preload("res://scripts/fx/pix.gd")
const ItemArt = preload("res://scripts/fx/item_art.gd")

var player
var flash := 0.0
var angle := 0.0
var timer := 1.0
var t := 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 6


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 8.0)
	angle += delta * 2.2
	global_position = player.global_position + Vector2.from_angle(angle) * 70.0 + Vector2(0, sin(t * 3.0) * 6.0)
	queue_redraw()
	timer -= delta
	if timer > 0.0:
		return
	var best = null
	var best_d := 520.0 * 520.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_squared_to(global_position)
		if d < best_d and Global.game.can_hit(global_position, e):
			best_d = d
			best = e
	if best == null:
		return
	timer = 0.7 * player.item_cd()
	flash = 1.0
	Sfx.play("it_drone_shot", 1.0 + randf() * 0.15, -11.0, 0.12)
	var p = ProjectileScript.new()
	p.position = global_position
	p.velocity = (best.global_position - global_position).normalized() * 600.0
	p.base_damage = 6.0 + 1.2 * player.level
	p.weapon_id = "drone"
	p.pierce = 1 + player.extra_pierce
	player.get_parent().add_child(p)


func _draw() -> void:
	var col := Global.C_GREEN
	ItemArt.shadow(self, Vector2(0, 22), 9.0, 0.22)
	if not ItemArt.icon(self, "drone", Vector2.ZERO, 2.0):
		Pix.dot(self, Vector2.ZERO, col, 14.0)
	# four rotor discs: a blur of two alternating pixel bars, so they read as spinning
	var spin := int(t * 30.0) % 2
	for k in 4:
		var c := Vector2(-14.0 if k % 2 == 0 else 14.0, -10.0 if k < 2 else 10.0)
		if spin == 0:
			Pix.rect(self, c + Vector2(-6, -1), Vector2(12, 2), Color(Color.WHITE, 0.55))
		else:
			Pix.rect(self, c + Vector2(-4, -3), Vector2(8, 2), Color(Color.WHITE, 0.55))
			Pix.rect(self, c + Vector2(-4, 1), Vector2(8, 2), Color(Color.WHITE, 0.55))
	# the target light blinks along the underside
	if fposmod(t, 0.8) < 0.4:
		Pix.dot(self, Vector2(0, 4), Color(Global.C_RED, 0.9), 2.0)
	if flash > 0.0:   # muzzle flash
		Pix.dither_disc(self, Vector2(0, 8), 8.0 * flash + 2.0, Color(Color.WHITE, flash))
