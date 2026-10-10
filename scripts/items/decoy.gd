extends Node2D
## DECOY: every 20s a decoy drops. Nearby threats chase it, then it explodes.

const Pix = preload("res://scripts/fx/pix.gd")
const ItemArt = preload("res://scripts/fx/item_art.gd")

var player
var tick_t := 0.0
var timer := 4.0
var active := false
var pos := Vector2.ZERO
var life := 0.0
var max_life := 4.0
var t := 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 3


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if active:
		life -= delta
		if life < 1.6:   # the last moments tick, faster as it goes
			tick_t -= delta
			if tick_t <= 0.0:
				tick_t = maxf(0.08, life * 0.28)
				Sfx.play("it_decoy_tick", 1.0 + (1.6 - life) * 0.3, -9.0, 0.0)
		if life <= 0.0:
			_explode()
		return
	timer -= delta
	if timer <= 0.0:
		timer = 20.0 * player.item_cd()
		active = true
		max_life = 4.0 * player.duration_mult
		life = max_life
		pos = player.global_position
		tick_t = 0.0
		Global.game.ifx("drop", pos, Global.C_ORANGE, 90.0, 0.6)
		Sfx.play("it_decoy_drop", 1.0, -3.0, 0.0)


func _explode() -> void:
	active = false
	var r: float = 180.0 * player.area()
	Global.game.ifx("boom", pos, Global.C_ORANGE, r, 0.75)
	Global.game.shake(0.25)
	Sfx.play("it_decoy_blast", 1.0, -2.0, 0.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		var off: Vector2 = e.global_position - pos
		if off.length() < r + e.radius:
			var d = player.calc_damage(40.0 + 8.0 * player.level, "decoy", e)
			e.take_damage(d[0], off.normalized() * 400.0, d[1])


func _draw() -> void:
	if not active:
		return
	var frac := clampf(life / max_life, 0.0, 1.0)
	var hot := life < 1.6 and int(life * 8.0) % 2 == 0   # blinks faster-looking as the fuse burns down
	var col := Color.WHITE if hot else Global.C_ORANGE
	ItemArt.zone(self, pos, 180.0 * player.area(), Global.C_ORANGE, 0.45 + 0.35 * (1.0 - frac), t * 1.5, 16, 0.04 + 0.06 * (1.0 - frac))
	ItemArt.shadow(self, pos + Vector2(0, 16), 14.0, 0.4)
	var jit := Vector2(roundf(sin(t * 40.0)) * (2.0 if life < 1.6 else 0.0), 0.0)   # shudders just before it goes
	var bob := roundf(sin(t * 4.0)) * 2.0
	if not ItemArt.icon(self, "decoy", pos + Vector2(0, -4.0 + bob) + jit, 2.0):
		Pix.rect(self, pos - Vector2(12, 12), Vector2(24, 24), Global.C_ORANGE)
	# a hologram flicker: a scanline sweeps down the target
	var sy := fposmod(t * 40.0, 36.0) - 22.0
	Pix.rect(self, pos + Vector2(-16, sy + bob), Vector2(32, 2), Color(Global.C_ORANGE, 0.5))
	# the fuse: a pixel arc that shrinks around it
	Pix.arc(self, pos + Vector2(0, -4.0), 26.0, -PI / 2.0, -PI / 2.0 + TAU * frac, col, 2.0)


## HUD: full while a decoy is out, then the time left until the next one.
func cd_frac() -> float:
	if active:
		return 1.0
	return clampf(timer / (20.0 * player.item_cd()), 0.0, 1.0)


func is_active() -> bool:
	return active
