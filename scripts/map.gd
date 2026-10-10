extends Control
## DEVICE MAP: devices laid out along a winding path. Cured devices are lit, the next one is the
## frontier, the rest are locked. Tap an unlocked device to select it, then press PLAY.

const BossData = preload("res://scripts/boss_data.gd")
const IconArt = preload("res://scripts/icon_art.gd")
const ScrollFix = preload("res://scripts/ui/scroll_fix.gd")
const PER_PAGE_TALL := 8
var per_page := 8   # 4 (one row) when the scaled screen is too short for two rows

var t := 0.0
var page := 0   # always 0 now: the map scrolls instead of paging
var scroll_y := 0.0
var drag_from := Vector2.ZERO
var dragging := false
var pressed_node := -1
const STEP := 300.0     # vertical distance between device nodes: one or two on screen, so the map scrolls
const POPUP_W := 440.0
const HEADER_H := 76.0
const NODE_R := 66.0
var popup: PanelContainer
var popup_scroll: ScrollContainer
var popup_box: VBoxContainer
var popup_open := true
var shake := {}
var play_button: Button
var info_label: Label
var challenge_button: Button
var class_button: Button
var start_button: Button
var threat_button: Button
var internet_button: Button
var hard_button: Button
var speed_button: Button


func _ready() -> void:
	Music.play_title()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	per_page = _count()
	_build_ui()
	_refresh()
	scroll_y = _scroll_to(Meta.selected_device)


func _build_ui() -> void:
	var m := Global.safe_margins()
	var back := Button.new()
	back.text = "< BACK"
	back.custom_minimum_size = Vector2(150, 56)
	back.focus_mode = Control.FOCUS_NONE
	add_child(back)
	back.position = Vector2(16.0 + m["left"], 14.0 + m["top"])
	back.pressed.connect(func():
		Sfx.play("select")
		on_back())
	var title := Label.new()
	title.text = "DEVICE MAP"
	title.add_theme_font_override("font", Global.FONT_TITLE)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Global.C_CYAN)
	add_child(title)
	title.position = Vector2(190.0 + m["left"], 28.0 + m["top"])
	# the stat-and-modifier box: it opens beside the clicked device node and follows it as the map scrolls
	popup = PanelContainer.new()
	popup.add_theme_stylebox_override("panel", Global.make_box(Color(0.03, 0.05, 0.09, 0.97), Global.C_CYAN, 2, 12, 4))
	add_child(popup)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var outer := VBoxContainer.new()   # PLAY stays pinned under the scrolling part
	outer.add_theme_constant_override("separation", 6)
	popup.add_child(outer)
	popup_scroll = ScrollContainer.new()   # scrolls if the box is taller than the screen (every modifier on, long challenge text)
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(popup_scroll)
	ScrollFix.apply(popup_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	popup_scroll.add_child(box)
	popup_box = box
	info_label = Label.new()
	info_label.custom_minimum_size = Vector2(POPUP_W - 24.0, 0)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 21)
	box.add_child(info_label)
	hard_button = _mode_button(box, func():
		if not Meta.hard_available():
			Sfx.play("deny")
			return
		Meta.mode_hard = not Meta.mode_hard
		_save_modes())
	speed_button = _mode_button(box, func():
		Meta.mode_speed = not Meta.mode_speed
		_save_modes())
	threat_button = _pick_button(box, func():
		if not Meta.threat_available():
			Sfx.play("deny")
			return
		Meta.mode_threat = (Meta.mode_threat + 1) % (Meta.THREAT_MAX + 1)
		_save_modes())
	internet_button = _pick_button(box, func(): pass)   # the INTERNET is its own node on the map; this stays hidden
	internet_button.visible = false
	challenge_button = _pick_button(box, func(): _cycle_challenge())
	class_button = _pick_button(box, func(): _cycle_class())
	start_button = _pick_button(box, func(): _cycle_start())
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(POPUP_W - 24.0, 62)
	play_button.add_theme_font_override("font", Global.FONT_TITLE)
	play_button.add_theme_font_size_override("font_size", 26)
	play_button.focus_mode = Control.FOCUS_NONE
	play_button.visible = false   # starting a run is done from the main menu
	outer.add_child(play_button)
	play_button.pressed.connect(func():
		Sfx.play("levelup")
		Global.change_scene("res://scenes/game.tscn"))


func _pick_button(parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(POPUP_W - 24.0, 44)
	b.add_theme_font_override("font", Global.FONT_TITLE)
	b.add_theme_font_size_override("font_size", 13)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_constant_override("line_spacing", 4)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b


func _mode_button(parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(POPUP_W - 24.0, 40)
	b.add_theme_font_override("font", Global.FONT_TITLE)
	b.add_theme_font_size_override("font_size", 13)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_constant_override("line_spacing", 4)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		if not Meta.mode_available():
			Sfx.play("deny")
			return
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b


func _save_modes() -> void:
	Meta.save()
	_refresh()


func _cycle_challenge() -> void:
	var ids := [""]
	for c in Meta.Challenges.ALL:
		if Meta.challenge_available(c):
			ids.append(c["id"])
	if not ids.has(Meta.active_challenge):
		Meta.active_challenge = ""
	Meta.active_challenge = ids[(ids.find(Meta.active_challenge) + 1) % ids.size()]
	Meta.save()
	_refresh()


## Cycles through NO CLASS and the classes bought this cycle (buy them in the CLASSES research tree).
func _cycle_class() -> void:
	var ids := [""]
	for c in Meta.Classes.LIST:
		if Meta.class_owned(c["id"]):
			ids.append(c["id"])
	if not ids.has(Meta.selected_class):
		Meta.selected_class = ""
	Meta.selected_class = ids[(ids.find(Meta.selected_class) + 1) % ids.size()]
	Meta.save()
	_refresh()


## Legacy starting-weapon picker: the START button is hidden in _refresh (evolutions are found in a run, not chosen at the start), so this is currently unused.
func _cycle_start() -> void:
	var ids := [""]
	for r in Meta.Evolutions.LIST:
		if Meta.unlocks.has("start:" + r["id"]):
			ids.append(r["id"])
	if not ids.has(Meta.selected_start):
		Meta.selected_start = ""
	Meta.selected_start = ids[(ids.find(Meta.selected_start) + 1) % ids.size()]
	Meta.save()
	_refresh()


func _refresh() -> void:
	var d := Meta.selected_device
	var status := "CURED" if d < Meta.devices_cured else "NEXT TO CURE"
	var c: Dictionary = Meta.Challenges.by_id(Meta.active_challenge)
	if not c.is_empty() and not Meta.challenge_available(c):
		c = {}
	var ok := Meta.mode_available()
	var net := Meta.run_internet()
	var tl := Meta.run_threat()
	threat_button.text = ("THREAT: %d (+%d%% DATA)" % [tl, int(Meta.THREAT_DATA * 100.0 * tl)]) if Meta.threat_available() else "THREAT LEVEL: cure this device first"
	threat_button.modulate = Color.WHITE if tl > 0 else Color(0.7, 0.75, 0.8)
	internet_button.text = ("THE INTERNET: %s  (endless)" % ("ON" if net else "OFF")) if Meta.internet_available() else "THE INTERNET: cure 3 devices"
	internet_button.modulate = Color.WHITE if net else Color(0.7, 0.75, 0.8)
	hard_button.text = ("HARD: %s  (x2 DATA, x2 PP)" % ("ON" if Meta.mode_hard else "OFF")) if Meta.hard_available() else "HARD: cure this device first"
	speed_button.text = ("SPEED RUN: %s  (x2 PP)" % ("ON" if Meta.mode_speed else "OFF")) if ok else "SPEED RUN: cure this device first"
	hard_button.visible = Meta.hard_available() and not net
	speed_button.visible = Meta.speed_available() and not net
	internet_button.visible = false   # replaced by the INTERNET node on the map
	threat_button.visible = Meta.threat_available()
	challenge_button.visible = Meta.trials_available()
	class_button.visible = false   # the class is picked on the main menu
	hard_button.modulate = Color.WHITE if Meta.run_hard() else Color(0.7, 0.75, 0.8)
	speed_button.modulate = Color.WHITE if Meta.run_speed() else Color(0.7, 0.75, 0.8)
	var fb: Dictionary = BossData.final_for(d)
	var third := "Final boss: %s" % (fb["name"] if Meta.codex.has("boss:" + fb["id"]) else "???")   # revealed once encountered (codex survives reformats)
	var extra := ""
	if net:
		third = "THE INTERNET: endless, no cure. Threats grow from 12:00. DATA x%.1f, no PP." % Meta.INTERNET_DATA
	if c.is_empty():
		challenge_button.text = "CHALLENGE: NONE"
	else:
		var done: bool = Meta.challenges_done.has(c["id"])
		challenge_button.text = "CHALLENGE: %s%s" % [c["name"], " (DONE)" if done else ""]
		extra = "%s. %s%s" % [c["rule_text"], c["goal_text"], "" if done else " for " + c["reward_text"]]
	var cl: Dictionary = Meta.Classes.by_id(Meta.selected_class)
	if cl["id"] != "" and not Meta.class_owned(cl["id"]):
		cl = Meta.Classes.NONE
	if Meta.selected_start != "" and not Meta.unlocks.has("start:" + Meta.selected_start):
		Meta.selected_start = ""
	var sr: Dictionary = Meta.Evolutions.by_id(Meta.selected_start)
	start_button.visible = false   # evolutions are no longer starting weapons
	start_button.text = "START: " + (sr["name"] if not sr.is_empty() else "DEFAULT")
	class_button.text = "CLASS: " + (cl["name"] if cl["id"] != "" else "NONE")
	if extra == "" and cl["id"] != "":
		extra = "%s: %s (%ds)" % [cl["name"], cl["ability_name"], int(cl["cd"])]
	if net:
		info_label.text = "THE INTERNET  -  ENDLESS MAP\nHP x%.1f   DMG x%.1f   DATA x%.1f\n%s%s" % [Meta.enemy_hp_mult(), Meta.enemy_dmg_mult(), Meta.device_data_mult(Meta.run_tier()) * Meta.INTERNET_DATA, third, ("\n" + extra) if extra != "" else ""]
	else:
		info_label.text = "%s  -  %s\nHP x%.1f   DMG x%.1f   DATA x%.1f\n%s%s" % [
		Meta.device_name(d), status, Meta.enemy_hp_mult(), Meta.enemy_dmg_mult(), Meta.device_data_mult(d) * (Meta.HARD_DATA if Meta.run_hard() else 1.0), third, ("\n" + extra) if extra != "" else ""]
	per_page = _count()
	scroll_y = clampf(scroll_y, 0.0, _max_scroll())
	popup.reset_size()


## Devices drawn: the cured ones, the next to cure and two locked ones beyond it (at least 6).
func _count() -> int:
	return mini(Meta.DEVICES.size(), maxi(6, Meta.devices_cured + 3))   # QUANTUM CORE is the last device


func _world_y(i: int) -> float:
	return 190.0 + (per_page - 1 - i) * STEP   # device 1 at the bottom, the path climbs as you progress


func _max_scroll() -> float:
	return maxf(0.0, _world_y(0) + 190.0 - size.y)


## The scroll offset that centres a device on screen.
func _scroll_to(gidx: int) -> float:
	return clampf(_world_y(gidx) - size.y / 2.0, 0.0, _max_scroll())


func on_back() -> void:
	Global.change_scene("res://scenes/menu.tscn")


# ---------- layout & input ----------

func _node_pos(i: int) -> Vector2:
	var amp := minf(190.0, size.x * 0.17)
	return Vector2(size.x / 2.0 + sin(i * 1.15) * amp, _world_y(i) - scroll_y)


## THE INTERNET: its own node beside the path between the OFFICE SERVER and the next device, revealed once the OFFICE SERVER is cured. Tap it to run it instead of the selected device.
func _net_pos() -> Vector2:
	var y := (_node_pos(mini(Meta.INTERNET_DEVICE, per_page - 1)).y + _node_pos(mini(Meta.INTERNET_DEVICE + 1, per_page - 1)).y) / 2.0
	return Vector2(size.x - 100.0 - Global.safe_margins()["right"], y)


func _node_at(pos: Vector2) -> int:
	if pos.y < HEADER_H:
		return -1   # under the header
	for i in per_page:
		if _node_pos(i).distance_to(pos) < NODE_R + 14.0:
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		scroll_y = clampf(scroll_y + (-90.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 90.0), 0.0, _max_scroll())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_from = event.position
			dragging = false
			pressed_node = _node_at(event.position)
		else:
			if not dragging:
				if Meta.internet_available() and event.position.y > HEADER_H and _net_pos().distance_to(event.position) < 56.0:
					if Meta.mode_internet and popup_open:
						popup_open = false
						Sfx.play("hover")
					else:
						Meta.mode_internet = true
						popup_open = true
						Sfx.play("select", 1.3)
						_save_modes()
				elif pressed_node >= 0 and pressed_node == _node_at(event.position):
					if pressed_node == Meta.selected_device and popup_open and not Meta.run_internet():
						popup_open = false   # tap the open node again to close its box
						Sfx.play("hover")
					else:
						popup_open = pressed_node <= Meta.devices_cured
						_select(pressed_node)
				elif event.position.y > HEADER_H:
					popup_open = false
			dragging = false
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not dragging and event.position.distance_to(drag_from) > 12.0:
			dragging = true
		if dragging:
			scroll_y = clampf(scroll_y - event.relative.y, 0.0, _max_scroll())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		on_back()
	elif event.is_action_pressed("ui_left"):
		_select(maxi(0, Meta.selected_device - 1))
		scroll_y = _scroll_to(Meta.selected_device)
	elif event.is_action_pressed("ui_right"):
		_select(mini(mini(Meta.devices_cured, Meta.DEVICES.size() - 1), Meta.selected_device + 1))
		scroll_y = _scroll_to(Meta.selected_device)


func _select(gidx: int) -> void:
	if gidx > Meta.devices_cured or gidx >= Meta.DEVICES.size():
		shake[gidx] = 1.0
		Sfx.play("deny")
		return
	Meta.selected_device = gidx
	Meta.mode_internet = false   # a device and THE INTERNET are separate maps
	Meta.save()
	Sfx.play("select", 1.3)
	_refresh()


func _process(delta: float) -> void:
	t += delta
	for k in shake.keys():
		shake[k] = maxf(0.0, shake[k] - delta * 3.0)
	_place_popup()
	queue_redraw()


## The box sits beside the selected node, on whichever side has room, and stays on screen.
func _place_popup() -> void:
	var p := _net_pos() if Meta.run_internet() else _node_pos(Meta.selected_device)
	popup.visible = popup_open and p.y > HEADER_H - 20.0 and p.y < size.y + 20.0
	if not popup.visible:
		return
	var w := POPUP_W
	var avail := size.y - HEADER_H - 16.0
	popup_scroll.custom_minimum_size = Vector2(POPUP_W - 4.0, minf(popup_box.get_combined_minimum_size().y, avail - 24.0))
	popup.reset_size()   # the box shrinks to its content every frame, so toggling hidden buttons (device vs THE INTERNET) never leaves stale empty space
	var h := popup.get_combined_minimum_size().y
	var x := p.x + NODE_R + 40.0 if p.x < size.x / 2.0 else p.x - NODE_R - 40.0 - w
	popup.position = Vector2(clampf(x, 8.0, size.x - w - 8.0), clampf(p.y - h / 2.0, HEADER_H + 4.0, maxf(HEADER_H + 4.0, size.y - h - 8.0)))


# ---------- drawing ----------

func _text(s: String, center: Vector2, fsize: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Global.FONT_BODY
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string_outline(f, center - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 5, Color(0.03, 0.035, 0.08))
	draw_string(f, center - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.08))
	var step := 64.0
	var gx := fposmod(t * 8.0, step)
	while gx < size.x:
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(0.2, 0.45, 0.55, 0.07), 1.0)
		gx += step
	var gy := 0.0
	while gy < size.y:
		draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(0.2, 0.45, 0.55, 0.07), 1.0)
		gy += step

	# the path
	for i in per_page - 1:
		var gi := page * per_page + i
		var a := _node_pos(i)
		var b := _node_pos(i + 1)
		var col: Color = Meta.PALETTES[gi % Meta.PALETTES.size()]
		if gi < Meta.devices_cured:
			draw_line(a, b, Color(col, 0.25), 14.0)
			draw_line(a, b, col, 4.0)
			draw_circle(a.lerp(b, fmod(t * 0.5 + i * 0.3, 1.0)), 5.0, Color.WHITE)
		else:
			draw_dashed_line(a, b, Color(0.5, 0.55, 0.65, 0.35), 3.0, 12.0)
	for i in per_page:
		_draw_node(i)
	if Meta.internet_available():
		_draw_net()
	# header backdrop so scrolled nodes pass beneath the buttons instead of through them
	draw_rect(Rect2(0, 0, size.x, HEADER_H + Global.safe_margins()["top"]), Color(0.03, 0.035, 0.08, 0.96))
	draw_line(Vector2(0, HEADER_H + Global.safe_margins()["top"]), Vector2(size.x, HEADER_H + Global.safe_margins()["top"]), Color(Global.C_CYAN, 0.25), 1.0)


func _draw_net() -> void:
	var p := _net_pos()
	var on := Meta.mode_internet
	var col := Color(0.4, 0.95, 0.85)
	var r := 36.0
	draw_circle(p, r * (1.5 + (0.1 * sin(t * 4.0) if on else 0.0)), Color(col, 0.14 if on else 0.06))
	draw_circle(p, r, Color(col.r * 0.12, col.g * 0.12, col.b * 0.12))
	draw_arc(p, r, 0.0, TAU, 40, col if on else Color(col, 0.6), 4.0)
	draw_arc(p, r * 0.62, PI / 2.0, PI * 1.5, 16, Color(col, 0.7), 2.0)
	draw_arc(p, r * 0.62, -PI / 2.0, PI / 2.0, 16, Color(col, 0.7), 2.0)
	draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), Color(col, 0.7), 2.0)
	draw_line(p + Vector2(0, -r), p + Vector2(0, r), Color(col, 0.7), 2.0)
	if on:
		draw_arc(p, r + 10.0 + 2.0 * sin(t * 6.0), 0.0, TAU, 48, Color.WHITE, 3.0)
	_text("THE INTERNET", p + Vector2(0, r + 26.0), 20, Color(0.9, 0.96, 1.0))
	_text("ENDLESS", p + Vector2(0, r + 48.0), 18, Global.C_GOLD if on else Color(0.6, 0.65, 0.75))
	var nb := float(Meta.mode_best.get("internet", 0.0))
	_text("BEST %s" % Global.format_time(nb) if nb > 0.0 else "NO RECORD", p + Vector2(0, r + 70.0), 18, Global.C_GOLD if nb > 0.0 else Color(0.5, 0.55, 0.65))


func _draw_node(i: int) -> void:
	var gidx := page * per_page + i
	var p := _node_pos(i) + Vector2(sin(t * 60.0) * 8.0 * shake.get(gidx, 0.0), 0)
	var col: Color = Meta.PALETTES[gidx % Meta.PALETTES.size()]
	var cured := gidx < Meta.devices_cured
	var frontier := gidx == Meta.devices_cured
	var locked := gidx > Meta.devices_cured
	var r := NODE_R
	if frontier:
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		draw_circle(p, r * (1.5 + 0.15 * pulse), Color(col, 0.12 + 0.1 * pulse))
		_text("NEXT", p + Vector2(-r - 44.0, 8.0), 24, Global.C_GOLD)   # beside the node, clear of the row above
	elif cured:
		draw_circle(p, r * 1.4, Color(Global.C_GOLD, 0.08))
	var hex := PackedVector2Array()
	for k in 6:
		hex.append(p + Vector2.from_angle(TAU * k / 6.0 + PI / 6.0) * r)
	var edge := col if not locked else Color(0.55, 0.6, 0.7, 0.8)
	draw_colored_polygon(hex, Color(col.r * 0.18, col.g * 0.18, col.b * 0.18) if not locked else Color(0.08, 0.09, 0.13))
	hex.append(hex[0])
	draw_polyline(hex, Global.C_GOLD if cured else edge, 4.0)
	IconArt.draw_icon(self, Meta.device_icon(gidx), p, r * 0.5, col if not locked else Color(0.45, 0.5, 0.6), t)
	_text(str(gidx + 1), p + Vector2(-r + 6.0, -r + 18.0), 18, Color.WHITE if not locked else Color(0.55, 0.6, 0.7), Global.FONT_TITLE)
	if cured:
		var ck := p + Vector2(r * 0.78, -r * 0.78)
		draw_circle(ck, 15.0, Global.C_GOLD)
		draw_polyline(PackedVector2Array([ck + Vector2(-7, 0), ck + Vector2(-2, 6), ck + Vector2(8, -6)]), Color(0.05, 0.05, 0.1), 3.5)
	elif locked:
		var lp := p + Vector2(r * 0.74, r * 0.7)
		draw_circle(lp, 15.0, Color(0.03, 0.035, 0.08))
		draw_arc(lp + Vector2(0, -5), 6.0, PI, TAU, 8, Color(0.9, 0.9, 0.95), 3.0)
		draw_rect(Rect2(lp + Vector2(-8, -4), Vector2(16, 12)), Color(0.9, 0.9, 0.95))
	if gidx == Meta.selected_device and not Meta.run_internet():
		draw_arc(p, r + 12.0 + 2.0 * sin(t * 6.0), 0.0, TAU, 48, Color.WHITE, 3.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r - 22.0), p + Vector2(-9, -r - 36.0), p + Vector2(9, -r - 36.0)]), Color.WHITE)
	# name, boss pips and final boss
	_text(Meta.device_name(gidx), p + Vector2(0, r + 34.0), 26, Color(0.9, 0.96, 1.0) if not locked else Color(0.55, 0.6, 0.7))
	var lit := [false, false, false, false]
	if cured:
		lit = [true, true, true, true]
	elif frontier:
		for k in 3:
			lit[k] = k < int(Meta.device_boss.get(gidx, 0))
	for k in 4:
		var c := p + Vector2((k - 1.5) * 26.0, r + 58.0)
		var on: bool = lit[k]
		if k < 3:
			draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), Global.C_GOLD if on else Color(0.35, 0.4, 0.5, 0.6), true if on else false, 2.0)
		else:
			var dm := PackedVector2Array([c + Vector2(0, -10), c + Vector2(9, 0), c + Vector2(0, 10), c + Vector2(-9, 0)])
			if on:
				draw_colored_polygon(dm, Global.C_RED)
			else:
				dm.append(dm[0])
				draw_polyline(dm, Color(0.7, 0.35, 0.4, 0.8), 2.0)
	if not locked:
		var bt := float(Meta.device_best.get(gidx, 0.0))
		_text("BEST %s" % Global.format_time(bt) if bt > 0.0 else "NO RECORD", p + Vector2(0, r + 86.0), 19, Global.C_GOLD if bt > 0.0 else Color(0.5, 0.55, 0.65))
