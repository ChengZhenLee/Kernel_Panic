extends SceneTree
var out := "."
func shot(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	await create_timer(0.5).timeout
	root.get_node("Meta").selected_device = 4
	change_scene_to_file("res://scenes/game.tscn")
	await create_timer(1.5).timeout
	var g = root.get_node("Global").game
	var s = g.secret
	g.player.invuln = 99999.0
	var SR = preload("res://scripts/secret_rooms.gd")
	g.camera.zoom = Vector2(0.2, 0.2)
	g.player.global_position = Vector2(0, 0)
	g.camera.reset_smoothing()
	await shot("a5_0_map_overview")
	g.camera.zoom = Vector2.ONE
	g.player.global_position = SR.A5_RACK + Vector2(0, 100)
	g.camera.reset_smoothing()
	await shot("a5_1_watch", 1.6)
	await shot("a5_2_lit", 0.5)
	# wrong tile
	g.player.global_position = SR.A5_TILES[(s.a5_seq[0] + 1) % 4]
	await shot("a5_3_wrong", 0.5)
	# retry correctly
	g.player.global_position = SR.A5_RACK + Vector2(0, 100)
	await create_timer(3.4).timeout
	g.player.global_position = SR.A5_RACK + Vector2(0, 100)
	await create_timer(0.5).timeout
	await create_timer(5.0).timeout
	print("STATE ", s.a5_state)
	for n in s.a5_seq:
		g.player.global_position = SR.A5_TILES[n]
		await shot("a5_4_step_%d" % n, 0.4)
		g.player.global_position = Vector2(0, 0)
		await create_timer(0.2).timeout
	print("STATE2 ", s.a5_state)
	await shot("a5_5_solved", 0.5)
	g.player.global_position = SR.A5_WALL.get_center() + Vector2(250, 0)
	g.camera.reset_smoothing()
	await shot("a5_6_door", 0.5)
	g.player.global_position = SR.A5_WALL.get_center() + Vector2(40, 0)
	await shot("a5_7_hall", 1.5)
	await shot("a5_8_hall_wave", 4.5)
	g.camera.zoom = Vector2(0.3, 0.3)
	await shot("a5_9_hall_overview", 0.3)
	g.camera.zoom = Vector2.ONE
	g.player.global_position = Vector2(g.arena.bounds.end.x - 1200, g.arena.bounds.get_center().y)
	g.camera.reset_smoothing()
	await shot("a5_10_end", 1.5)
	g.player.global_position = Vector2(g.arena.bounds.end.x - 540, g.arena.bounds.get_center().y)
	await shot("a5_11_lore", 0.6)
	g.player.global_position = s._exit_pos()
	await shot("a5_12_exit", 1.0)
	quit()
