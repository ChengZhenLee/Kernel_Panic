extends Control
## CODEX: every enemy, modifier, boss, hazard, status effect, weapon and class, as a book. Each page shows the real in-game sprite, drawn by the game's own
## enemy and boss scripts. Entries stay blacked out until you meet them in a run, then show a kill count.
## Flip pages with the arrows, by swiping, or with the left and right keys; the bookmarks jump to a section.

const CodexData = preload("res://scripts/codex_data.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BossScript = preload("res://scripts/boss.gd")
const BossData = preload("res://scripts/boss_data.gd")
const IconArt = preload("res://scripts/icon_art.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const CageScript = preload("res://scripts/ui/codex_cage.gd")


## A class avatar for the CLASSES pages: the pixel avatar alone (a class without art shows its icon).
class ClassSprite extends Node2D:
	var cid := ""
	var icon := ""
	var col := Color.WHITE
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := 64.0
		var avatar: Texture2D = PixelArt.class_tex(cid)
		if avatar != null:
			PixelArt.draw_class(self, avatar, Vector2(0.0, -r * 0.08), r * 2.5, t)
		elif icon == "":
			var f := Vector2.from_angle(t * 0.8)
			var s := f.orthogonal()
			draw_colored_polygon(PackedVector2Array([f * r * 0.5, -f * r * 0.27 + s * r * 0.32, -f * r * 0.09, -f * r * 0.27 - s * r * 0.32]), Color(0.9, 1.0, 1.0))
		else:
			IconArt.draw_icon(self, icon, Vector2.ZERO, r * 0.55, col, t)

## A status effect or weapon (its icon) or a combo (the two icons that react, with a plus between) for the STATUS pages.
class StatusSprite extends Node2D:
	var icons := []
	var cols := []
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var n := icons.size()
		var s := 56.0 if n == 1 else 32.0
		var gap := s * 2.7 + 32.0 if n == 2 else s * 2.6
		for i in n:
			var c := Vector2((i - (n - 1) * 0.5) * gap, 0.0)
			IconArt.draw_icon(self, icons[i], c + Vector2(0.0, sin(t * 2.0 + i) * 3.0), s, cols[i], t)
		if n == 2:
			draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Color.WHITE, 4.0)
			draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), Color.WHITE, 4.0)

## A hazard zone for the HAZARDS pages: drawn by the game's own zone code, looping its clock.
class HazardSprite extends Node2D:
	const HazardScript = preload("res://scripts/hazards.gd")
	var id := ""
	var col := Color.WHITE
	var t := 0.0
	var page: Texture2D   # looked up once, not on every redraw
	var frame := -1

	func _ready() -> void:
		page = PixelArt.hazard_tex(id)

	func _process(delta: float) -> void:
		t += delta
		var f := _frame() if page != null else PixelArt.HAZARD_FRAMES
		if page == null or f != frame or LIVES.has(id):   # the pixel page only changes when its frame does; the timed zones that fade out redraw every frame
			frame = f
			queue_redraw()

	## Seconds the page's clock runs before it starts over (the timed zones play their whole life, then a beat of rest).
	const CYCLES := {"vent": 5.2, "strike": 3.6, "flux": 8.0, "arc": 3.0}
	const LIVES := {"vent": 4.7, "strike": 3.0}   # fade-outs, same as a run (EVENTS life)

	func _frame() -> int:
		if CYCLES.has(id):   # same frame mapping and clock as a run
			return HazardScript.frame_at(id, fmod(t, CYCLES[id]))
		return int(t * 5.0) % PixelArt.hazard_frames(page)   # the steady zones drift along at 5 pages a second

	func _draw() -> void:
		var cycle := 4.0 if id in ["vent", "flux"] else (1.8 if id == "strike" else 3.0)
		if page != null:   # the pixel picture of the zone, looping
			var ct: float = fmod(t, CYCLES[id]) if CYCLES.has(id) else t
			var vis := 1.0
			if LIVES.has(id):
				vis = HazardScript.zone_fade({"id": id, "t": ct, "life": LIVES[id]})
			var art_r: float = HazardScript.ART_R.get(id, 0.0)
			PixelArt.draw_hazard_zone(self, page, Vector2.ZERO, 62.0 if art_r > 0.0 else 70.0, ct, vis, 0.0, -1, _frame(), art_r)
			if id == "strike":
				HazardScript.draw_strike_beam(self, Vector2.ZERO, 62.0, ct, vis, 220.0)
			return
		HazardScript.draw_zone(self, id, Vector2.ZERO, 70.0, col, fmod(t, cycle))


var entries := []        # flat list of {"entry": dict, "section": name}
var spread := 0          # index of the left page / 2
var pages := []          # [page panel, sprite anchor, name, desc, kills]
var page_label: Label
var bookmarks := {}
var prev_button: Button
var next_button: Button
var drag_start := Vector2.ZERO
var dragging := false
const BOSS_BOOST := {"popupking": 1.6, "megaworm": 1.5, "keylogger": 1.4, "phisher": 1.4, "baseband": 1.3}   # bosses whose drawing is small for their radius
const ZOOM_MIN := 0.6
const ZOOM_MAX := 3.0
var view_zoom := [1.0, 1.0]            # per page: zoom and pan of the sprite
var view_pan := [Vector2.ZERO, Vector2.ZERO]
var pan_page := -1                      # page whose sprite is being dragged
var zoom_boxes := []


func _ready() -> void:
	Music.play_title()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := Global.safe_margins()
	var seen := 0
	for sec in CodexData.sections():
		for e in sec[1]:
			entries.append({"entry": e, "section": sec[0]})
			if _known(e):
				seen += 1
	# left sidebar like the UNLOCKS page: BACK, the title and one stacked button per section, so nothing runs off a narrow screen
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	add_child(side)
	side.position = Vector2(14.0 + m["left"], 12.0 + m["top"])
	side.custom_minimum_size = Vector2(190, 0)
	var back := Button.new()
	back.text = "< BACK"
	back.custom_minimum_size = Vector2(190, 46)
	back.focus_mode = Control.FOCUS_NONE
	side.add_child(back)
	back.pressed.connect(func():
		Sfx.play("select")
		on_back())
	var title := Label.new()
	title.text = "CODEX %d/%d" % [seen, entries.size()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Global.FONT_TITLE)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Global.C_CYAN)
	side.add_child(title)
	for sec in CodexData.sections():
		var name: String = sec[0]
		var b := Button.new()
		b.text = name
		b.custom_minimum_size = Vector2(190, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Global.FONT_TITLE)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): _jump(name))
		side.add_child(b)
		bookmarks[name] = b

	# the book: two pages and a spine
	var book := HBoxContainer.new()
	book.add_theme_constant_override("separation", 0)
	add_child(book)
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.offset_top = 12.0 + m["top"]
	book.offset_bottom = -84.0 - m["bottom"]
	book.offset_left = 222.0 + m["left"]
	book.offset_right = -16.0 - m["right"]
	pages.append(_make_page(book))   # one entry per page

	# page controls
	var ctl := HBoxContainer.new()
	ctl.alignment = BoxContainer.ALIGNMENT_CENTER
	ctl.add_theme_constant_override("separation", 20)
	add_child(ctl)
	ctl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ctl.offset_left = 222.0 + m["left"]
	ctl.offset_right = -16.0 - m["right"]
	ctl.offset_top = -76.0 - m["bottom"]
	ctl.offset_bottom = -14.0 - m["bottom"]
	prev_button = _flip_button("<", ctl, -1)
	page_label = Label.new()
	page_label.custom_minimum_size = Vector2(220, 0)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_label.add_theme_font_override("font", Global.FONT_TITLE)
	page_label.add_theme_font_size_override("font_size", 14)
	ctl.add_child(page_label)
	next_button = _flip_button(">", ctl, 1)
	_show_spread()


## Enemies, modifiers and bosses are known once met; a class or base weapon once it can be bought (or is owned); an evolution once found in a run.
func _known(e: Dictionary) -> bool:
	var key := String(e["key"])
	if key.begins_with("weapon:"):
		var wid := key.substr(7)
		if wid.begins_with("evo_"):
			return Meta.evolutions_found.has(wid) or Meta.codex.has(key)
		return Meta.weapon_owned(wid) or Meta.weapon_available(wid) or Meta.codex.has(key)
	if key.begins_with("class:"):
		var id := key.substr(6)
	if key.begins_with("class:"):
		var id := key.substr(6)
		return id == "" or Meta.class_available(id) or Meta.class_owned(id)
	return Meta.codex.has(key)


func _flip_button(text: String, parent: Node, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _flip(dir))
	parent.add_child(b)
	return b


func _make_page(parent: Node) -> Array:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(pc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	pc.add_child(row)
	var idx := pages.size()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(240, 260)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.clip_contents = true
	row.add_child(holder)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(240, 0)   # small minimums: the page must never be wider than the screen
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.clip_contents = true
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(col)
	var sec := Label.new()
	sec.add_theme_font_override("font", Global.FONT_TITLE)
	sec.add_theme_font_size_override("font_size", 12)
	sec.add_theme_color_override("font_color", Global.C_GOLD)
	sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sec)
	var anchor := Node2D.new()
	holder.add_child(anchor)
	pc.clip_contents = true
	holder.resized.connect(func(): _apply_view(idx))
	var zbox := HBoxContainer.new()
	zbox.add_theme_constant_override("separation", 4)
	holder.add_child(zbox)
	zbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	zbox.offset_left = -170.0
	zbox.offset_right = -4.0
	zbox.offset_top = 4.0
	for z in [["-", 1.0 / 1.3], ["+", 1.3], ["1x", 0.0]]:
		var zb := Button.new()
		zb.text = z[0]
		zb.custom_minimum_size = Vector2(52, 40)
		zb.focus_mode = Control.FOCUS_NONE
		var f: float = z[1]
		zb.pressed.connect(func(): _zoom_view(idx, f, holder.size / 2.0))
		zbox.add_child(zb)
	zoom_boxes.append(zbox)
	var name := Label.new()
	name.add_theme_font_override("font", Global.FONT_TITLE)
	name.add_theme_font_size_override("font_size", 20)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name)
	var desc := Label.new()
	desc.add_theme_font_override("font", Global.FONT_BODY)
	desc.add_theme_font_size_override("font_size", 22)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	var kills := Label.new()
	kills.add_theme_font_override("font", Global.FONT_BODY)
	kills.add_theme_font_size_override("font_size", 22)
	kills.add_theme_color_override("font_color", Global.C_GREEN)
	kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kills)
	return [pc, anchor, name, desc, kills, sec]


func _show_spread() -> void:
	var last := entries.size() - 1
	spread = clampi(spread, 0, last)
	for i in pages.size():
		var idx := spread + i
		var pg: Array = pages[i]
		for c in pg[1].get_children():
			c.queue_free()
		pg[0].visible = idx < entries.size()
		if idx >= entries.size():
			continue
		var item: Dictionary = entries[idx]
		var e: Dictionary = item["entry"]
		var entry = Meta.codex.get(e["key"])
		var known: bool = _known(e)
		if entry == null:
			entry = {}
		var col: Color = e["color"]
		pg[0].add_theme_stylebox_override("panel", Global.make_box(Color(0.04, 0.07, 0.1, 0.96), Color(col, 0.8) if known else Color(0.3, 0.33, 0.4, 0.7), 2, 8, 6))
		pg[5].text = item["section"]
		pg[2].text = e["name"] if known else "? ? ? ? ?"
		pg[2].add_theme_color_override("font_color", col if known else Color(0.45, 0.5, 0.58))
		pg[3].text = e["desc"] if known else ("Not found yet." if item["section"] in ["CLASSES", "WEAPONS"] else "Not encountered yet.")
		if known and item["section"] == "WEAPONS":
			pg[3].text += "\n\n" + _weapon_status(String(e["key"]).substr(7))
		pg[3].add_theme_color_override("font_color", Color(0.8, 0.9, 0.95) if known else Color(0.45, 0.5, 0.58))
		pg[4].text = ("Deleted: %d" % int(entry.get("kills", 0))) if known and not (item["section"] in ["CLASSES", "HAZARDS", "STATUS"]) else ""
		if known and item["section"] == "STATUS":
			pg[4].text = ("Triggered: %d" % int(entry.get("applied", 0))) if String(e["key"]).begins_with("combo:") else ("Kills: %d" % int(entry.get("kills", 0)))
		if known and item["section"] == "WEAPONS":
			pg[4].text = "Kills: %d" % int(entry.get("kills", 0))
		var sprite = _make_sprite(e["key"])
		var stat = sprite.creature if sprite != null and sprite.has_method("fit") else sprite
		if known and sprite != null and String(e["key"]).begins_with("enemy:"):
			# base stats at minute 0, with the device multipliers divided out
			pg[4].text += "\nHP %d   SPEED %d   DAMAGE %d   XP %d" % [roundi(stat.max_hp / Meta.enemy_hp_mult()), roundi(stat.speed), roundi(stat.damage / Meta.enemy_dmg_mult()), stat.xp_value]
		if known and sprite != null and String(e["key"]).begins_with("boss:"):
			# boss health at minute 0 on the first device (it grows with the device and the run clock)
			pg[4].text += "\nHP %d   DAMAGE %d   XP %d" % [roundi(stat.max_hp / Meta.enemy_hp_mult()), roundi(stat.damage / Meta.enemy_dmg_mult()), stat.xp_value]
		if sprite != null:
			if not known:
				if sprite.has_method("set_unknown"):
					sprite.set_unknown(true)
				else:
					sprite.modulate = Color(0.0, 0.0, 0.0)
			pg[1].add_child(sprite)
		view_zoom[i] = 1.0
		view_pan[i] = Vector2.ZERO
		_apply_view(i)
	page_label.text = "%d / %d" % [spread + 1, last + 1]
	prev_button.disabled = spread <= 0
	next_button.disabled = spread >= last
	var first_sec: String = entries[spread]["section"]
	for k in bookmarks:
		bookmarks[k].modulate = Color.WHITE if k == first_sec else Color(0.6, 0.65, 0.7)


## Unlock state of a weapon (this used to be the WEAPONS tab of the UNLOCKS page).
func _weapon_status(id: String) -> String:
	var n: Dictionary = Meta.by_id.get(Meta.unlock_node.get("weapon:" + id, ""), {})
	if not n.is_empty() and Meta.is_granted_node(n):   # evolved and challenge weapons are given, never bought
		return "UNLOCKED: in your arsenal for good." if Meta.weapon_owned(id) else "LOCKED: " + Meta.lock_reason(n)
	if Meta.weapon_owned(id):
		return "BOUGHT: in your arsenal."
	if Meta.weapon_available(id):
		return "AVAILABLE: buy and upgrade it in the ARSENAL tree (again after every reformat)."
	return "LOCKED: " + Meta.unlock_hint("weapon:" + id)


## The sprite is the game's own enemy or boss node, never added to a run, so it draws exactly like in game.
func _make_sprite(key: String):
	var parts := key.split(":")
	var kind := parts[0]
	var id := parts[1]
	if kind == "class":
		var cs := ClassSprite.new()
		cs.cid = id
		for e in CodexData.classes():
			if e["key"] == key:
				cs.icon = e["icon"]
				cs.col = e["color"]
		cs.scale = Vector2.ONE * 1.7
		return cs
	if kind == "weapon":   # the weapon's own icon in a ring, like a status page
		var ws := StatusSprite.new()
		for e in CodexData.weapons():
			if e["key"] == key:
				ws.icons = [e["icon"]]
				ws.cols = [e["color"]]
		ws.scale = Vector2.ONE * 1.3
		return ws
	if kind == "status" or kind == "combo":
		var ss := StatusSprite.new()
		for e in CodexData.status_pages():
			if e["key"] == key:
				if kind == "status":
					ss.icons = [e["icon"]]
					ss.cols = [e["color"]]
				else:
					for p in e["parts"]:
						ss.icons.append(p)
						ss.cols.append(CodexData.STATUS_EFFECTS[["burn", "poison", "freeze", "shock"].find(p)]["color"])
		ss.scale = Vector2.ONE * 1.3
		return ss
	if kind == "hazard":
		var hs := HazardSprite.new()
		hs.id = id
		for h in preload("res://scripts/hazards.gd").TYPES:
			if h["id"] == id:
				hs.col = h["color"]
		return hs
	if kind == "enemy":
		var e = EnemyScript.new()
		e.setup(id, 0.0, false)
		return _cage(e, "enemy")
	if kind == "affix":
		var e = EnemyScript.new()
		e.setup("trojan", 0.0, true)
		e.affix = id
		e.display_name = ""
		return _cage(e, "affix")
	if kind == "boss":
		var def := {}
		var slot := 0
		if BossData.MID.has(id):
			def = BossData.MID[id].duplicate()
			def["id"] = id
		else:
			for f in BossData.FINALS:
				if f["id"] == id:
					def = f.duplicate()
					slot = 3
		if def.is_empty():
			return null
		var b = BossScript.new()
		b.setup_boss(def, slot, 0.0)
		return _cage(b, "boss", BOSS_BOOST.get(id, 1.0))
	return null


## Puts the creature node in a roaming cage; stats are still read from the node (it keeps its own fields).
func _cage(creature, kind: String, boost := 1.0):
	var cage = CageScript.new()
	cage.setup(creature, kind, boost)
	return cage


func _apply_view(i: int) -> void:
	var anchor: Node2D = pages[i][1]
	var holder: Control = anchor.get_parent()
	var lim: Vector2 = holder.size * 0.5 * maxf(view_zoom[i], 1.0)   # how far the sprite may be dragged off centre
	view_pan[i] = Vector2(clampf(view_pan[i].x, -lim.x, lim.x), clampf(view_pan[i].y, -lim.y, lim.y))
	for c in anchor.get_children():
		if c.has_method("fit"):
			c.fit(holder.size - Vector2(24.0, 70.0))
			c.position.y = 24.0
	anchor.scale = Vector2.ONE * view_zoom[i]
	anchor.position = holder.size / 2.0 + view_pan[i]


## factor 0 resets the view; otherwise zoom about the point `at` (holder coordinates).
func _zoom_view(i: int, factor: float, at: Vector2) -> void:
	var holder: Control = pages[i][1].get_parent()
	if factor == 0.0:
		view_zoom[i] = 1.0
		view_pan[i] = Vector2.ZERO
	else:
		var old: float = view_zoom[i]
		var nz := clampf(old * factor, ZOOM_MIN, ZOOM_MAX)
		var centre: Vector2 = holder.size / 2.0 + view_pan[i]
		view_pan[i] = view_pan[i] + (at - centre) * (1.0 - nz / old)   # keeps the point under the cursor fixed
		view_zoom[i] = nz
	_apply_view(i)


func _holder_at(pos: Vector2) -> int:
	for i in pages.size():
		if not pages[i][0].visible:
			continue
		var holder: Control = pages[i][1].get_parent()
		if holder.get_global_rect().has_point(pos) and not zoom_boxes[i].get_global_rect().has_point(pos):
			return i
	return -1


func _flip(dir: int) -> void:
	var before := spread
	spread += dir
	_show_spread()
	if spread != before:
		Sfx.play("hover")


func _jump(section: String) -> void:
	for i in entries.size():
		if entries[i]["section"] == section:
			spread = i
			break
	_show_spread()
	Sfx.play("select")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_flip(1)
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_flip(-1)
	elif event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var wi := _holder_at(event.position)
		if wi >= 0 and event.pressed:
			var holder: Control = pages[wi][1].get_parent()
			_zoom_view(wi, 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15, event.position - holder.get_global_rect().position)
	elif event is InputEventMouseMotion and pan_page >= 0:
		view_pan[pan_page] += event.relative
		_apply_view(pan_page)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			pan_page = -1
		if event.pressed and _holder_at(event.position) >= 0:
			pan_page = _holder_at(event.position)   # dragging the sprite pans it instead of flipping the page
		elif event.pressed:
			drag_start = event.position
			dragging = true
		elif dragging:
			dragging = false
			var dx: float = event.position.x - drag_start.x
			if absf(dx) > 90.0 and absf(event.position.y - drag_start.y) < 120.0:
				_flip(-1 if dx > 0.0 else 1)


func on_back() -> void:
	Global.change_scene("res://scenes/unlocks.tscn")
