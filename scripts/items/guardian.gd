extends Node2D
## GUARDIAN ORB: a big orb circles you, destroys enemy shots and damages threats it touches.

const Pix = preload("res://scripts/fx/pix.gd")
const ItemArt = preload("res://scripts/fx/item_art.gd")

var player
var trail := []
var trail_t := 0.0
var angle := 0.0
var clock := 0.0
var t := 0.0
var hit_times := {}


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 6


func _process(delta: float) -> void:
	t += delta
	clock += delta
	angle -= delta * 2.0
	var r: float = 115.0 * player.area()
	global_position = player.global_position + Vector2.from_angle(angle) * r
	queue_redraw()
	trail_t -= delta
	if trail_t <= 0.0:
		trail_t = 0.025
		trail.append(global_position)
		if trail.size() > 9:
			trail.pop_front()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if b.global_position.distance_to(global_position) < 26.0:
			Global.game.ifx("block", b.global_position, Global.C_CYAN, 18.0, 0.25)
			Sfx.play("it_guardian_block", 1.0 + randf() * 0.3, -9.0, 0.06)
			b.queue_free()
	if hit_times.size() > 300:
		hit_times.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < 22.0 + e.radius:
			var id: int = e.get_instance_id()
			if clock - hit_times.get(id, -10.0) > 0.5:
				hit_times[id] = clock
				var d = player.calc_damage(8.0 + 2.0 * player.level, "guardian", e)
				e.take_damage(d[0], (e.global_position - global_position).normalized() * 220.0, d[1])


func _draw() -> void:
	var col := Global.C_CYAN
	ItemArt.trail(self, trail, col, 6.0)
	Pix.dither_disc(self, Vector2.ZERO, 22.0, Color(col, 0.22 + 0.06 * sin(t * 6.0)))
	if not ItemArt.icon(self, "guardian", Vector2.ZERO, 2.0):
		Pix.dot(self, Vector2.ZERO, col, 24.0)
	# two rune brackets turning around the orb
	Pix.arc(self, Vector2.ZERO, 20.0, t * 3.0, t * 3.0 + 1.0, Color(Color.WHITE, 0.9), 2.0)
	Pix.arc(self, Vector2.ZERO, 20.0, t * 3.0 + PI, t * 3.0 + PI + 1.0, Color(Color.WHITE, 0.9), 2.0)
	Pix.ring(self, Vector2.ZERO, 22.0, Color(col, 0.35), 2.0)
