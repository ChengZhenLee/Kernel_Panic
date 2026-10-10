extends Node2D
## STRIKER: a companion that darts at the nearest threat, slicing it, then returns to you.

const Pix = preload("res://scripts/fx/pix.gd")
const ItemArt = preload("res://scripts/fx/item_art.gd")

var player
var trail := []
var trail_t := 0.0
var state := "idle"
var timer := 1.5
var target_pos := Vector2.ZERO
var facing := Vector2.RIGHT
var hit := {}
var t := 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 6
	global_position = player.global_position


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	var home: Vector2 = player.global_position + Vector2.from_angle(t * 2.5 + PI) * 50.0
	var before := global_position
	match state:
		"idle":
			global_position = global_position.move_toward(home, 500.0 * delta)
			timer -= delta
			if timer <= 0.0:
				var best = null
				var best_d := 480.0 * 480.0
				for e in get_tree().get_nodes_in_group("enemies"):
					var d: float = e.global_position.distance_squared_to(player.global_position)
					if d < best_d:
						best_d = d
						best = e
				if best == null:
					timer = 0.3
				else:
					state = "dash"
					Sfx.play("it_striker_dash", 1.0 + randf() * 0.1, -8.0, 0.1)
					target_pos = best.global_position + (best.global_position - global_position).normalized() * 120.0
					hit.clear()
		"dash":
			global_position = global_position.move_toward(target_pos, 900.0 * delta)
			for e in get_tree().get_nodes_in_group("enemies"):
				# check the whole path travelled this frame so fast dashes cannot skip over a target
				var near: Vector2 = Geometry2D.get_closest_point_to_segment(e.global_position, before, global_position)
				if near.distance_to(e.global_position) < 24.0 + e.radius:
					var id: int = e.get_instance_id()
					if not hit.has(id):
						hit[id] = true
						Global.game.ifx("block", e.global_position, Global.C_MAGENTA, 26.0, 0.25)
						var d = player.calc_damage(14.0 + 3.5 * player.level, "striker", e)
						e.take_damage(d[0], (e.global_position - global_position).normalized() * 150.0, d[1])
			if global_position.distance_to(target_pos) < 10.0:
				state = "return"
		"return":
			global_position = global_position.move_toward(home, 700.0 * delta)
			if global_position.distance_to(home) < 20.0:
				state = "idle"
				timer = 0.9 * player.item_cd()
	trail_t -= delta
	if trail_t <= 0.0:
		trail_t = 0.016 if state == "dash" else 0.05
		trail.append(global_position)
		if trail.size() > (14 if state == "dash" else 5):
			trail.pop_front()
	if global_position.distance_to(before) > 0.5:
		facing = (global_position - before).normalized()


func _draw() -> void:
	var col := Global.C_MAGENTA
	ItemArt.trail(self, trail, col if state == "dash" else Color(col, 0.5), 7.0 if state == "dash" else 4.0)
	if state == "dash":   # a slash streak behind the blade
		Pix.line(self, Vector2.ZERO, -facing * 30.0, Color(Color.WHITE, 0.8), 3.0)
		Pix.line(self, Vector2.ZERO, -facing * 20.0, Color(col, 0.9), 5.0)
	var bob := roundf(sin(t * 5.0)) * 2.0 if state == "idle" else 0.0
	if not ItemArt.icon(self, "striker", Vector2(0, bob), 2.0):
		Pix.dot(self, Vector2.ZERO, col, 12.0)
	if state == "dash":
		Pix.dither_disc(self, Vector2.ZERO, 14.0, Color(col, 0.45))
