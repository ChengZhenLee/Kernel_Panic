extends Node2D
## COLLECTOR BOT: a companion that flies out and sends distant XP gems to you.

const Pix = preload("res://scripts/fx/pix.gd")
const ItemArt = preload("res://scripts/fx/item_art.gd")

var player
var trail := []
var trail_t := 0.0
var target = null
var t := 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 6
	global_position = player.global_position


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if target != null and (not is_instance_valid(target) or target.attracted):
		target = null
	if target == null:
		var min_d: float = player.pickup_radius * 1.1
		var best_d := 900.0 * 900.0
		for gem in get_tree().get_nodes_in_group("gems"):
			if gem.attracted:
				continue
			var d: float = gem.global_position.distance_squared_to(player.global_position)
			if d < best_d and d > min_d * min_d:
				best_d = d
				target = gem
	var goal: Vector2 = player.global_position + Vector2.from_angle(t * 1.6) * 55.0
	if target != null:
		goal = target.global_position
	global_position = global_position.move_toward(goal, 420.0 * delta)
	trail_t -= delta
	if trail_t <= 0.0:
		trail_t = 0.03
		trail.append(global_position)
		if trail.size() > 7:
			trail.pop_front()
	if target != null and global_position.distance_to(goal) < 18.0:
		Global.game.ifx("block", target.global_position, Global.C_CYAN, 22.0, 0.25)
		Sfx.play("it_collector", 1.0 + randf() * 0.2, -9.0, 0.08)
		target.attracted = true
		target = null


func _draw() -> void:
	var col := Global.C_CYAN
	ItemArt.trail(self, trail, col, 4.0)
	if target != null and is_instance_valid(target):   # a tractor line of pixels reaching for the gem
		var to: Vector2 = to_local(target.global_position)
		var n := maxi(2, int(to.length() / 10.0))
		for i in n:
			var f := fposmod(float(i) / n - t * 1.5, 1.0)
			Pix.dot(self, to * f, Color(col, 0.8 * (1.0 - f)), 2.0)
	var bob := roundf(sin(t * 6.0)) * 2.0
	ItemArt.shadow(self, Vector2(0, 18), 10.0, 0.25)
	if not ItemArt.icon(self, "collector", Vector2(0, bob), 2.0):
		Pix.dot(self, Vector2(0, bob), col, 14.0)
	var blink := fposmod(t, 2.4) < 0.12   # the visor blinks
	if blink:
		Pix.rect(self, Vector2(-8, -6 + bob), Vector2(16, 4), Color(0.3, 0.33, 0.4))
