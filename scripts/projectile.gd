extends Node2D
## Data bolt fired by the Packet Gun.
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")
const SpriteFx = preload("res://scripts/fx/sprite_fx.gd")


var velocity := Vector2.ZERO
var base_damage := 10.0
var weapon_id := "laser"
var pierce := 1
var life := 1.4
var radius := 6.0
var size := 1.0   # weapon area scale (capped by the player)
var already_hit := {}
var age := 0.0


func _process(delta: float) -> void:
	age += delta
	position += velocity * delta
	queue_redraw()   # the pixel art snaps to the world grid, so it is redrawn as it moves
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if Global.game and Global.game.arena != null and Global.game.arena.point_blocked(global_position):
		queue_free()   # bolts stop at walls
		return
	var g = Global.game
	g.refresh_enemies()
	var en: Array = g.enemy_nodes
	var ep: PackedVector2Array = g.enemy_pos
	var er: PackedFloat64Array = g.enemy_rad
	var gp := global_position
	var reach := radius * size
	for i in en.size():
		if gp.distance_to(ep[i]) < reach + er[i]:
			var e = en[i]
			if already_hit.has(e):
				continue
			already_hit[e] = true
			var d = Global.game.player.calc_damage(base_damage, weapon_id, e)
			e.take_damage(d[0], velocity.normalized() * 160.0, d[1])
			Global.game.burst(global_position, Global.C_CYAN, 3, 120.0, 3.0, 0.2)
			SpriteFx.play("packet_hit", global_position)
			pierce -= 1
			if pierce <= 0:
				queue_free()
				return


## A pixel-art packet: a fading pixel tail, a cyan body with a white core and a bright head. The node is never rotated: the art is
## placed along the travel direction in world space (Pix snaps to the world grid), so it is redrawn as it moves.
func _draw() -> void:
	if WFx.has("packet_bolt"):   # the data-packet sprite (assets/fx/weapons/packet_bolt.png), pointing along the flight
		var dir := velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT
		draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
		WFx.draw(self, "packet_bolt", WFx.at(age), Vector2.ZERO, Vector2(44, 12), 1.0)   # always 1x: weapon area still widens the hit radius, the art stays small
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# a hard white core on a cyan body with a fading pixel tail (snapped to the world pixel grid, redrawn as it moves)
	var d := velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT
	var side := d.orthogonal()
	var sz: float = maxf(1.0, size)
	var cy := Color(0.29, 0.94, 1.0)
	var tail := int(14.0 * sz)
	for k in range(1, tail + 1):
		var a := 1.0 - float(k) / tail
		Pix.dot(self, -d * k, Color(cy, a * 0.7))
		if k < tail * 0.6:
			Pix.dot(self, -d * k + side, Color(cy, a * 0.3))
			Pix.dot(self, -d * k - side, Color(cy, a * 0.3))
	Pix.dot(self, Vector2.ZERO, cy, roundf(6.0 * sz))
	Pix.dot(self, d, Color(0.91, 1.0, 1.0), roundf(4.0 * sz))
	Pix.dot(self, d * 2.0 * sz, Color.WHITE, 2.0)
