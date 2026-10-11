extends SceneTree
# usage: godot --path . -s tools/shot_a1.gd -- OUTDIR
var out := "."
func shot(name: String) -> void:
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	change_scene_to_file("res://scenes/game.tscn")
	await create_timer(1.5).timeout
	var g = root.get_node("Global").game
	var s = g.secret
	var wc: Vector2 = s._wall_center()
	g.player.global_position = wc + Vector2(0, 250)
	g.camera.reset_smoothing()
	g.camera.zoom = Vector2(0.28, 0.28)
	g.player.global_position = wc + Vector2(900, 900)
	g.camera.reset_smoothing()
	await shot("a1_00_pocket_overview")
	g.camera.zoom = Vector2.ONE
	g.player.global_position = wc + Vector2(0, 250)
	g.camera.reset_smoothing()
	await shot("a1_0_intact")
	s.on_purge(wc + Vector2(0, 250)); await shot("a1_1_crack1")
	s.on_purge(wc + Vector2(0, 250)); await shot("a1_2_crack2")
	s.on_purge(wc + Vector2(0, 250)); await shot("a1_3_portal")
	g.player.global_position = wc + Vector2(0, 60)
	await create_timer(0.3).timeout
	g.player.global_position = g.arena.bounds.get_center() + Vector2(150, 0)
	g.camera.reset_smoothing()
	g.camera.zoom = Vector2(0.45, 0.45)
	g.camera.reset_smoothing()
	await shot("a1_4_freezer_frozen")
	await create_timer(2.6).timeout
	g.player.global_position = g.arena.bounds.get_center() + Vector2(150, 0)
	await shot("a1_5_thawed")
	g.camera.zoom = Vector2.ONE
	for b in g.enemy_layer.get_children():
		if b.is_boss:
			s.on_boss_killed(b)
			b.queue_free()
	await create_timer(0.8).timeout
	g.player.global_position = s.lore_pos + Vector2(-260, 0)
	g.camera.reset_smoothing()
	await shot("a1_6_lore_item")
	g.player.global_position = s.lore_pos + Vector2(0, 20)
	await create_timer(0.4).timeout
	await shot("a1_7_lore_panel")
	quit()
