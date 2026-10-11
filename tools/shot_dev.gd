extends SceneTree
var out := "."
func shot(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func boot(dev: int):
	root.get_node("Meta").selected_device = dev
	change_scene_to_file("res://scenes/game.tscn")
	await create_timer(1.5).timeout
	var g = root.get_node("Global").game
	g.player.invuln = 99999.0
	return g
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	await create_timer(0.5).timeout
	var g = await boot(4)
	var s = g.secret
	await shot("dev_0_button", 0.3)
	s._toggle_dev()
	await shot("dev_1_panel_a5", 0.5)
	s._dev_do(s._a5_solved)
	await shot("dev_2_after_solve", 0.6)
	s._toggle_dev()
	await shot("dev_3_panel_again", 0.4)
	s._dev_do(s._enter_upload)
	await shot("dev_4_in_room", 1.0)
	g = await boot(7)
	s = g.secret
	s._toggle_dev()
	await shot("dev_5_panel_a8", 0.5)
	quit()
