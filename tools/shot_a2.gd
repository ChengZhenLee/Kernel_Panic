extends SceneTree
# usage: godot --path . -s tools/shot_a2.gd -- OUTDIR
var out := "."
func shot(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	await create_timer(0.5).timeout
	root.get_node("Meta").selected_device = 1
	change_scene_to_file("res://scenes/game.tscn")
	await create_timer(1.5).timeout
	var g = root.get_node("Global").game
	var s = g.secret
	print("DBG dev=", root.get_node("Meta").selected_device, " phone=", s.phone, " blocks=", s.app_blocks.size(), " game=", s.game, " internet=", g.internet)
	# overview of the grid with the corrupted block
	var cb: Rect2 = s.app_blocks[s.corrupt_i]
	g.camera.zoom = Vector2(0.3, 0.3)
	g.player.global_position = cb.get_center() + Vector2(-1200, 1500)
	g.camera.reset_smoothing()
	await shot("a2_0_grid_overview")
	g.camera.zoom = Vector2.ONE
	# a normal block: pick the first non corrupted one
	var idx := 0 if s.corrupt_i != 0 else 1
	for theme_i in [0, 1, 2]:
		var blk: Rect2 = s.app_blocks[theme_i if theme_i != s.corrupt_i else 5]
		g.player.global_position = Vector2(blk.get_center().x, blk.end.y + 36)
		g.camera.reset_smoothing()
		await create_timer(0.4).timeout
		if theme_i == 0:
			await shot("a2_1_prompt")
		s.prompt_idx = theme_i if theme_i != s.corrupt_i else 5
		s._on_prompt_yes()
		await shot("a2_2_app_%d" % theme_i, 0.8)
		if theme_i == 0:
			g.player.global_position = s.lore_drops[0]["pos"] + Vector2(0, 30)
			await shot("a2_3_app_memo", 0.6)
		s._leave()
		s.portal_cd = 0
		await create_timer(0.3).timeout
	# corrupted app
	g.player.global_position = Vector2(cb.get_center().x, cb.end.y + 36)
	g.camera.reset_smoothing()
	s.prompt_cd = 0
	await shot("a2_4_corrupted_block", 0.6)
	s.prompt_idx = s.corrupt_i
	s._on_prompt_yes()
	await shot("a2_5_password", 0.4)
	s.pw_edit.text = "WRONG"; s._try_password()
	await shot("a2_6_denied", 0.3)
	s.pw_edit.text = "envy"; s._try_password()
	await shot("a2_7_corrupt_room", 3.0)
	quit()
