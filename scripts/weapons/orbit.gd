extends Node2D
## ENCRYPTION KEYS: crystal shards orbit you and shred anything they touch.
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")
const SpriteFx = preload("res://scripts/fx/sprite_fx.gd")


var level := 1
var angle := 0.0
var clock := 0.0
var hit_times := {}
var player


func _ready() -> void:
	player = get_parent()


func blade_count() -> int:
	return 1 + int(level / 2.0)


func orbit_radius() -> float:
	return (88.0 + level * 3.0) * player.area()


func _process(delta: float) -> void:
	queue_redraw()
	clock += delta
	angle += (2.6 + 0.22 * level) * delta
	if hit_times.size() > 600:
		hit_times.clear()
	var n := blade_count()
	var r := orbit_radius()
	for i in n:
		var blade_pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle + TAU * i / n) * r
		for e in get_tree().get_nodes_in_group("enemies"):
			if blade_pos.distance_to(e.global_position) < 14.0 + e.radius:
				var id: int = e.get_instance_id()
				if clock - hit_times.get(id, -10.0) > 0.45:
					hit_times[id] = clock
					var push: Vector2 = (e.global_position - player.global_position).normalized() * 260.0
					var d = player.calc_damage(10.0 + 4.5 * level, "orbit", e)
					e.take_damage(d[0], push, d[1])
					Sfx.play("weapon_keys", randf_range(0.9, 1.25))


func _draw() -> void:
	# pixel keys on a dotted orbit with a fading streak behind each, so the orbit direction reads (pixel-snapped)
	var n := blade_count()
	var r := orbit_radius()
	var mag := Color("#5df08a")      # green keys: main
	var streak := Color("#a8ffc4")   # highlight
	var dots := clampi(int(r * 0.7), 24, 120)
	for i in range(0, dots, 3):
		Pix.dot(self, Vector2.from_angle(TAU * i / dots) * r, Color(mag, 0.14))
	for i in n:
		var a := angle + TAU * i / n
		for k in range(1, 13):
			var aa := a - k * (0.07 * 26.0 / r * 1.5)
			Pix.dot(self, Vector2.from_angle(aa) * r, Color(streak, (1.0 - k / 12.0) * 0.7), 2.0)
		var c := Vector2.from_angle(a) * r
		if WFx.has("key_head"):   # the key sprite (assets/fx/weapons/key_head.png), pointing the way it travels
			draw_set_transform(c, a + PI / 2.0, Vector2.ONE)
			WFx.draw(self, "key_head", WFx.at(clock, i * 2), Vector2.ZERO, Vector2(24, 24))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var fwd := Vector2.DOWN.rotated(a)
		var out := Vector2.from_angle(a)
		for sh in range(-6, 7, 2):   # the shaft, white at the tip
			Pix.dot(self, c + fwd * sh, Color("#e6ffe9") if sh > 2 else mag, 2.0)
		Pix.dot(self, c - fwd * 9.0, mag, 6.0)
		Pix.dot(self, c - fwd * 9.0, Color("#2f8a4a"), 2.0)
		for t in 2:
			Pix.dot(self, c + fwd * (2.0 + t * 4.0) + out * 3.0, Color("#e6ffe9"), 2.0)
			Pix.dot(self, c + fwd * (2.0 + t * 4.0) + out * 5.0, mag, 2.0)
