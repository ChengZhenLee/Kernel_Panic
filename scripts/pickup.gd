extends Node2D
const PixelArt = preload("res://scripts/pixel_art.gd")
const Pix = preload("res://scripts/fx/pix.gd")
## Things enemies drop: XP data bits, PATCH (heal), DEFRAG (magnet), and encrypted caches.

var kind := "xp"  # xp, heal, magnet, cache
var value := 1
var attracted := false
var fly_speed := 120.0
var t := 0.0
var player


func _ready() -> void:
	add_to_group("pickups")
	if kind == "xp":
		add_to_group("gems")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0   # was -1: that put every pickup under the opaque floor drawn by game.gd (art-v2)
	t = randf() * 5.0
	player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if player == null or not player.alive:
		return
	var d: float = global_position.distance_to(player.global_position)
	if not attracted and d < player.pickup_radius:
		attracted = true
	if attracted:
		fly_speed += 1100.0 * delta
		global_position = global_position.move_toward(player.global_position, fly_speed * delta)
		if d < player.radius + 6.0:
			if Global.game:
				Global.game.on_pickup(self)
			queue_free()


func _draw() -> void:
	var bob := sin(t * 4.0) * 2.0
	match kind:
		"xp":
			var col := Global.C_CYAN
			if value >= 10:
				col = Global.C_GOLD
			elif value >= 3:
				col = Global.C_GREEN
			var s := 4.0 + minf(value, 12) * 0.35
			_halo(bob, s * 2.2, col, 0.7)
			if _draw_sprite(bob, 14.0 + minf(value, 12) * 0.6):
				return
			draw_set_transform(Vector2(0, bob), t * 2.0, Vector2.ONE)
			draw_rect(Rect2(-s / 2.0, -s / 2.0, s, s), col)
			draw_rect(Rect2(-s / 4.0, -s / 4.0, s / 2.0, s / 2.0), Color(1, 1, 1, 0.8))
		"heal":
			_halo(bob, 18.0, Global.C_GREEN, 1.0)
			_sparks(bob, 15.0, Global.C_GREEN, 3)
			if _draw_sprite(bob, 26.0):
				return
			draw_rect(Rect2(-9, -3 + bob, 18, 6), Global.C_GREEN)
			draw_rect(Rect2(-3, -9 + bob, 6, 18), Global.C_GREEN)
		"magnet":
			_halo(bob, 20.0, Global.C_CYAN, 1.0)
			_sparks(bob, 17.0, Global.C_CYAN, 4)
			if _draw_sprite(bob, 28.0):
				return
			draw_arc(Vector2(0, bob), 9.0, PI, TAU, 16, Global.C_RED, 6.0)
			draw_rect(Rect2(-12, bob, 6, 6), Global.C_RED)
			draw_rect(Rect2(6, bob, 6, 6), Global.C_RED)
			draw_rect(Rect2(-12, bob + 6, 6, 4), Color.WHITE)
			draw_rect(Rect2(6, bob + 6, 6, 4), Color.WHITE)
		"purge":
			var glow := 0.5 + 0.5 * sin(t * 6.0)
			_halo(bob, 26.0, Global.C_GOLD, 1.0 + glow * 0.5)
			Pix.ring_auto(self, Vector2(0, bob), 20.0 + roundf(glow * 3.0) * 2.0, Color(Global.C_GOLD, 0.55), 2.0)
			_sparks(bob, 22.0, Global.C_GOLD, 6)
			if _draw_sprite(bob, 30.0 + glow * 4.0):
				return
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0 + t * 2.0)
				draw_line(Vector2(0, bob) + d * 7.0, Vector2(0, bob) + d * (15.0 if k % 2 == 0 else 11.0), Global.C_GOLD, 2.5)
			draw_circle(Vector2(0, bob), 5.0, Color.WHITE)
		"cache":
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			_halo(bob, 30.0, Global.C_GOLD, 1.0 + pulse * 0.5)
			Pix.ring_auto(self, Vector2(0, bob), 24.0 + roundf(pulse * 3.0) * 2.0, Color(Global.C_GOLD, 0.5), 2.0)
			_sparks(bob, 26.0, Global.C_GOLD, 5)
			Pix.rect(self, Vector2(-14, -22 + bob + roundf(fposmod(t * 1.5, 1.0) * 6.0)), Vector2(28, 2), Color(Color.WHITE, 0.3))   # a scanline crawling over the lid
			if _draw_sprite(bob, 34.0):
				return
			draw_rect(Rect2(-15, -11 + bob, 30, 22), Color(0.15, 0.1, 0.0))
			draw_rect(Rect2(-15, -11 + bob, 30, 22), Global.C_GOLD, false, 3.0)
			draw_rect(Rect2(-15, -3 + bob, 30, 4), Global.C_GOLD)
			draw_rect(Rect2(-3, -6 + bob, 6, 9), Color.WHITE)


## The pixel sprite for this pickup, size px square on top of the glow; false when there is none (the vector shape is drawn instead).
func _draw_sprite(bob: float, size: float) -> bool:
	var spr: Texture2D = PixelArt.pickup_tex(kind)
	if spr == null:
		return false
	draw_texture_rect(spr, Rect2(Vector2(-size, bob - size) * 0.5, Vector2(size, size)), false)
	return true


## A dithered checker halo under the sprite (hard-edged, no soft glow); r is the diameter in px.
func _halo(bob: float, r: float, col: Color, strength: float) -> void:
	Pix.dither_disc(self, Vector2(0, bob), r * 0.5, Color(col, clampf(0.2 * strength, 0.0, 0.5)))


## Square sparks orbiting the pickup (n of them), so the special pickups read as live objects.
func _sparks(bob: float, r: float, col: Color, n: int) -> void:
	if Global.low_fx:
		n = maxi(2, n / 2)
	for i in n:
		var ang := t * 2.0 + TAU * i / n
		Pix.dot(self, Vector2(cos(ang) * r, bob + sin(ang) * r * 0.8), Color(Color.WHITE if i % 2 == 0 else col, 0.9), 3.0 if i % 2 == 0 else 2.0)
