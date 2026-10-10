extends Node2D
## LOGIC MINE: drops proximity mines behind you that detonate in a big blast.
const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")
const SpriteFx = preload("res://scripts/fx/sprite_fx.gd")

var level := 1
var timer := 1.0
var player
var clock := 0.0
var mines := []  # [pos, arm_time, life]
var blasts := []  # [pos, age, radius]: the pixel blast animation of a mine that went off (visual only)
const BLAST_TIME := 0.45


func _ready() -> void:
	player = get_parent()
	z_index = 0   # was -1: under the opaque floor game.gd draws at z 0, so mines were hidden
	top_level = true  # draw mines in world space, not attached to the player


func blast_radius() -> float:
	return (70.0 + level * 9.0) * player.area()


func _process(delta: float) -> void:
	queue_redraw()
	clock += delta
	for b in blasts.duplicate():
		b[1] += delta
		if b[1] >= BLAST_TIME:
			blasts.erase(b)
	timer -= delta
	var max_mines: int = 3 + level + player.extra_proj
	if timer <= 0.0 and mines.size() < max_mines:
		timer = maxf(0.6, 2.2 - 0.15 * level) * player.cooldown_mult
		mines.append([player.global_position, 0.5, 12.0 * player.duration_mult])
	var enemies := get_tree().get_nodes_in_group("enemies")
	for m in mines.duplicate():
		m[1] -= delta
		m[2] -= delta
		var boom: bool = m[2] <= 0.0
		if m[1] <= 0.0 and not boom:
			for e in enemies:
				if e.global_position.distance_to(m[0]) < 40.0 + e.radius and Global.game.can_hit(m[0], e):
					boom = true
					break
		if boom:
			_explode(m[0], enemies)
			mines.erase(m)


func _explode(pos: Vector2, enemies: Array) -> void:
	var r := blast_radius()
	blasts.append([pos, 0.0, r])   # drawn in pixels below (replaces the smooth ring and particle burst)
	SpriteFx.play("mine_blast", pos, 1.0 if r < 115.0 else 2.0)
	Global.game.shake(0.08)
	Sfx.play("explode", 1.6, -8.0, 0.06)
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(pos) < r + e.radius and Global.game.can_hit(pos, e):   # walls shield
			var d = player.calc_damage(22.0 + 9.0 * level, "mines", e)
			e.take_damage(d[0], (e.global_position - pos).normalized() * 300.0, d[1])


func _draw() -> void:
	# the mine: a blinking box with orange studs; the blast: white flash, dithered orange shockwave, ring and flying pixel sparks (pixel-snapped)
	for m in mines:
		var p: Vector2 = m[0]
		var armed: bool = m[1] <= 0.0
		var lit: bool = (0.5 + 0.5 * sin(Time.get_ticks_msec() / 80.0)) > 0.5 and armed
		if WFx.has("mine_idle"):   # frames 0-3 arming (slow dim light), 4-7 armed (fast blink)
			WFx.draw(self, "mine_idle", (4 + WFx.at(clock, 0, 6.0) % 4) if armed else WFx.at(clock, 0, 3.0) % 4, p, Vector2(20, 22))
			continue
		# landmine: flat steel disc, darker centre plate, three pressure prongs with yellow tips, blinking red light, side studs
		var rim := Color("#8a93ac")
		Pix.dot(self, p + Vector2(0, 2), Color("#262d3e"), 17.0)   # shadow / underside
		Pix.dot(self, p, rim, 15.0)
		Pix.dot(self, p, Color("#4a5270"), 13.0)
		Pix.dot(self, p, Color("#262d3e"), 7.0)
		for x in [-4, 0, 4]:   # pressure prongs on top
			Pix.dot(self, p + Vector2(x, -8), rim, 2.0)
			Pix.dot(self, p + Vector2(x, -10), Color("#ffd23a"), 2.0)
		Pix.dot(self, p, Color("#ff3b3b") if lit else Color("#6a1a1a"), 3.0)
		for sx in [-8, 8]:   # side studs
			Pix.dot(self, p + Vector2(sx, 1), rim, 2.0)
	for b in blasts:
		var p: Vector2 = b[0]
		var sf: float = clampf(b[1] / BLAST_TIME, 0.0, 1.0)
		var br: float = maxf(4.0, b[2] * sf)
		Pix.dither_disc(self, p, br, Color(1.0, 0.69, 0.29, 0.5 * (1.0 - sf)))
		Pix.dither_disc(self, p, br * 0.6, Color(1.0, 0.35, 0.1, 0.35 * (1.0 - sf)))
		Pix.ring(self, p, br, Color(1.0, 0.88, 0.54, 1.0 - sf), 3.0, 300)
		Pix.ring(self, p, br - 3.0, Color(1.0, 0.48, 0.16, (1.0 - sf) * 0.7), 2.0, 300)


func ci_row(p: Vector2, col: Color) -> void:   # a 13 px edge of the mine box, one px thick
	for x in range(-6, 7):
		Pix.dot(self, p + Vector2(x, 0), col)


func ci_col(p: Vector2, col: Color) -> void:
	for y in range(-6, 7):
		Pix.dot(self, p + Vector2(0, y), col)
