extends Node2D
## BACKDOOR: opens a door behind a threat; a boomerang flies out of it toward you and hits the threat in the back.

const Pix = preload("res://scripts/fx/pix.gd")
const WFx = preload("res://scripts/fx/weapon_fx.gd")
const SpriteFx = preload("res://scripts/fx/sprite_fx.gd")
const OPEN_TIME := 0.25   # the door fades in this long before the boomerang is thrown
const FADE_TIME := 0.25
const DOOR_SCALE := 3.0   # the 16 px door icon at a whole multiple, so its pixels stay crisp
const TURN_RATE := 4.5    # rad/s the boomerang can bend toward you (the curve of its flight)

var level := 1
var timer := 0.5
var player
var doors := []  # {pos, age, phase (0 opening, 1 flying, 2 fading), bpos, bvel, life, hits}
var clock := 0.0
var trail := {}   # door -> its last boomerang positions


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5


func _process(delta: float) -> void:
	queue_redraw()
	clock += delta
	timer -= delta
	var enemies := get_tree().get_nodes_in_group("enemies")
	var reach: float = (260.0 + level * 12.0) * player.area()
	if timer <= 0.0 and doors.is_empty():
		_fire(enemies, reach)
	var arena = Global.game.arena
	for d in doors.duplicate():
		d["age"] += delta
		match d["phase"]:
			0:
				if d["age"] >= OPEN_TIME:
					d["phase"] = 1
					d["bpos"] = d["pos"]
					d["bvel"] = (player.global_position - d["pos"]).normalized() * 520.0 * player.proj_speed
					Sfx.play("shoot", 0.7, -6.0)
			1:
				d["life"] -= delta
				var to_p: Vector2 = player.global_position - d["bpos"]
				var speed: float = d["bvel"].length()
				var want := to_p.angle()
				var cur: float = d["bvel"].angle()
				d["bvel"] = Vector2.from_angle(cur + clampf(angle_difference(cur, want), -TURN_RATE * delta, TURN_RATE * delta)) * speed
				d["bpos"] += d["bvel"] * delta
				d["trail"].push_front(d["bpos"])
				if d["trail"].size() > 10:
					d["trail"].pop_back()
				var dist := to_p.length()
				var passed: bool = dist < 150.0 and dist > d["last"]   # it flew by you and is moving away again: done, not orbiting
				d["last"] = dist
				if dist < 20.0 or passed or d["life"] <= 0.0 or (arena != null and arena.point_blocked(d["bpos"])):
					d["phase"] = 2
					d["age"] = 0.0
					continue
				for e in enemies:
					if is_instance_valid(e) and e.global_position.distance_to(d["bpos"]) < 16.0 * player.proj_size() + e.radius and Global.game.can_hit(d["bpos"], e):
						var id: int = e.get_instance_id()
						if clock - d["hits"].get(id, -10.0) > 0.35:
							d["hits"][id] = clock
							var dm = player.calc_damage(14.0 + 5.0 * level, "backdoor", e)
							e.take_damage(dm[0], d["bvel"].normalized() * 120.0, dm[1])
							SpriteFx.play("backdoor_slash", e.global_position)
			2:
				if d["age"] >= FADE_TIME:
					doors.erase(d)


## Opens a door behind each of the nearest threats in reach (on the line from you through the threat); none in reach = try again soon.
func _fire(enemies: Array, reach: float) -> void:
	var cands := []
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(player.global_position) < reach:
			cands.append(e)
	if cands.is_empty():
		timer = 0.3
		return
	timer = maxf(0.5, 1.8 - 0.12 * level) * player.cooldown_mult
	var origin: Vector2 = player.global_position
	cands.sort_custom(func(a, b): return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	var count: int = 1 + int(level / 3.0) + player.extra_proj
	var arena = Global.game.arena
	for e in cands:
		if doors.size() >= count:
			break
		var away: Vector2 = (e.global_position - origin).normalized()
		var spot := Vector2.ZERO
		var ok := false
		for gap in [50.0, 36.0, 24.0]:   # not inside a wall: back off toward the threat until the spot is open
			spot = e.global_position + away * (e.radius + gap)
			if arena == null or not arena.point_blocked(spot):
				ok = true
				break
		if ok:
			doors.append({"pos": spot, "age": 0.0, "phase": 0, "bpos": spot, "bvel": Vector2.ZERO, "life": 2.0, "last": 1e9, "trail": [], "hits": {}})
	if doors.is_empty():
		timer = 0.3
	else:
		Sfx.play("shoot", 0.5, -8.0)


func _draw() -> void:
	# a glitchy pixel door behind the target, then a spinning boomerang with a green trail comes out of it (pixel-snapped)
	var g := Color("#b46cff")   # purple main (name kept from the old green version)
	var sz: float = player.proj_size()
	for d in doors:
		var a := 1.0
		var open := 1.0
		if d["phase"] == 0:
			open = clampf(d["age"] / OPEN_TIME, 0.0, 1.0)
			a = open
		elif d["phase"] == 2:
			open = 1.0 - clampf(d["age"] / FADE_TIME, 0.0, 1.0)
			a = open
		var p: Vector2 = d["pos"]
		if WFx.has("backdoor_door"):   # the glitching door sprite: frames 0-3 swing open, 4-7 idle
			var fr := mini(3, int(open * 3.99)) if d["phase"] == 0 else 4 + int(clock * 12.0) % 4
			WFx.draw(self, "backdoor_door", fr, p, Vector2(28, 44), 1.0, Color(1, 1, 1, a))
		else:
			var w := roundi(12.0 * open)
			if w > 0:
				var f := int(clock * 12.0)
				var x0 := -w / 2   # integer half width
				Pix.rect(self, p + Vector2(x0, -18), Vector2(w, 36), Color(Color("#7a3ad6"), a * 0.9))
				for y in range(-18, 18):   # glitch scanlines
					if Pix.rnd(y + f) > 0.8:
						Pix.rect(self, p + Vector2(x0, y), Vector2(w, 1), Color(g, 0.8 * a))
				var edge := Color(Color("#e0c2ff"), a)
				Pix.rect(self, p + Vector2(x0 - 1, -19), Vector2(w + 2, 1), edge)
				Pix.rect(self, p + Vector2(x0 - 1, 18), Vector2(w + 2, 1), edge)
				Pix.rect(self, p + Vector2(x0 - 1, -19), Vector2(1, 38), edge)
				Pix.rect(self, p + Vector2(x0 + w, -19), Vector2(1, 38), edge)
				if w > 8:
					Pix.dot(self, p + Vector2(3, 0), Color("#ffd23a", a), 3.0)
		if d["phase"] == 1:
			var tr: Array = d["trail"]
			for k in tr.size():
				Pix.dot(self, tr[k], Color(g, (1.0 - float(k) / tr.size()) * 0.7), 2.0)
			var b: Vector2 = d["bpos"]
			if WFx.has("backdoor_boomerang"):
				WFx.draw(self, "backdoor_boomerang", WFx.at(clock, 0, 24.0), b, Vector2(24, 24), 2.0 if sz >= 1.5 else 1.0)
			else:
				var rot: float = clock * 14.0
				for k in 2:
					var an := rot + k * PI
					var tip := b + Vector2.from_angle(an) * 8.0 * sz
					Pix.line(self, b, tip, Color("#e0c2ff"), 3.0)
					Pix.line(self, tip, tip + Vector2.from_angle(an + 1.2) * 8.0 * sz, g, 2.0)
				Pix.dot(self, b, Color.WHITE, 4.0)
