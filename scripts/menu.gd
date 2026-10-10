extends Control
const FD = preload("res://scripts/fx/fd.gd")
## Main menu: glitchy title, binary rain, options panel.
const ScrollFix = preload("res://scripts/ui/scroll_fix.gd")

var t := 0.0
var rain := []      # [x, y, speed, chars]
var drifters := []  # decorative viruses floating by
var main_box: Control
const LEFT_W := 400.0
const RIGHT_W := 420.0
var left_col: VBoxContainer
var right_col: VBoxContainer
var avatar_space: Control
var class_button: Button
var swipe_from := Vector2.ZERO
var swiping := false
var options_panel: PanelContainer
var start_button: Button
const IconView = preload("res://scripts/ui/icon_view.gd")
const IconArt = preload("res://scripts/icon_art.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const BossData = preload("res://scripts/boss_data.gd")
var glitch := 0.0
var info_label: Label
var sub_label: Label
var device_label: Label
var dev_buttons: Array = []
var map_button: Button
var howto_panel: PanelContainer
var howto_from_options := false
var title_y := 180.0


func _ready() -> void:
	Music.play_title()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var w := get_viewport_rect().size.x
	for i in int(w / 18.5) + 2:
		rain.append([i * 18.5 + randf() * 6.0, randf() * 900.0 - 200.0, randf_range(40.0, 150.0), _bits(14)])
	for i in 7:
		drifters.append([Vector2(randf() * 1280.0, randf() * 720.0), Vector2(randf_range(-30, 30), randf_range(-20, 20)),
			[Global.C_MAGENTA, Global.C_GREEN, Global.C_ORANGE, Global.C_RED].pick_random(), randf_range(8.0, 18.0)])

	var sub := Label.new()
	sub_label = sub
	sub.text = ""
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(Global.C_MAGENTA, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 236
	sub.offset_bottom = 276

	var info := Label.new()
	info_label = info
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_top = 320
	info.offset_bottom = 370

	# left: RESEARCH / UNLOCKS, a big START RUN, then QUIT and OPTIONS along the bottom. Right: the class avatar with the map under it.
	main_box = Control.new()
	main_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_box)
	main_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_col = _column(main_box, LEFT_W)
	right_col = _column(main_box, RIGHT_W)
	left_col.alignment = BoxContainer.ALIGNMENT_END
	var n := Meta.affordable_count()
	var research := _button("RESEARCH" + (" (%d)" % n if n > 0 else ""), left_col, func(): Global.change_scene("res://scenes/research.tscn"))
	research.custom_minimum_size = Vector2(LEFT_W, 64)
	if n > 0:
		research.add_theme_color_override("font_color", Global.C_GOLD)
	var unl := _button("UNLOCKS", left_col, func(): Global.change_scene("res://scenes/unlocks.tscn"))
	unl.custom_minimum_size = Vector2(LEFT_W, 64)
	start_button = _button("> START RUN <", left_col, _on_start)
	start_button.custom_minimum_size = Vector2(LEFT_W, 110)
	start_button.add_theme_font_size_override("font_size", 28)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	left_col.add_child(bottom)
	if not OS.has_feature("ios"):
		var quit := _button("QUIT", bottom, func(): get_tree().quit())
		quit.custom_minimum_size = Vector2((LEFT_W - 12.0) / 2.0, 64)
	var opt := _button("OPTIONS", bottom, _show_options)
	opt.custom_minimum_size = Vector2((LEFT_W - 12.0) / 2.0 if not OS.has_feature("ios") else LEFT_W, 64)

	var class_row := HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 8)
	right_col.add_child(class_row)
	var prev := _button("<", class_row, func(): _shift_class(-1))
	prev.custom_minimum_size = Vector2(56, 52)
	class_button = _button("", class_row, func(): _shift_class(1))
	class_button.custom_minimum_size = Vector2(RIGHT_W - 128.0, 52)
	class_button.add_theme_color_override("font_color", Global.C_CYAN)
	class_button.add_theme_font_size_override("font_size", 15)
	var next := _button(">", class_row, func(): _shift_class(1))
	next.custom_minimum_size = Vector2(56, 52)
	avatar_space = Control.new()   # the animated avatar is drawn in this gap
	avatar_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avatar_space.custom_minimum_size = Vector2(RIGHT_W, 150)
	avatar_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.add_child(avatar_space)
	var enter_row := HBoxContainer.new()   # "ENTERING:" plus the map's name as the button that opens the map
	enter_row.add_theme_constant_override("separation", 10)
	right_col.add_child(enter_row)
	var enter_label := Label.new()
	enter_label.text = "ENTERING:"
	enter_label.add_theme_font_override("font", Global.FONT_TITLE)
	enter_label.add_theme_font_size_override("font_size", 15)
	enter_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	enter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enter_row.add_child(enter_label)
	map_button = _button("MAP", enter_row, func(): Global.change_scene("res://scenes/map.tscn"))
	map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_button.custom_minimum_size = Vector2(RIGHT_W - 140.0, 52)
	map_button.add_theme_color_override("font_color", Global.C_GOLD)
	map_button.add_theme_font_size_override("font_size", 15)
	info_label.reparent(right_col)
	info_label.custom_minimum_size = Vector2(RIGHT_W, 0)
	info_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_refresh_info()

	_build_options()
	_build_howto()
	_layout()
	get_viewport().size_changed.connect(_layout)
	start_button.call_deferred("grab_focus")


## Left stack hugs the bottom-left, the avatar column fills the right under the title.
func _layout() -> void:
	var sz := get_viewport_rect().size
	var m := Global.safe_margins()
	title_y = lerpf(64.0, 92.0, clampf((sz.y - 480.0) / 240.0, 0.0, 1.0))
	sub_label.offset_top = 0.0
	sub_label.offset_bottom = 0.0
	left_col.size = Vector2(LEFT_W, left_col.get_combined_minimum_size().y)
	left_col.position = Vector2(m["left"] + 32.0, sz.y - m["bottom"] - 24.0 - left_col.size.y)
	var top := title_y + 28.0
	# the column is centred between the middle of the screen and the right edge, and never wider than that half
	var half_l := sz.x * 0.5 + 16.0
	var half_r: float = sz.x - m["right"] - 16.0
	var col_w := minf(RIGHT_W, half_r - half_l)
	var avail_h := maxf(300.0, sz.y - m["bottom"] - 24.0 - top)
	right_col.size = Vector2(col_w, avail_h)
	right_col.position = Vector2((half_l + half_r) * 0.5 - col_w * 0.5, top)
	info_label.custom_minimum_size = Vector2(col_w, 0)
	avatar_space.custom_minimum_size = Vector2(col_w, 60)
	class_button.custom_minimum_size = Vector2(col_w - 128.0, 52)
	map_button.custom_minimum_size = Vector2(col_w - 140.0, 52)
	# long ability text must not push the column past the screen: shrink the modifier text until it fits
	var fs := 20
	while fs > 12:
		info_label.add_theme_font_size_override("font_size", fs)
		right_col.size = Vector2(col_w, 0)
		if right_col.get_combined_minimum_size().y <= avail_h:
			break
		fs -= 2
	right_col.size = Vector2(col_w, avail_h)
	for p in [options_panel, howto_panel]:
		_fit_panel(p, sz.y)


## Keep a centered panel inside the screen height (its content scrolls if it is taller).
func _fit_panel(p: Control, h: float) -> void:
	var half: float = minf(p.get_meta("half_h", 300.0), h / 2.0 - 10.0)
	p.offset_top = -half
	p.offset_bottom = half


func _bits(n: int) -> String:
	var s := ""
	for i in n:
		s += "1" if randf() < 0.5 else "0"
	return s


func _column(parent: Node, w: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 12)
	c.custom_minimum_size = Vector2(w, 0)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(c)
	return c


func _button(text: String, parent: Node, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_override("font", Global.FONT_TITLE)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func():
		Sfx.play("select")
		callback.call())
	b.mouse_entered.connect(func(): Sfx.play("hover"))
	b.focus_entered.connect(func():
		Sfx.play("hover")
		glitch = 0.15)
	parent.add_child(b)
	return b


## One labelled volume slider bound to a Global setting; plays a sample sound from that group.
func _volume_row(box: Control, text: String, setting: String, sample: String) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Global.get(setting)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v):
		Global.set(setting, v)
		Sfx.apply_volumes()
		Music.apply_volume()
		if sample != "":
			Sfx.play(sample, 1.0, -4.0, 0.25))
	row.add_child(slider)


var options_focus: Button


func _build_options() -> void:
	options_panel = PanelContainer.new()
	add_child(options_panel)
	options_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options_panel.offset_left = -230
	options_panel.offset_right = 230
	options_panel.offset_top = -300
	options_panel.offset_bottom = 300
	options_panel.set_meta("half_h", 300.0)
	var scroll := ScrollContainer.new()
	ScrollFix.apply(scroll)
	options_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_override("font", Global.FONT_TITLE)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Global.C_CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_volume_row(box, "VOLUME", "sfx_volume", "pickup")
	_volume_row(box, "MUSIC", "music_volume", "")
	_volume_row(box, "EFFECTS", "fx_volume", "levelup")

	var shake := CheckButton.new()
	shake.text = "SCREEN SHAKE"
	shake.button_pressed = Global.screen_shake
	shake.toggled.connect(func(on): Global.screen_shake = on)
	box.add_child(shake)

	for o in [["MINIMAP", "minimap_on"], ["DAMAGE NUMBERS", "damage_numbers"], ["STATUS WORDS", "status_words"], ["SWAP ABILITY BUTTON / JOYSTICK SIDES", "swap_controls"]]:
		var tg := CheckButton.new()
		tg.text = o[0]
		tg.button_pressed = Global.get(o[1])
		var key: String = o[1]
		tg.toggled.connect(func(on):
			Global.set(key, on)
			Global.save())
		box.add_child(tg)

	var dev := CheckButton.new()
	dev.text = "DEV: UNLOCK EVERYTHING"
	dev.button_pressed = Global.dev_mode
	dev.toggled.connect(func(on): Meta.set_dev_mode(on))
	box.add_child(dev)

	var dev_cash := CheckButton.new()
	dev_cash.text = "DEV: INFINITE CURRENCY"
	dev_cash.button_pressed = Global.dev_money
	dev_cash.toggled.connect(func(on):
		Global.dev_money = on
		Global.save())
	box.add_child(dev_cash)

	options_focus = _button("HOW TO PLAY", box, func(): _open_howto(true))
	var wipe := _button("WIPE PROGRESS", box, func(): pass)
	wipe.pressed.connect(func():
		if wipe.text == "WIPE PROGRESS":
			wipe.text = "CLICK AGAIN TO CONFIRM"
		else:
			Meta.reset_all()
			Global.best_time = 0.0
			Global.save()
			get_tree().reload_current_scene())
	_button("BACK", box, _hide_options)
	options_panel.hide()


func _show_options() -> void:
	main_box.hide()
	options_panel.show()
	if options_focus:
		options_focus.call_deferred("grab_focus")


func _hide_options() -> void:
	Global.save()
	options_panel.hide()
	main_box.show()
	start_button.call_deferred("grab_focus")


func _on_start() -> void:
	Sfx.play("menu_start", 1.0, 0.0, 0.0)   # a soft confirm; the big start_run sting was far too dramatic for a menu button
	glitch = 0.4
	Global.change_scene("res://scenes/game.tscn")


func _challenge_text() -> String:
	var c: Dictionary = Meta.Challenges.by_id(Meta.active_challenge)
	var s := "" if c.is_empty() else "   -   CHALLENGE: %s" % c["name"]
	return s + ("" if Meta.mode_key() == "normal" else "   -   %s" % Meta.mode_name())


func _refresh_info() -> void:
	if map_button:
		map_button.text = "THE INTERNET" if Meta.run_internet() else Meta.device_name(Meta.selected_device)
	var cl := _current_class()
	if class_button:
		class_button.text = cl["name"]
	if info_label:
		var lines := []
		var mods := []
		if Meta.run_hard():
			mods.append("HARD")
		if Meta.run_speed():
			mods.append("SPEED RUN")
		if Meta.run_threat() > 0:
			mods.append("THREAT %d" % Meta.run_threat())
		var ch: Dictionary = Meta.Challenges.by_id(Meta.active_challenge)
		if not ch.is_empty() and Meta.challenge_available(ch):
			mods.append("CHALLENGE: " + String(ch["name"]))
		lines.append("MODIFIERS: " + (", ".join(mods) if not mods.is_empty() else "NONE"))
		if cl["id"] != "":
			lines.append("%s: %s" % [cl["ability_name"], cl["passive_text"]])
		info_label.text = "\n".join(lines)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if howto_panel:
			_layout()   # re-fits the column to the new text
			_layout.call_deferred()   # again once the wrapped label has its real height


## The class that will start the run (falls back to the base class if it is not owned this cycle).
func _current_class() -> Dictionary:
	var cl: Dictionary = Meta.Classes.by_id(Meta.selected_class)
	if cl["id"] != "" and not Meta.class_owned(cl["id"]):
		return Meta.Classes.NONE
	return cl


## Cycles through the base class and the classes bought this cycle (buy them in the CLASSES research tree).
func _shift_class(dir: int) -> void:
	var ids := [""]
	for c in Meta.Classes.LIST:
		if Meta.class_owned(c["id"]):
			ids.append(c["id"])
	var cur := _current_class()["id"] as String
	Meta.selected_class = ids[posmod(ids.find(cur) + dir, ids.size())]
	Meta.save()
	_refresh_info()


func _shift_device(dir: int) -> void:
	Meta.selected_device = posmod(Meta.selected_device + dir, mini(Meta.devices_cured, Meta.DEVICES.size() - 1) + 1)
	Meta.mode_internet = false
	Meta.save()
	_refresh_info()


func _howto_text() -> String:
	var move := "Touch and drag anywhere to move. A joystick appears under your thumb." if Global.is_touch else "Move with WASD or the arrow keys (or hold the mouse button and drag)."
	var pause := "Use the pause button (top right) or your back button. The STATS tab shows all your stats." if Global.is_touch else "Press ESC to pause. The STATS tab shows all your stats."
	var pick := "Tap a card to take it." if Global.is_touch else "Click a card or press 1-4. Press R to reroll."
	var ban := "Switch BAN on at the bottom, then tap a card" if Global.is_touch else "Switch BAN on at the bottom, then click a card (or hold Shift and press its number)"
	var parts := [
		"GOAL\nSurvive the infection. Your weapons fire automatically. Delete threats to earn XP and DATA. Defeat the final boss at 12:00 to cure the device.",
		"MOVING\n" + move,
		"LEVEL UPS\nEvery level offers three cards. " + pick + " Card colors show rarity: Common, Rare, Epic and Legendary. " + ban + " to remove that rarity of that card for the rest of the run, so it can't be offered again. You start with 1 ban, and research and items add more.",
		"CHESTS AND ITEMS\nElites and bosses can drop a gold chest. It offers special items, one of each per run. Red CORRUPTED items give a big bonus with a cost.",
		"PICKUPS\nGreen cross: repair patch (30 HP, more with HOT PATCH research). Magnet: pulls in all XP. Gold starburst: System Purge, which wipes the screen; elites lose a share of HP that grows with your damage and PURGE PAYLOAD research, and bosses survive.",
		"THREATS\nElites have a gold ring and hit hard. Swarms circle you, and clearing one drops a Purge. Bosses arrive at 3:00, 6:00 and 9:00, and the final boss at 12:00.",
		"STATUS EFFECTS\nIGNITION, TOXIN, CRYOGEN and STATIC SHOCK cards give every hit a chance to burn (damage over time), poison (stacking damage over time), freeze (slow) or shock (threats are stunned briefly and take more damage). VIRULENCE boosts all four. Bosses cannot be frozen. The STATS tab lists your chances.",
		"COMBOS\nKill threats quickly to build a combo. It fades fast and getting hit costs a quarter of it. Higher combos give bonus XP, DATA, crit chance and luck.",
		"RESEARCH\nDATA is permanent, even if you die. Spend it in Research on upgrades that last across runs. Outer rings unlock as you defeat bosses.",
		"DEVICES\nCure a device to unlock the next one. Each is about 2x tougher but pays double DATA. Tap ENTERING under the avatar to choose where to play.",
		"MODES AND CHALLENGES\nOn the device map, once a device is cured in the current cycle, you can switch on HARD (tougher enemies, double DATA and prestige points). SPEED RUN (the clock runs faster, more XP, double prestige points), THREAT LEVEL, CHALLENGES (a special rule and a reward) and the CLASSES tree are bought with prestige points and stay hidden until then. Prestige points are spent in the PRESTIGE tab of Research, but only after you reformat: points earned this cycle unlock at your next reformat.",
		"CODEX AND UNLOCKS\nThe CODEX button on the device map records every enemy, modifier, boss, weapon and evolution you meet. UNLOCKS lists your achievements and challenges.",
		"CLASSES\nA class gives a starting weapon, a passive and one ability. Unlock it (DATA, prestige, or a challenge), buy it in the CLASSES research tree, then pick it on the main menu (swipe left or right, or use the arrows above the avatar). Use the ability with the round button (bottom right) or Space / Q. Classes must be bought again after every reformat.",
		"STATUS COMBOS AND THREAT LEVEL\nStatus effects react: SHOCK on a frozen threat SHATTERS it, BURN on a frozen one is a MELTDOWN, BURN on a poisoned one is a TOXIC FLARE (extra damage, and the first status is used up). FIREWALL burns, QUARANTINE freezes, PING.EXE shocks and ENCRYPTION KEYS poison on their own, more often as they level. THREAT LEVEL (device map, once the device is cured) makes enemies tougher, more numerous and harder-hitting for more DATA.",
		"ARENAS\nEvery device is a fixed arena with walls, and its final boss is fought in a sealed boss room. Walls block you, threats and enemy shots (your laser bolts stop at them too); threats path around walls, except ROOTKITS which phase through. A small map in the top right shows the walls, you and the boss. THE INTERNET is its own endless map: the floor never ends, with walls and every kind of hazard scattered across it.",
		"HAZARDS\nEvery device has one hazard. FROST PATCHES, SIGNAL JAMMERS, LIVE WIRES, COOLING FANS and GRAVITY WELLS are built into the device: they sit in the same spots, and fans blow the same way, every run, so you can learn the map. HEAT VENTS, ORBITAL STRIKES and QUANTUM FLUX are events: they pop up at random near you, do their thing once, then fade away. THE INTERNET has a bit of everything. Hazards switch off inside a boss room.",
		"THE INTERNET\nOnce you have cured the OFFICE SERVER (kept through reformats), the device map gets a THE INTERNET toggle. The run plays like the chosen device, but there is no final boss and no cure: from 12:00 threats grow stronger every minute, with a boss every 3 minutes, until you fall. It pays DATA x0.8 and no prestige points, and HARD and SPEED RUN are off. Its own best time is kept.",
		"EVOLUTIONS\nOwn two particular weapons at LV 10 and the matching special item and a Legendary EVOLVE card starts appearing (often). It replaces both weapons with one super weapon. Evolutions are found during runs, never chosen up front. Once found, the evolved weapon joins your ARSENAL for good: no purchase, kept through every reformat, but a run only offers it as an EVOLVE card once you meet its recipe again.",
		"CHARGES AND SUPER CASTS\nEvery cache you open also gives an ability charge (up to 3). A charge lets you use the ability again without waiting for its cooldown; with no class the button is PURGE, which also recharges on its own every 60s. The cooldown is paused while you hold charges and only runs once they are used up, and it only ever stores one ready cast; extra stored casts come only from caches. After any cast a ring shrinks on the button: tap again while it is inside the gold band for a stronger SUPER cast with extra invulnerability and half the cooldown back. Tapping while the ring runs but outside the band only spoils the SUPER; it never spends another cast or charge.",
		"REFORMAT\nAfter curing a device you can reformat: research resets, but your prestige points and PRESTIGE tree stay, and the points you earned this cycle become spendable.",
		"PAUSING\n" + pause,
	]
	return "\n\n".join(parts)


func _build_howto() -> void:
	howto_panel = PanelContainer.new()
	add_child(howto_panel)
	howto_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	howto_panel.offset_left = -400
	howto_panel.offset_right = 400
	howto_panel.offset_top = -310
	howto_panel.offset_bottom = 310
	howto_panel.set_meta("half_h", 310.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	howto_panel.add_child(box)
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_override("font", Global.FONT_TITLE)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Global.C_CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ScrollFix.apply(scroll)
	box.add_child(scroll)
	var text := Label.new()
	text.text = _howto_text()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(740, 0)
	text.add_theme_font_size_override("font_size", 26)
	scroll.add_child(text)
	_button("BACK", box, _close_howto)
	howto_panel.hide()
	if not Global.seen_help:   # first launch: show the guide once
		Global.seen_help = true
		Global.save()
		_open_howto.call_deferred(false)


func _open_howto(from_options := false) -> void:
	howto_from_options = from_options
	main_box.hide()
	options_panel.hide()
	howto_panel.show()


func _close_howto() -> void:
	howto_panel.hide()
	if howto_from_options:
		options_panel.show()
	else:
		main_box.show()
		start_button.call_deferred("grab_focus")


func on_back() -> void:
	if howto_panel and howto_panel.visible:
		_close_howto()
	elif options_panel.visible:
		_hide_options()
	elif not OS.has_feature("ios"):
		get_tree().quit()


## Swipe left or right anywhere on the menu to change class (only owned classes are offered).
func _gui_input(event: InputEvent) -> void:
	if not main_box.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			swipe_from = event.position
			swiping = true
		elif swiping:
			swiping = false
			var d: Vector2 = event.position - swipe_from
			if absf(d.x) > 70.0 and absf(d.x) > absf(d.y) * 1.5:
				Sfx.play("select")
				_shift_class(-1 if d.x > 0.0 else 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if howto_panel and howto_panel.visible:
			_close_howto()
		elif options_panel.visible:
			_hide_options()


func _process(delta: float) -> void:
	t += delta
	# hide the main-menu text while the Options / How to Play panels are open
	info_label.visible = main_box.visible
	if class_button and class_button.text != _current_class()["name"]:
		_refresh_info()   # keeps the class name in step with the avatar, which always draws _current_class()
	glitch = maxf(0.0, glitch - delta)
	if randf() < 0.008:
		glitch = 0.12
	for col in rain:
		col[1] += col[2] * delta
		if col[1] > 800.0:
			col[1] = -300.0
			col[3] = _bits(14)
	for d in drifters:
		d[0] += d[1] * delta
		d[0].x = fposmod(d[0].x, size.x + 40.0)
		d[0].y = fposmod(d[0].y, size.y + 40.0)
	queue_redraw()


func _draw() -> void:
	var sz := size
	# grid
	var off := fmod(t * 20.0, 48.0)
	for x in range(0, int(sz.x) + 48, 48):
		draw_line(Vector2(x - off, 0), Vector2(x - off, sz.y), Color(0.1, 0.4, 0.5, 0.08), 1.0)
	for y in range(0, int(sz.y) + 48, 48):
		draw_line(Vector2(0, y + off), Vector2(sz.x, y + off), Color(0.1, 0.4, 0.5, 0.08), 1.0)

	# binary rain
	var font: Font = Global.FONT_BODY
	for col in rain:
		var s: String = col[3]
		for i in s.length():
			var a := (1.0 - float(i) / s.length()) * 0.28
			var c := Color(0.3, 1.0, 0.6, a) if i > 0 else Color(0.8, 1.0, 0.9, 0.6)
			draw_string(font, Vector2(col[0], col[1] - i * 18.0), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, c)

	# drifting viruses
	for d in drifters:
		var p: Vector2 = d[0]
		var c: Color = d[2]
		var r: float = d[3]
		FD.circle(self, p, r * 2.2, Color(c, 0.05))
		draw_rect(Rect2(p - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), Color(c, 0.35))

	if (options_panel and options_panel.visible) or (howto_panel and howto_panel.visible):
		return
	_draw_avatar()
	# glitchy title
	var title := "KERNEL PANIC"
	var tf: Font = Global.FONT_TITLE
	var fs := 64
	var w := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((sz.x - w) / 2.0, title_y + sin(t * 2.0) * 4.0)
	var j := 3.0 + glitch * 40.0
	var jitter := Vector2(randf_range(-j, j), 0) if glitch > 0.0 else Vector2(sin(t * 3.0) * 3.0, 0)
	draw_string(tf, pos + Vector2(0, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	draw_string(tf, pos + jitter, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Global.C_MAGENTA, 0.75))
	draw_string(tf, pos - jitter, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Global.C_CYAN, 0.75))
	draw_string(tf, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 1.0, 1.0))
	if glitch > 0.0:
		for i in 3:
			var y := pos.y - randf() * fs
			draw_rect(Rect2(pos.x + randf_range(-30, 30), y, w, randf_range(2, 8)), Color(Global.C_CYAN if randf() < 0.5 else Global.C_MAGENTA, 0.6))


## The animated player avatar, tinted by the chosen class (cyan for the base class).
func _draw_avatar() -> void:
	if avatar_space == null or not main_box.visible:
		return
	var rect := Rect2(avatar_space.global_position - global_position, avatar_space.size)
	var c := rect.get_center()
	var cl := _current_class()
	var col: Color = cl.get("color", Global.C_CYAN)
	var r := clampf(minf(rect.size.y * 0.3, 70.0), 30.0, 70.0)
	var spin := t * 0.8
	var avatar0: Texture2D = PixelArt.class_tex(cl["id"])
	if avatar0 == null:   # no pixel avatar: the old glow, ring and spinning hexagon
		Global.glow_circle(self, c, r * 1.2, col, 1.6 + 0.4 * sin(t * 2.0))
		draw_arc(c, r * 1.55 + 3.0 * sin(t * 2.0), 0.0, TAU, 48, Color(col, 0.18), 2.0)
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(c + Vector2.from_angle(spin + TAU * i / 6.0) * r * 1.1)
		draw_colored_polygon(hex, Color(col, 0.15))
		hex.append(hex[0])
		draw_polyline(hex, col, 4.0)
	var avatar: Texture2D = PixelArt.class_tex(cl["id"])
	if avatar != null:   # the pixel avatar of the chosen class, standing inside the spinning ring
		PixelArt.draw_class(self, avatar, c + Vector2(0.0, -r * 0.08), r * 2.5, t)
	elif cl["id"] == "":   # the base class shows the plain pointer, turning to follow the mouse
		var to_mouse := get_local_mouse_position() - c
		var f := to_mouse.normalized() if to_mouse.length() > 4.0 else Vector2.from_angle(t)
		var s := f.orthogonal()
		draw_colored_polygon(PackedVector2Array([c + f * r * 0.5, c - f * r * 0.27 + s * r * 0.32, c - f * r * 0.09, c - f * r * 0.27 - s * r * 0.32]), Color(0.9, 1.0, 1.0))
	else:
		IconArt.draw_icon(self, cl["icon"], c, r * 0.55, col, t)
	if avatar0 == null:
		FD.circle(self, c + Vector2.from_angle(-spin * 2.2) * r * 1.35, 5.0, col)
