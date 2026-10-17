extends SceneTree
var out := "."
func shot(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	await create_timer(0.5).timeout
	root.get_node("Meta").selected_device = 3
	change_scene_to_file("res://scenes/game.tscn")
	await create_timer(1.5).timeout
	var g = root.get_node("Global").game
	var s = g.secret
	var SR = preload("res://scripts/secret_rooms.gd")
	g.camera.zoom = Vector2(0.2, 0.2)
	g.player.global_position = Vector2(-3500, 0)
	g.camera.reset_smoothing()
	await shot("a4_0_map_overview")
	g.camera.zoom = Vector2.ONE
	g.player.global_position = SR.PRINTER_POS + Vector2(0, 450)
	g.camera.reset_smoothing()
	await shot("a4_1_printer_jam", 0.8)
	if is_instance_valid(s.jam_enemy): s.jam_enemy.queue_free()
	await shot("a4_2_print_complete", 0.9)
	g.player.global_position = SR.PRINTER_POS + Vector2(0, 120)
	await shot("a4_3_print_memo", 0.5)
	s._hide_lore()
	g.player.global_position = SR.INTERN_POS + Vector2(500, 0)
	g.camera.reset_smoothing()
	await shot("a4_4_intern_hiding", 4.0)
	s.intern_t = 29.5
	await shot("a4_5_badge_dropped", 1.5)
	g.player.global_position = s.badge_pos + Vector2(30, 0) if s.badge_pos != null else SR.INTERN_POS
	await shot("a4_6_badge_acquired", 0.4)
	g.player.global_position = SR.DOOR_POS + Vector2(250, 0)
	g.camera.reset_smoothing()
	await shot("a4_7_lounge_door", 0.4)
	g.player.global_position = SR.DOOR_POS + Vector2(60, 0)
	await shot("a4_8_lounge_room", 1.2)
	g.camera.zoom = Vector2(0.45, 0.45)
	await shot("a4_9_lounge_overview", 0.6)
	quit()
