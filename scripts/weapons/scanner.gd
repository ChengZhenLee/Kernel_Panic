extends Node2D
## SCANNER: rotating radar beams that sweep around you.
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
	z_index = 0   # was -1: under the floor game.gd draws at z 0


func beam_count() -> int:
	return 1 + int(level / 3.0)


func beam_length() -> float:
	return (170.0 + level * 16.0) * player.area()


func _process(delta: float) -> void:
	queue_redraw()
	clock += delta
	angle += (2.0 + 0.12 * level) * delta
	if hit_times.size() > 800:
		hit_times.clear()
	var n := beam_count()
	var length := beam_length()
	for e in get_tree().get_nodes_in_group("enemies"):
		var off: Vector2 = e.global_position - player.global_position
		var dist := off.length()
		if dist > length + e.radius:
			continue
		for i in n:
			var dir := Vector2.from_angle(angle + TAU * i / n)
			var along := off.dot(dir)
			if along < 0.0:
				continue
			if absf(off.cross(dir)) < 10.0 + e.radius:
				var id: int = e.get_instance_id()
				if clock - hit_times.get(id, -10.0) > 0.3:
					hit_times[id] = clock
					var d = player.calc_damage(6.0 + 3.0 * level, "scanner", e)
					e.take_damage(d[0], dir.orthogonal() * 60.0, d[1])
					SpriteFx.play("scanner_blip", e.global_position)
					Sfx.play("weapon_scanner", randf_range(0.95, 1.1))
				break


func _draw() -> void:
	# radar sweep: hard white leading edge, a dithered afterglow behind it, dim range rings (pixel-snapped)
	var n := beam_count()
	var length := beam_length()
	var g := Color(0.25, 1.0, 0.54)
	Pix.ring(self, Vector2.ZERO, length, Color(g, 0.18), 2.0, 160)
	Pix.ring(self, Vector2.ZERO, length * 0.5, Color(g, 0.08), 2.0, 100)
	if WFx.has("scanner_hub"):   # the radar base turns with the sweep (assets/fx/weapons/scanner_hub.png)
		draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
		WFx.draw(self, "scanner_hub", WFx.at(clock, 0, 6.0), Vector2.ZERO, Vector2(32, 32))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rays := 10 if n <= 2 else 6
	for i in n:
		var a := angle + TAU * i / n
		for k in rays:   # afterglow: dashed rays behind the edge, fading
			var aa := a - (k + 1) * 0.06
			var u := Vector2.from_angle(aa)
			var rr := 6.0 + (k & 1) * 2.0
			while rr < length:
				Pix.dot(self, u * rr, Color(g, (1.0 - float(k) / rays) * 0.35), 2.0)
				rr += 6.0
		var e := Vector2.from_angle(a)
		Pix.line(self, e * 4.0, e * length, Color(g, 0.6), 4.0)
		Pix.line(self, e * 4.0, e * length, Color(0.85, 1.0, 0.91), 2.0)
