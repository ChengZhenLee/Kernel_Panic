extends Control
## RESEARCH: the permanent tech tree.
## Tap/click a node to inspect it, then BUY (or tap it again). Drag to pan, pinch / scroll to zoom.
## Outer rings are gated behind bosses beaten on the current device.

const IconArt = preload("res://scripts/icon_art.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const TreeData = preload("res://scripts/tree_data.gd")
const IconView = preload("res://scripts/ui/icon_view.gd")
const DEFAULT_ZOOM := 0.62

var cam := Vector2.ZERO
var zoom := DEFAULT_ZOOM
var t := 0.0
var hover_id := ""
var selected := ""
var pop := {}
var shake_n := {}
var particles := []
var rings := []
var shown_data := 0.0
var tab := "system"   # which tree is shown: "system" (DATA), "arsenal" (DATA; evolved weapons sit here too once found), "classes" (DATA) or "prestige" (prestige points)
var tab_buttons := {}

# input state
var touches := {}
var multi := false
var pinch_dist := 0.0
var mouse_down := false
var press_pos := Vector2.ZERO
var moved := 0.0

var top_bar: PanelContainer
var data_label: Label
var complete_label: Label
var complete_bar: ProgressBar
var device_label: Label
var prestige_button: Button
var zoom_box: HBoxContainer
var panel: PanelContainer
var p_icon
var p_name: Label
var p_info: Label
var p_desc: Label
var p_cost: Label
var buy_button: Button
var hold_t := 0.0        # how long BUY has been held; past HOLD_DELAY it keeps buying, faster the longer it is held
var hold_next := 0.0
const HOLD_DELAY := 0.45
var auto_button: Button   # ON / OFF switch for the auto-pick prestige nodes
var dialog: Control
var dialog_text: Label


func _ready() -> void:
	Music.play_title()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown_data = Meta.data
	_build_ui()
	_refresh()
	_go_home.call_deferred()


# ---------------- UI ----------------

func _label(text: String, font: Font, fsize: int, color: Color, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(text: String, parent: Node, cb: Callable, min_size := Vector2(150, 60)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("hover"))
	parent.add_child(b)
	return b


func _build_ui() -> void:
	var m := Global.safe_margins()

	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", Global.make_box(Color(0.02, 0.03, 0.07, 0.94), Color(Global.C_CYAN, 0.4), 0, 0, 0))
	add_child(top_bar)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 64 + m["top"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top_bar.add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(m["left"], 0)
	row.add_child(pad)
	_button("< BACK", row, func(): Global.change_scene("res://scenes/menu.tscn"), Vector2(110, 48))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_label("RESEARCH", Global.FONT_TITLE, 16, Global.C_CYAN, col)
	device_label = _label("", Global.FONT_BODY, 18, Color(0.7, 0.85, 0.9), col)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var comp := VBoxContainer.new()
	comp.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(comp)
	complete_label = _label("", Global.FONT_BODY, 18, Color.WHITE, comp)
	complete_bar = ProgressBar.new()
	complete_bar.show_percentage = false
	complete_bar.custom_minimum_size = Vector2(150, 10)
	comp.add_child(complete_bar)
	data_label = _label("", Global.FONT_TITLE, 14, Global.C_GOLD, row)
	data_label.custom_minimum_size = Vector2(170, 0)
	data_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	data_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	data_label.size_flags_vertical = Control.SIZE_FILL
	prestige_button = _button("REFORMAT", row, _open_dialog)
	prestige_button.add_theme_font_size_override("font_size", 14)
	prestige_button.custom_minimum_size = Vector2(110, 48)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(m["right"], 0)
	row.add_child(pad2)

	# tree tabs
	var tab_box := HBoxContainer.new()
	tab_box.add_theme_constant_override("separation", 6)
	add_child(tab_box)
	tab_box.position = Vector2(16 + m["left"], 72 + m["top"])
	for pair in [["system", "SYSTEM"], ["arsenal", "ARSENAL"], ["classes", "CLASSES"], ["prestige", "PRESTIGE"]]:
		var key: String = pair[0]
		tab_buttons[key] = _button(pair[1], tab_box, func(): _set_tab(key), Vector2(120, 44))

	# zoom controls
	zoom_box = HBoxContainer.new()
	zoom_box.add_theme_constant_override("separation", 10)
	add_child(zoom_box)
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	zoom_box.offset_left = 16 + m["left"]
	zoom_box.offset_top = -80 - m["bottom"]
	zoom_box.offset_bottom = -16 - m["bottom"]
	_button("-", zoom_box, func(): _zoom_at(_tree_center(), 1.0 / 1.25), Vector2(64, 64))
	_button("+", zoom_box, func(): _zoom_at(_tree_center(), 1.25), Vector2(64, 64))
	_button("CENTER", zoom_box, _center_view, Vector2(130, 64))

	var hint := _label("DRAG pan   PINCH zoom   TAP node, then BUY" if Global.is_touch else "DRAG pan   SCROLL zoom   CLICK node, then BUY",
		Global.FONT_BODY, 18, Color(0.55, 0.7, 0.75), self)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40 - m["bottom"]
	hint.offset_bottom = -12 - m["bottom"]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.offset_right = -16 - m["right"]

	# detail panel (right side)
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -380 - m["right"]
	panel.offset_right = -14 - m["right"]
	panel.offset_top = 74 + m["top"]
	panel.offset_bottom = -96 - m["bottom"]
	var pb := VBoxContainer.new()
	pb.add_theme_constant_override("separation", 10)
	panel.add_child(pb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	pb.add_child(head)
	p_icon = IconView.new()
	p_icon.custom_minimum_size = Vector2(92, 92)
	head.add_child(p_icon)
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	p_name = _label("", Global.FONT_TITLE, 14, Color.WHITE, hv)
	p_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_name.custom_minimum_size = Vector2(200, 0)
	p_info = _label("", Global.FONT_BODY, 24, Color(0.65, 0.8, 0.85), hv)
	p_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_info.custom_minimum_size = Vector2(200, 0)
	p_desc = _label("", Global.FONT_BODY, 28, Color(0.88, 0.96, 1.0), pb)
	p_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_desc.custom_minimum_size = Vector2(320, 0)
	p_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p_cost = _label("", Global.FONT_BODY, 30, Global.C_GOLD, pb)
	p_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_cost.custom_minimum_size = Vector2(320, 0)
	buy_button = _button("RESEARCH", pb, _buy_selected, Vector2(320, 70))
	buy_button.add_theme_font_override("font", Global.FONT_TITLE)
	buy_button.add_theme_font_size_override("font_size", 18)
	buy_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS   # buy on press so holding can repeat
	buy_button.button_down.connect(func():
		hold_t = 0.0
		hold_next = HOLD_DELAY)
	auto_button = _button("", pb, _toggle_selected_auto, Vector2(320, 56))
	auto_button.add_theme_font_override("font", Global.FONT_TITLE)
	auto_button.add_theme_font_size_override("font_size", 16)
	panel.hide()

	# prestige dialog
	dialog = ColorRect.new()
	dialog.color = Color(0, 0.01, 0.03, 0.88)
	add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	dialog.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dpanel := PanelContainer.new()
	dpanel.add_theme_stylebox_override("panel", Global.make_box(Color(0.06, 0.04, 0.01, 0.97), Global.C_GOLD, 2, 30, 4))
	cc.add_child(dpanel)
	var db := VBoxContainer.new()
	db.add_theme_constant_override("separation", 14)
	dpanel.add_child(db)
	_label("REFORMAT", Global.FONT_TITLE, 22, Global.C_GOLD, db).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_text = _label("", Global.FONT_BODY, 28, Color(0.9, 0.95, 1.0), db)
	dialog_text.custom_minimum_size = Vector2(620, 0)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 20)
	db.add_child(brow)
	_button("REFORMAT", brow, _do_prestige, Vector2(200, 64))
	_button("CANCEL", brow, func(): dialog.hide(), Vector2(200, 64))
	dialog.hide()


func _nodes() -> Array:
	return Meta.tree_nodes(tab).filter(func(n): return Meta.node_shown(n))


## Starting view per tree: fitted so every visible node and its label is on screen (under the tab buttons, above the hint line).
## Returns [camera offset, zoom]; a tree that has grown past the minimum zoom just starts as wide as it can and is panned from there.
func _fit_home() -> Array:
	var nodes := _nodes()
	if nodes.is_empty() or size.x < 100.0:
		return [Vector2(0, 100), DEFAULT_ZOOM]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n in nodes:
		var p := Meta.node_pos(n)
		lo = lo.min(p - Vector2(130, 50))
		hi = hi.max(p + Vector2(130, 100))
	var m := Global.safe_margins()
	var area := Rect2(Vector2(16.0 + m["left"], 130.0 + m["top"]), Vector2(size.x - 32.0 - m["left"] - m["right"], size.y - 130.0 - m["top"] - 70.0 - m["bottom"]))
	var z := clampf(minf(area.size.x / (hi.x - lo.x), area.size.y / (hi.y - lo.y)), 0.16, 0.7)
	var centre := (lo + hi) / 2.0
	return [area.get_center() - centre * z - _tree_center(), z]


func _go_home() -> void:
	var f := _fit_home()
	cam = f[0]
	zoom = f[1]


func _set_tab(name: String) -> void:
	if name == tab:
		return
	tab = name
	Sfx.play("hover", 1.1)
	_select("")
	_go_home()
	_refresh()


func _refresh() -> void:
	device_label.text = "%s  -  CURED %d" % [Meta.device_name(), Meta.devices_cured]
	var c := Meta.completion()
	if tab == "prestige":
		complete_label.get_parent().show()   # prestige points already show in the top right; this spot counts the reformats instead
		complete_label.text = "REFORMS: %d" % Meta.prestige
		complete_bar.hide()
	else:
		complete_label.get_parent().show()
		complete_bar.show()
		complete_label.text = "RESEARCHED %.1f%%" % (c * 100.0)
		complete_bar.value = c * 100.0
	for k in tab_buttons:
		tab_buttons[k].modulate = Color.WHITE if k == tab else Color(0.6, 0.65, 0.7)
	prestige_button.disabled = not Meta.can_prestige()
	if selected != "":
		_show_panel(selected)


# ---------------- coordinates ----------------

func _tree_center() -> Vector2:
	return Vector2(size.x / 2.0, (size.y + 84.0) / 2.0)


func _origin() -> Vector2:
	return _tree_center() + cam


func to_screen(world: Vector2) -> Vector2:
	return _origin() + world * zoom


func to_world(screen: Vector2) -> Vector2:
	return (screen - _origin()) / zoom


## ARSENAL and CLASSES unlock nodes are octagons of the same size as the core node (PACKET GUN, BASIC).
func _big_octagon(n: Dictionary) -> bool:
	return n["kind"] == "unlock" and (n["tree"] == "arsenal" or n["tree"] == "classes")


func node_radius(n: Dictionary) -> float:
	if _big_octagon(n):
		return 46.0
	match n["kind"]:
		"core":
			return 46.0
		"ult":
			return 40.0
		"major", "unlock", "prestige":
			return 36.0
	return 32.0


func _node_at(screen: Vector2) -> String:
	var w := to_world(screen)
	var best := ""
	var best_d := INF
	for n in _nodes():
		var d := Meta.node_pos(n).distance_to(w)
		# generous hit area for fingers: at least ~34px on screen
		var hit := maxf(node_radius(n) + 6.0, 34.0 / zoom)
		if d < hit and d < best_d:
			best_d = d
			best = n["id"]
	return best


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := to_world(screen_pos)
	zoom = clampf(zoom * factor, 0.16, 1.8)
	cam += screen_pos - to_screen(before)


func _center_view() -> void:
	var tw := create_tween().set_parallel()
	var f := _fit_home()
	tw.tween_property(self, "cam", f[0], 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "zoom", f[1], 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------------- input ----------------

func _over_ui(pos: Vector2) -> bool:
	if dialog.visible:
		return true
	for c in [top_bar, zoom_box, panel]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return false


func _input(event: InputEvent) -> void:
	if dialog.visible:
		return
	# --- touch (phones/tablets) ---
	if event is InputEventScreenTouch:
		if event.pressed:
			if touches.is_empty() and _over_ui(event.position):
				return
			touches[event.index] = event.position
			if touches.size() == 1:
				press_pos = event.position
				moved = 0.0
				multi = false
			elif touches.size() == 2:
				multi = true
				pinch_dist = _pinch_distance()
		elif touches.has(event.index):
			touches.erase(event.index)
			if touches.is_empty():
				if not multi and moved < 18.0:
					_tap(event.position)
				multi = false
			elif touches.size() == 1:
				pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		if touches.size() == 1 and not multi:
			cam += event.relative
			moved += event.relative.length()
		elif touches.size() >= 2:
			var d := _pinch_distance()
			if pinch_dist > 0.0 and d > 0.0:
				var keys := touches.keys()
				var mid: Vector2 = (touches[keys[0]] + touches[keys[1]]) / 2.0
				_zoom_at(mid, d / pinch_dist)
			pinch_dist = d
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		cam -= event.delta * 12.0
	# --- mouse (desktop). Touch-emulated mouse events are ignored: touch is handled above ---
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _over_ui(event.position):
					return
				mouse_down = true
				moved = 0.0
				press_pos = event.position
			elif mouse_down:
				mouse_down = false
				if moved < 8.0:
					_tap(event.position)
		elif event.pressed and not _over_ui(event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(event.position, 1.12)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(event.position, 1.0 / 1.12)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if mouse_down:
			cam += event.relative
			moved += event.relative.length()
		hover_id = "" if _over_ui(event.position) else _node_at(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and selected != "":
			_buy_selected()


func _pinch_distance() -> float:
	var keys := touches.keys()
	if keys.size() < 2:
		return 0.0
	return (touches[keys[0]] as Vector2).distance_to(touches[keys[1]])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		on_back()


func on_back() -> void:
	if dialog.visible:
		dialog.hide()
	elif selected != "":
		_select("")
	else:
		Global.change_scene("res://scenes/menu.tscn")


func _tap(pos: Vector2) -> void:
	var id := _node_at(pos)
	if id == "":
		_select("")
		return
	if id == selected:
		_buy_selected()  # tapping the selected node again buys it
	else:
		_select(id)


func _select(id: String) -> void:
	selected = id
	if id == "":
		panel.hide()
		return
	Sfx.play("hover", 1.3)
	_show_panel(id)
	# keep the node visible to the left of the panel
	var sp := to_screen(Meta.node_pos(Meta.by_id[id]))
	var limit := size.x - 420.0
	if sp.x > limit:
		create_tween().tween_property(self, "cam", cam + Vector2(limit - sp.x - 40.0, 0), 0.25).set_trans(Tween.TRANS_CUBIC)


## The stat key of an auto-pick node ("autolevel", "autocache"), or "" for any other node.
func _auto_key(n: Dictionary) -> String:
	for e in n["effects"]:
		if e[0] in ["autolevel", "autocache"]:
			return e[0]
	return ""


func _toggle_selected_auto() -> void:
	if selected == "":
		return
	var key := _auto_key(Meta.by_id[selected])
	if key != "" and Meta.rank(selected) > 0:
		Meta.toggle_auto(key)
		_show_panel(selected)


func _show_panel(id: String) -> void:
	var n: Dictionary = Meta.by_id[id]
	var r := Meta.rank(id)
	var akey := _auto_key(n)
	auto_button.visible = akey != "" and r > 0
	if auto_button.visible:
		auto_button.text = "AUTO: ON" if Meta.auto_on(akey) else "AUTO: OFF"
		auto_button.add_theme_color_override("font_color", Global.C_GREEN if Meta.auto_on(akey) else Color(0.75, 0.55, 0.3))
	var col: Color = TreeData.BRANCHES[n["branch"]]["color"]
	panel.show()
	panel.add_theme_stylebox_override("panel", Global.make_box(Color(0.02, 0.03, 0.07, 0.96), col, 2, 16, 6))
	p_icon.icon_id = n["icon"] if Meta.is_visible(n) else "key"
	p_icon.color = col
	if not Meta.is_visible(n):
		p_name.text = "ENCRYPTED NODE"
		p_info.text = "Locked"
		p_desc.text = "This research is not available yet."
		p_cost.text = ""
		buy_button.disabled = true
		buy_button.text = "LOCKED"
		return
	p_name.text = n["name"]
	p_name.add_theme_color_override("font_color", col)
	p_info.text = "%s  -  RANK %d / %d" % [TreeData.BRANCHES[n["branch"]]["name"], r, Meta.max_rank(n)]
	if Meta.max_rank(n) >= 999:
		p_info.text = "%s  -  RANK %d" % [TreeData.BRANCHES[n["branch"]]["name"], r]
	if r == 0:
		p_desc.text = Meta.describe(n, 1)
	elif r < Meta.max_rank(n):
		p_desc.text = "NOW:  %s\nNEXT: %s" % [Meta.describe(n, r), Meta.describe(n, r + 1)]
	else:
		p_desc.text = Meta.describe(n, r)
	var reason := Meta.lock_reason(n)
	if Meta.is_granted_node(n) and r > 0:
		p_cost.text = "UNLOCKED FOREVER\nNo purchase needed. Kept through every reformat."
		p_cost.add_theme_color_override("font_color", Global.C_GREEN)
		buy_button.disabled = true
		buy_button.text = "OWNED"
	elif reason != "":
		p_cost.text = "LOCKED\n" + reason
		p_cost.add_theme_color_override("font_color", Global.C_RED)
		buy_button.disabled = true
		buy_button.text = "LOCKED"
	elif r >= Meta.max_rank(n):
		p_cost.text = "FULLY RESEARCHED"
		p_cost.add_theme_color_override("font_color", Global.C_GREEN)
		buy_button.disabled = true
		buy_button.text = "MAXED"
	else:
		var c := Meta.cost(n)
		var have: float = INF if Global.dev_money else (Meta.pp_free() if Meta.uses_pp(n) else Meta.data)
		var unit := "PRESTIGE POINTS" if Meta.uses_pp(n) else "DATA"
		var ok := have >= c
		p_cost.text = "COST  %s %s" % [_fmt(c), unit] + ("" if ok else "\nNeed %s more" % _fmt(c - have))
		if Meta.uses_pp(n) and not ok and Meta.pp_locked > 0 and Meta.pp >= c:
			p_cost.text += "\n%d PP are banked and unlock after your next reformat" % Meta.pp_locked
		p_cost.add_theme_color_override("font_color", Global.C_GOLD if ok else Color(0.75, 0.55, 0.3))
		buy_button.disabled = not ok
		buy_button.text = "RESEARCH" if r == 0 else "UPGRADE"


func _buy_selected() -> bool:
	if selected == "":
		return false
	var id := selected
	var n: Dictionary = Meta.by_id[id]
	if Meta.buy(id):
		var r := Meta.rank(id)
		pop[id] = 1.0
		var col: Color = TreeData.BRANCHES[n["branch"]]["color"]
		_spawn_particles(Meta.node_pos(n), col, 26 + r * 4)
		rings.append([Meta.node_pos(n), 1.0, col])
		if r >= Meta.max_rank(n):
			rings.append([Meta.node_pos(n), 1.0, Global.C_GOLD])
			_spawn_particles(Meta.node_pos(n), Global.C_GOLD, 50)
			Sfx.play("levelup", 1.0, 0.0, 0.0)
		elif n["kind"] in ["unlock", "major", "ult", "prestige"]:
			Sfx.play("epic", 1.0, 0.0, 0.0)
		else:
			Sfx.play("buy", 0.9 + r * 0.08, 0.0, 0.0)
		if Global.is_mobile:
			Input.vibrate_handheld(30)
		_refresh()
		if Meta.can_prestige():
			Sfx.play("legendary", 1.0, 0.0, 0.0)
		return true
	shake_n[id] = 1.0
	Sfx.play("deny", 1.0, 0.0, 0.0)
	return false


func _spawn_particles(p: Vector2, col: Color, count: int) -> void:
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 320.0)
		var life := randf_range(0.4, 0.9)
		particles.append([p, v, life, life, col if randf() > 0.25 else Color.WHITE])


func _fmt(v: float) -> String:
	var n := int(v)
	if n >= 1000000:
		return "%.2fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fK" % (n / 1000.0)
	return str(n)


# ---------------- prestige ----------------

func _open_dialog() -> void:
	if not Meta.can_prestige():
		Sfx.play("deny")
		return
	dialog_text.text = ("REFORMAT and restart from the first device?\n\nYou have cured %d device(s) this cycle.\n\n" +
		"- Research ranks, DATA and device progress reset\n" +
		"+ Points earned this cycle become spendable in the PRESTIGE tree\n" +
		"+ Prestige points, the PRESTIGE tree and found evolutions are kept") % [Meta.devices_cured]
	dialog.show()


func _do_prestige() -> void:
	dialog.hide()
	Meta.do_prestige()
	shown_data = 0.0
	Sfx.play("legendary", 1.0, 0.0, 0.0)
	Sfx.play("reform", 1.0, 0.0, 0.0)
	Sfx.play("explode", 0.6, 0.0, 0.0)
	rings.append([Vector2.ZERO, 1.0, Global.C_GOLD])
	_spawn_particles(Vector2.ZERO, Global.C_GOLD, 150)
	_select("")
	_center_view()
	_refresh()


# ---------------- update & draw ----------------

func _process(delta: float) -> void:
	t += delta
	if buy_button.button_pressed and panel.visible and not buy_button.disabled:
		hold_t += delta
		if hold_t >= hold_next:
			# 0.2 s between buys at first, down to 0.05 s after a couple of seconds of holding
			hold_next = hold_t + lerpf(0.2, 0.05, clampf((hold_t - HOLD_DELAY) / 2.0, 0.0, 1.0))
			if not _buy_selected():
				buy_button.release_focus()
				hold_t = -999.0   # out of DATA or maxed: stop repeating until released
	shown_data = lerpf(shown_data, Meta.data, minf(1.0, delta * 8.0))
	if absf(shown_data - Meta.data) < 1.0:
		shown_data = Meta.data
	if Global.dev_money:
		data_label.text = "INFINITE PP" if tab == "prestige" else "INFINITE DATA"
	else:
		data_label.text = (("%s PP" % _fmt(Meta.pp_free())) + (("\n(+%s)" % _fmt(Meta.pp_locked)) if Meta.pp_locked > 0 else "")) if tab == "prestige" else ("%s DATA" % _fmt(shown_data))
	for k in pop.keys():
		pop[k] = maxf(0.0, pop[k] - delta * 3.0)
	for k in shake_n.keys():
		shake_n[k] = maxf(0.0, shake_n[k] - delta * 3.0)
	var drag := pow(0.05, delta)
	for p in particles:
		p[0] += p[1] * delta
		p[1] *= drag
		p[2] -= delta
	particles = particles.filter(func(p): return p[2] > 0.0)
	for r in rings:
		r[1] -= delta * 1.5
	rings = rings.filter(func(r): return r[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.08))
	var o := _origin()
	var step := 64.0 * zoom
	var off := Vector2(fposmod(o.x, step), fposmod(o.y, step))
	var gx := off.x
	while gx < size.x:
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(0.2, 0.45, 0.55, 0.08), 1.0)
		gx += step
	var gy := off.y
	while gy < size.y:
		draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(0.2, 0.45, 0.55, 0.08), 1.0)
		gy += step

	draw_set_transform(o, 0.0, Vector2(zoom, zoom))
	var font: Font = Global.FONT_BODY

	# boss gate rings (the prestige tree is not gated by bosses)
	var gates: Array[int] = []
	if tab == "system":
		gates.assign([1, 2, 3])
	for g in gates:
		var radius: float = (g + 3) * Meta.RING + 40.0 - Meta.RING * 0.5
		var open := Meta.best_boss >= g
		_dashed_circle(Vector2.ZERO, radius, Color(Global.C_GREEN, 0.15) if open else Color(Global.C_RED, 0.4), 2.5 / zoom)
		if not open:
			var txt := "DEFEAT BOSS %d TO DECRYPT" % g
			var fs := 28
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			for ang in [-PI / 2.0 + 0.6, PI / 2.0 + 0.6]:
				var p := Vector2.from_angle(ang) * radius
				draw_string_outline(font, p - Vector2(w / 2.0, -8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.03, 0.035, 0.08))
				draw_string(font, p - Vector2(w / 2.0, -8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.45, 0.45, 0.9))

	# the prestige tree is split into its areas like a pie chart
	if tab == "prestige":
		var areas := ["offense", "defense", "utility", "arsenal", "system"]
		for b in areas:
			var edge := Vector2.from_angle(deg_to_rad(Meta.branch_angle(b, tab) + 36.0))
			var d := 120.0
			while d < 1500.0:
				draw_circle(edge * d, 2.5 / zoom, Color(0.6, 0.75, 0.85, 0.4))   # dotted
				d += 24.0

	# connections
	for n in _nodes():
		if n["parent"] == "" or not Meta.node_shown(Meta.by_id[n["parent"]]):
			continue   # a node can sit beside a spoke that is still hidden
		var a := Meta.node_pos(Meta.by_id[n["parent"]])
		var b := Meta.node_pos(n)
		var col: Color = TreeData.BRANCHES[n["branch"]]["color"]
		var vis := Meta.is_visible(n)
		if Meta.rank(n["id"]) > 0:
			draw_line(a, b, Color(col, 0.3), 12.0)
			draw_line(a, b, col, 4.0)
			draw_circle(a.lerp(b, fmod(t * 0.8 + a.x * 0.001, 1.0)), 5.0, Color.WHITE)
		elif vis and Meta.is_unlocked(n):
			draw_line(a, b, Color(col, 0.7), 3.0)
		else:
			draw_line(a, b, Color(0.55, 0.6, 0.7, 0.35 if vis else 0.15), 2.5)

	# branch titles
	for b in TreeData.BRANCHES:
		if b == "core" or tab == "arsenal" or tab == "classes":
			continue
		var info: Dictionary = TreeData.BRANCHES[b]
		var dir := Vector2.from_angle(deg_to_rad(Meta.branch_angle(b, tab)))
		var deepest := -1
		for n in Meta.tree_nodes(tab):
			if n["branch"] == b and n["lane"] == 0:
				deepest = maxi(deepest, n["depth"])
		if deepest < 0:
			continue
		var p := dir * ((deepest + 0.85) * Meta.RING + 40.0)
		var sy := (p.y + 10.0) * zoom + o.y
		if sy < 150.0 + Global.safe_margins()["top"] or sy > size.y - 90.0:
			continue   # would sit under the header or the hint line
		var fs := 34
		var w := Global.FONT_TITLE.get_string_size(info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(Global.FONT_TITLE, p - Vector2(w / 2.0, -10), info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0.03, 0.035, 0.08))
		draw_string(Global.FONT_TITLE, p - Vector2(w / 2.0, -10), info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(info["color"], 0.6))

	for n in _nodes():
		_draw_node(n, font)

	for r in rings:
		var k: float = 1.0 - r[1]
		draw_arc(r[0], 34.0 + k * 100.0, 0.0, TAU, 40, Color(r[2], r[1]), 5.0)
	for p in particles:
		var k: float = p[2] / p[3]
		var s := 6.0 * k + 1.5
		draw_rect(Rect2(p[0] - Vector2(s, s) * 1.5, Vector2(s, s) * 3.0), Color(p[4], 0.2 * k))
		draw_rect(Rect2(p[0] - Vector2(s, s) * 0.5, Vector2(s, s)), Color(p[4], k))
	draw_set_transform(Vector2.ZERO)


## The in-run class sprite for a CLASSES-tree node (the class and its training node), or null.
func _class_sprite(n: Dictionary) -> Texture2D:
	if n["tree"] != "classes":
		return null
	var id: String = n["id"]
	if id == "ccore":
		return PixelArt.class_run_tex("basic")
	if not id.begins_with("c_"):
		return null
	var cid := id.substr(2)
	if cid.ends_with("_t"):
		cid = cid.substr(0, cid.length() - 2)
	return PixelArt.load_tex("classes/run/%s.png" % cid)


func _draw_node(n: Dictionary, font: Font) -> void:
	var id: String = n["id"]
	var p := Meta.node_pos(n)
	if shake_n.get(id, 0.0) > 0.0:
		p.x += sin(t * 60.0) * 8.0 * shake_n[id]
	var r: float = node_radius(n) * (1.0 + 0.35 * pop.get(id, 0.0))
	var col: Color = TreeData.BRANCHES[n["branch"]]["color"]
	var rank := Meta.rank(id)
	var maxr: int = Meta.max_rank(n)
	var vis := Meta.is_visible(n)
	var unlocked := vis and Meta.is_unlocked(n)
	var maxed := rank >= maxr
	var affordable := unlocked and not maxed and Meta.can_buy(n)
	var is_sel := id == selected
	var hovered := id == hover_id

	if is_sel:
		draw_arc(p, r + 16.0 + 3.0 * sin(t * 6.0), 0.0, TAU, 48, Color.WHITE, 3.0)
	if not vis:
		_shape(n, p, r, Color(0.07, 0.06, 0.12), Color(0.55, 0.45, 0.8, 0.8), 2.5)
		draw_string(Global.FONT_TITLE, p + Vector2(-11, 11), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.7, 0.55, 0.95))
		return

	# locked nodes stay clearly visible: light grey outline and icon
	var fill := Color(0.09, 0.1, 0.14)
	var edge := Color(0.6, 0.65, 0.75, 0.9)
	var icon_col := Color(0.62, 0.66, 0.75, 0.85)
	if unlocked or rank > 0:
		edge = col
		icon_col = col
		fill = Color(col.r * 0.16, col.g * 0.16, col.b * 0.16)
	if rank > 0:
		fill = Color(col.r * 0.3, col.g * 0.3, col.b * 0.3)
		icon_col = col.lightened(0.35)
	if maxed:
		edge = Global.C_GOLD
		fill = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35)

	if affordable:
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(p, r * (1.55 + 0.15 * pulse), Color(col, 0.15 + 0.12 * pulse))
	elif maxed:
		draw_circle(p, r * 1.45, Color(Global.C_GOLD, 0.12))
	if hovered:
		draw_circle(p, r * 1.65, Color(1, 1, 1, 0.08))

	_shape(n, p, r, fill, edge, 3.5 if (hovered or is_sel) else 3.0)
	var cspr: Texture2D = _class_sprite(n)
	if cspr != null:   # class nodes wear the in-run avatar of their class
		var bb := clampf(maxf(icon_col.r, maxf(icon_col.g, icon_col.b)) * 1.15, 0.4, 1.0)
		PixelArt.draw_class(self, cspr, p + Vector2(0.0, -r * 0.05), r * 1.7, t, false, Color(bb, bb, bb, icon_col.a))
	else:
		IconArt.draw_icon(self, n["icon"], p, r * 0.6, icon_col, t)

	if maxr > 1 and (rank > 0 or unlocked):
		var frac := float(rank) / maxr
		draw_arc(p, r + 7.0, 0.0, TAU, 40, Color(0, 0, 0, 0.7), 5.0)
		if frac > 0.0:
			draw_arc(p, r + 7.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, Global.C_GOLD if maxed else col, 5.0)
	if not unlocked and rank == 0:
		_lock(p + Vector2(r * 0.7, r * 0.65), r * 0.34)
	if affordable:
		draw_circle(p + Vector2(-r * 0.75, -r * 0.75), 7.0, Global.C_GOLD)

	if zoom > (0.3 if tab == "arsenal" or tab == "classes" else 0.4) or is_sel or hovered:
		var fs := 24
		var label: String = n["name"]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lp := p + Vector2(-w / 2.0, r + 30.0)
		var a := 1.0 if (unlocked or rank > 0) else 0.7
		draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.03, 0.035, 0.08, a))
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.96, 1.0, a))
		if maxr > 1 and (rank > 0 or unlocked) and not (maxr >= 999 and rank == 0):
			var rt := ("%d/%d" % [rank, maxr]) if maxr < 999 else str(rank)   # endless nodes (ROOT KEY) show no maximum
			var rw := font.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string_outline(font, p + Vector2(-rw / 2.0, r + 52.0), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0.03, 0.035, 0.08))
			draw_string(font, p + Vector2(-rw / 2.0, r + 52.0), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Global.C_GOLD if maxed else col, a))


func _shape(n: Dictionary, p: Vector2, r: float, fill: Color, edge: Color, width: float) -> void:
	var sides := 0
	var rot := 0.0
	match n["kind"]:
		"unlock":
			sides = 8 if _big_octagon(n) else 6
			rot = PI / 8.0 if _big_octagon(n) else PI / 6.0
		"major", "prestige":
			sides = 4
			rot = PI / 4.0
		"ult", "core":
			sides = 8
			rot = PI / 8.0
	if sides == 0:
		draw_circle(p, r, fill)
		draw_arc(p, r, 0.0, TAU, 40, edge, width)
		return
	var pts := PackedVector2Array()
	var rr := r * (1.15 if sides == 4 else 1.05)
	for i in sides:
		pts.append(p + Vector2.from_angle(rot + TAU * i / sides) * rr)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, width)
	if n["kind"] in ["ult", "core"] or _big_octagon(n):
		var pts2 := PackedVector2Array()
		for i in sides + 1:
			pts2.append(p + Vector2.from_angle(rot + TAU * i / sides) * rr * 1.18)
		draw_polyline(pts2, Color(edge, 0.5), 2.0)


func _lock(p: Vector2, s: float) -> void:
	draw_circle(p, s * 1.25, Color(0.03, 0.035, 0.08))
	draw_arc(p + Vector2(0, -s * 0.4), s * 0.5, PI, TAU, 10, Color(0.9, 0.9, 0.95), s * 0.24)
	draw_rect(Rect2(p + Vector2(-s * 0.7, -s * 0.4), Vector2(s * 1.4, s * 1.1)), Color(0.9, 0.9, 0.95))


func _dashed_circle(c: Vector2, r: float, col: Color, w: float) -> void:
	var segs := 90
	for i in segs:
		if i % 2 == 0:
			var a0 := TAU * i / segs
			draw_arc(c, r, a0, a0 + TAU / segs, 3, col, w)
