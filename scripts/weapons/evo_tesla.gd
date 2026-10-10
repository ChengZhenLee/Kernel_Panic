extends Node2D
## TESLA GRID (evolution of PING.EXE + SCANNER + CHAIN REACTION): lightning hits many threats at once, shocks them and arcs on.

const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")
const STRIKE_FRAMES := 10

var level := 1
var timer := 0.4
var player
var clock := 0.0
var hit_marks := []        # [world pos, age]: the bolt-and-grid sheet on every threat the grid hits
var layer: Node2D        # draws the strikes above the threats (this node itself draws the coil under the player)


func _ready() -> void:
	player = get_parent()
	show_behind_parent = true   # the coil sits under the player sprite
	layer = Node2D.new()
	layer.z_index = 4
	layer.draw.connect(_draw_strikes)
	add_child(layer)


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
	layer.queue_redraw()
	for st in hit_marks.duplicate():
		st[1] += delta
		if st[1] >= STRIKE_FRAMES / WFx.FPS:
			hit_marks.erase(st)
	timer -= delta
	if timer > 0.0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	var near := []
	for e in enemies:
		var d: float = e.global_position.distance_to(player.global_position)
		if d < 460.0 and Global.game.can_hit(player.global_position, e):
			near.append([d, e])
	if near.is_empty():
		return
	timer = maxf(0.35, 1.1 - 0.05 * level) * player.cooldown_mult
	near.sort_custom(func(a, b): return a[0] < b[0])
	var strikes := mini(near.size(), 3 + int(level / 2) + int(player.extra_proj))
	var hit := []
	for i in strikes:
		var current = near[i][1]
		var points := [player.global_position, current.global_position]
		hit.append(current)
		for j in 2:
			var best = null
			var best_d := 180.0 * 180.0
			for e in enemies:
				if hit.has(e):
					continue
				var d: float = e.global_position.distance_squared_to(current.global_position)
				if d < best_d:
					best_d = d
					best = e
			if best == null:
				break
			hit.append(best)
			points.append(best.global_position)
			current = best
		Global.game.lightning(points, Color(0.6, 0.9, 1.0), "tesla")
	for e in hit:
		if not is_instance_valid(e):
			continue
		if hit_marks.size() < 24:
			hit_marks.append([e.global_position, 0.0])
		var d = player.calc_damage(12.0 + 5.0 * level, "evo_tesla", e)
		e.take_damage(d[0], Vector2.ZERO, d[1])
		if is_instance_valid(e) and e.has_method("apply_status"):
			e.apply_status("shock", d[0])
	Sfx.play("weapon_tesla", randf_range(0.9, 1.05))


func _draw() -> void:
	# the emitter glyph under your feet: four pylons arcing round a pulsing core (assets/fx/weapons/evo_tesla_coil.png)
	WFx.draw(self, "evo_tesla_coil", WFx.at(clock, 0, 8.0), Vector2(0, 12), Vector2(48, 48))


func _draw_strikes() -> void:
	for st in hit_marks:
		WFx.draw(layer, "evo_tesla_strike", int(st[1] * WFx.FPS), layer.to_local(st[0]), Vector2(56, 160), 1.0, Color(1, 1, 1, 0.8))
