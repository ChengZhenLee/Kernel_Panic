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
	var SR = preload("res://scripts/secret_rooms.gd")
	var M = root.get_node("Meta")
	# ---------- A6 ----------
	var g = await boot(5)
	var s = g.secret
	g.camera.zoom = Vector2.ONE
	g.player.global_position = Vector2(0, 1500)
	g.camera.reset_smoothing()
	await shot("a6_1_battery_low", 0.6)
	M.lore["a6_kills"] = 2600
	await shot("a6_2_battery_half", 0.4)
	M.lore["a6_kills"] = 5000
	g.player.global_position = SR.A6_PADS[0] + Vector2(300, 0)
	g.camera.reset_smoothing()
	await shot("a6_3_pads", 0.5)
	for i in 3:
		g.player.global_position = SR.A6_PADS[i]
		await create_timer(0.3).timeout
		if i == 0: await shot("a6_4_pad_lit", 0.1)
	g.player.global_position = SR.A6_BEAM + Vector2(400, 300)
	g.camera.reset_smoothing()
	await shot("a6_5_beam", 0.6)
	g.player.global_position = SR.A6_BEAM
	await shot("a6_6_moon", 1.5)
	g.camera.zoom = Vector2(0.4, 0.4)
	await shot("a6_7_moon_overview", 2.0)
	g.camera.zoom = Vector2.ONE
	for e in g.enemy_layer.get_children():
		if e.has_meta("secret"):
			e.hp = 1.0
			e.take_damage(5000.0)
	await shot("a6_8_alien_dead", 1.5)
	# ---------- A7 ----------
	g = await boot(6)
	s = g.secret
	g.camera.zoom = Vector2.ONE
	g.player.global_position = SR.A7_BOXES[0] + Vector2(250, 0)
	g.camera.reset_smoothing()
	await shot("a7_1_box", 0.5)
	g.player.global_position = SR.A7_BOXES[1]
	await shot("a7_2_wrong", 0.4)
	for i in 3:
		g.player.global_position = SR.A7_BOXES[i]
		await create_timer(1.2).timeout
	await shot("a7_3_wired", 0.1)
	g.player.global_position = SR.A7_KEYPAD
	g.camera.reset_smoothing()
	await shot("a7_4_keypad", 0.6)
	s.pw_edit.text = "PANIC"
	s._try_password()
	g.player.global_position = SR.A7_PORTAL + Vector2(300, 0)
	g.camera.reset_smoothing()
	await shot("a7_5_hq_portal", 0.8)
	g.player.global_position = SR.A7_PORTAL
	await shot("a7_6_hq", 1.5)
	g.camera.zoom = Vector2(0.4, 0.4)
	await shot("a7_7_hq_overview", 0.5)
	# ---------- A8 ----------
	g = await boot(7)
	s = g.secret
	g.camera.zoom = Vector2(0.25, 0.25)
	s.a8_clock = 999.0
	await shot("a8_1_tile_overview", 0.6)
	g.camera.zoom = Vector2.ONE
	g.player.global_position = SR.A8_SPOTS[s.a8_spot] + Vector2(300, 0)
	g.camera.reset_smoothing()
	await shot("a8_2_tile", 0.5)
	g.player.global_position = SR.A8_SPOTS[s.a8_spot]
	for e in g.enemy_layer.get_children(): e.queue_free()
	await create_timer(5.6).timeout
	await shot("a8_3_room", 1.0)
	await shot("a8_4_lucifer", 3.5)
	# ---------- A3 ----------
	g = await boot(1)
	s = g.secret
	M.data = 5000.0
	g.camera.zoom = Vector2.ONE
	s._enter_app("store")
	await shot("a3_1_shop", 1.0)
	g.player.global_position = s._shop_spots()[0]
	await shot("a3_2_bought", 0.5)
	g.player.global_position = s._shop_spots()[3] + Vector2(0, 200)
	g = await boot(2)
	s = g.secret
	g.camera.zoom = Vector2(0.5, 0.5)
	g.player.global_position = SR.A3_PORTALS[0] + Vector2(0, -300)
	g.camera.reset_smoothing()
	await shot("a3_3_laptop_portal", 0.6)
	g.camera.zoom = Vector2.ONE
	g.player.global_position = SR.A3_PORTALS[0]
	await shot("a3_4_keyboard_room", 1.5)
	g.camera.zoom = Vector2(0.4, 0.4)
	await shot("a3_5_room_overview", 0.4)
	quit()
