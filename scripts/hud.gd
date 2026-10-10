extends CanvasLayer
## In-game UI: XP bar, timer, combo, DATA, boss bar, weapon loadout, upgrade cards,
## pause, and the end-of-run results screen.
const ScrollFix = preload("res://scripts/ui/scroll_fix.gd")

signal option_chosen(opt: Dictionary)
signal reroll_requested
signal ban_requested(index: int)
signal ability_requested

const IconView = preload("res://scripts/ui/icon_view.gd")
const CooldownSlot = preload("res://scripts/ui/cooldown_slot.gd")
const ItemData = preload("res://scripts/items.gd")
const StatsData = preload("res://scripts/stats_data.gd")
const Indicators = preload("res://scripts/ui/indicators.gd")
const Joystick = preload("res://scripts/ui/joystick.gd")
const ITEM_COLUMNS := 10   # item slots per row of the bottom strip (10 x 48 fits its 600 px and stays clear of the ability button)
const ITEM_ROW_H := 48
const CARD_W := 236.0
const CARD_H := 352.0

var busy := false
var safe: Control
const Minimap = preload("res://scripts/ui/minimap.gd")
var minimap: Control
const AbilityButton = preload("res://scripts/ui/ability_button.gd")
var ability_button: AbilityButton
var joystick
var pause_button: Button

var xp_bar: ProgressBar
var level_label: Label
var time_label: Label
var tag_label: Label
var threat_label: Label      # overtime only: enemy damage multiplier
var ot_text := ""
var cure_root: Control
var cure_continue: Button
var pause_abandon: Button
var kills_label: Label
var data_label: Label
var combo_label: Label
var combo_bonus_label: Label
var combo_tier_shown := -1
var announce_label: Label
var flash_rect: ColorRect
var hurt_rect: TextureRect
var loadout_box: HBoxContainer
var items_clip: Control          # bottom strip showing one row of items; swipe up / down (or wheel) for the next row
var items_box: GridContainer
var items_row := 0
var items_rows := 1
var items_tween: Tween
var items_label: Label
var items_swipe_from := Vector2.ZERO
var items_swiping := false
var cd_box: HBoxContainer        # top-left: items with a cooldown or counter
var revive_label: Label
var stats_slider: Control      # slide-in stats tab on the right edge of the pause screen
var stats_vbox: VBoxContainer
var stats_open := false
var stats_width := 440.0
var pause_center: Control     # slides left when the stats tab opens
var stats_tween: Tween
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss_fade_left := 0.0
var warning_label: Label

var offer_root: Control
var offer_title: Label
var offer_hint: Label
var offer_hint_default := "CLICK A CARD OR PRESS 1-4"
var cards_box: HBoxContainer
var decrypt_box: VBoxContainer
var decrypt_bar: ProgressBar
var reroll_button: Button
var ban_button: Button
var ban_mode := false   # BAN toggled on: the cards turn red and tapping one bans it

var pause_root: Control
var pause_loadout: Label
var pause_resume: Button
var over_root: Control
var over_panel: PanelContainer
var over_title: Label
var over_device_icon: Control
var over_device_name: Label
var over_stats: Label
var over_data: Label
var over_note: Label
var over_note_panel: PanelContainer
var over_first: Button

var shown_xp := 0.0
var current_options := []
var current_cards := []
var offer_ready_time := 0.0
var choosing := false
var announce_tween: Tween
var combo_tween: Tween
var offer_fade: Tween
var warning_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	hurt_rect = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0, 0.1, 0.0))
	grad.set_color(1, Color(1, 0, 0.1, 0.38))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.05, 1.05)
	hurt_rect.texture = gtex
	hurt_rect.stretch_mode = TextureRect.STRETCH_SCALE
	hurt_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_rect.modulate.a = 0.0
	_full(hurt_rect)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(flash_rect)

	var ind := Indicators.new()
	_full(ind)

	joystick = Joystick.new()
	_full(joystick)

	safe = Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(safe)
	var m := Global.safe_margins()
	# UI size: the safe-area root is laid out in a smaller space and scaled up to fill the screen,
	# so every HUD element grows by the same factor and still fits
	var s := Global.get_ui_scale()
	safe.scale = Vector2(s, s)
	safe.anchor_right = 1.0 / s
	safe.anchor_bottom = 1.0 / s
	safe.offset_left = m["left"]
	safe.offset_top = m["top"]
	safe.offset_right = m["left"] - (m["left"] + m["right"]) / s
	safe.offset_bottom = m["top"] - (m["top"] + m["bottom"]) / s

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.add_theme_font_override("font", Global.FONT_TITLE)
	pause_button.add_theme_font_size_override("font_size", 18)
	pause_button.focus_mode = Control.FOCUS_NONE
	safe.add_child(pause_button)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -82
	pause_button.offset_right = -14
	pause_button.offset_top = 30
	pause_button.offset_bottom = 92
	pause_button.pressed.connect(func():
		if not busy and not over_root.visible and not pause_root.visible:
			Sfx.play("select")
			_pause())
	joystick.blockers.append(pause_button)

	minimap = Minimap.new()
	minimap.visible = false
	safe.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -124
	minimap.offset_right = -14
	minimap.offset_top = 100
	minimap.offset_bottom = 210

	ability_button = AbilityButton.new()
	ability_button.visible = false
	safe.add_child(ability_button)
	place_ability_button()
	ability_button.activated.connect(func(): ability_requested.emit())
	joystick.blockers.append(ability_button)

	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(xp_bar)
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_left = 8
	xp_bar.offset_right = -8
	xp_bar.offset_top = 8
	xp_bar.offset_bottom = 24

	level_label = _label("LV 1", Global.FONT_TITLE, 16, Global.C_CYAN)
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	level_label.offset_left = -290
	level_label.offset_right = -106
	level_label.offset_top = 32
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	time_label = _label("00:00", Global.FONT_TITLE, 26, Color.WHITE)
	time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	time_label.offset_top = 34
	time_label.offset_bottom = 68
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	tag_label = _label("", Global.FONT_TITLE, 12, Global.C_GOLD)
	tag_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tag_label.offset_top = 98
	tag_label.offset_bottom = 118
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	threat_label = _label("", Global.FONT_TITLE, 14, Global.C_RED)
	threat_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	threat_label.offset_top = 70
	threat_label.offset_bottom = 94
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_label = _label("DELETED 0", Global.FONT_BODY, 30, Global.C_CYAN)
	kills_label.position = Vector2(18, 30)
	data_label = _label("DATA 0", Global.FONT_BODY, 30, Global.C_GOLD)
	data_label.position = Vector2(18, 58)
	revive_label = _label("", Global.FONT_BODY, 26, Global.C_GOLD)
	revive_label.position = Vector2(18, 86)
	cd_box = HBoxContainer.new()
	cd_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_box.add_theme_constant_override("separation", 6)
	cd_box.position = Vector2(18, 118)
	safe.add_child(cd_box)

	combo_label = _label("", Global.FONT_TITLE, 22, Global.C_GOLD)
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	combo_label.offset_left = -440
	combo_label.offset_right = -96
	combo_label.offset_top = 62
	combo_label.offset_bottom = 94
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.pivot_offset = Vector2(340, 16)
	combo_label.modulate.a = 0.0
	combo_bonus_label = _label("", Global.FONT_BODY, 24, Color(0.8, 0.95, 1.0))
	combo_bonus_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	combo_bonus_label.offset_left = -760
	combo_bonus_label.offset_right = -96
	combo_bonus_label.offset_top = 96
	combo_bonus_label.offset_bottom = 124
	combo_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_bonus_label.modulate.a = 0.0

	boss_box = VBoxContainer.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(boss_box)
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_left = -300
	boss_box.offset_right = 300
	boss_box.offset_top = 132
	boss_box.offset_bottom = 178
	boss_name = _label("", Global.FONT_TITLE, 14, Global.C_RED, boss_box)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(600, 14)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_theme_stylebox_override("fill", Global.make_box(Global.C_RED, Global.C_RED, 0, 10, 2))
	boss_box.add_child(boss_bar)
	boss_box.hide()

	loadout_box = HBoxContainer.new()
	loadout_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loadout_box.add_theme_constant_override("separation", 6)
	safe.add_child(loadout_box)
	loadout_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	loadout_box.offset_left = -200
	loadout_box.offset_right = 200
	loadout_box.alignment = BoxContainer.ALIGNMENT_CENTER
	loadout_box.offset_top = -70
	loadout_box.offset_bottom = -14

	items_clip = Control.new()
	items_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_clip.clip_contents = true
	safe.add_child(items_clip)
	items_clip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	items_clip.offset_left = -300
	items_clip.offset_right = 300
	items_clip.offset_top = -120
	items_clip.offset_bottom = -76
	items_clip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	joystick.blockers.append(items_clip)
	items_box = GridContainer.new()
	items_box.columns = ITEM_COLUMNS
	items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_box.add_theme_constant_override("h_separation", 4)
	items_box.add_theme_constant_override("v_separation", ITEM_ROW_H - 44)
	items_clip.add_child(items_box)
	items_label = _label("", Global.FONT_TITLE, 10, Global.C_CYAN)
	items_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	items_label.offset_left = 180
	items_label.offset_right = 240
	items_label.offset_top = -138
	items_label.offset_bottom = -120
	items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	announce_label = _label("", Global.FONT_TITLE, 26, Color.WHITE)
	announce_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	announce_label.offset_top = 196
	announce_label.offset_bottom = 246
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce_label.modulate.a = 0.0

	warning_label = _label("", Global.FONT_TITLE, 40, Global.C_RED)
	warning_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	warning_label.offset_left = -640
	warning_label.offset_right = 640
	warning_label.offset_top = -120
	warning_label.offset_bottom = -20
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.modulate.a = 0.0

	_build_offer_ui()
	_build_pause_ui()
	_build_results_ui()
	_build_cure_prompt_ui()

	for c in get_children():
		if c is Control:
			c.theme = Global.ui_theme


# ---------- helpers ----------

func _full(c: Control, parent: Node = self) -> void:
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _label(text: String, font: Font, size: int, color: Color, parent: Node = null) -> Label:
	if parent == null:
		parent = safe
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Shrinks a label's font until the text fits inside max_w x max_h.
func _fit(l: Label, max_w: float, max_h: float, max_size: int, min_size: int) -> void:
	var font: Font = l.get_theme_font("font")
	var fs := max_size
	while fs > min_size:
		var sz := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, max_w, fs)
		if sz.x <= max_w + 0.5 and sz.y <= max_h:
			break
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	l.custom_minimum_size = Vector2(max_w, max_h)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true


func _overlay(dim_alpha := 0.75) -> CenterContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, dim_alpha)
	_full(dim)
	# like the HUD: lay out in a smaller space and scale up, so cards, pause and results grow with UI SIZE
	var s := Global.get_ui_scale()
	var scaler := Control.new()
	scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(scaler, dim)
	scaler.scale = Vector2(s, s)
	scaler.anchor_right = 1.0 / s
	scaler.anchor_bottom = 1.0 / s
	var center := CenterContainer.new()
	_full(center, scaler)
	dim.hide()
	return center


## Shrinks an overlay's UI SIZE scale just enough that its content fits on screen
## (e.g. five cards, or the results panel on a Large UI). Never grows past the chosen size.
func _fit_overlay(center: Control) -> void:
	var s := Global.get_ui_scale()
	var vp := get_viewport().get_visible_rect().size
	var need: Vector2 = center.get_child(0).get_combined_minimum_size() + Vector2(48.0, 40.0)
	var k := minf(1.0, minf(vp.x / s / need.x, vp.y / s / need.y))
	var scaler: Control = center.get_parent()
	scaler.scale = Vector2(s * k, s * k)
	scaler.anchor_right = 1.0 / (s * k)
	scaler.anchor_bottom = 1.0 / (s * k)


func _button(text: String, parent: Node, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 60)
	b.pressed.connect(func():
		Sfx.play("select")
		callback.call())
	b.mouse_entered.connect(func(): Sfx.play("hover"))
	b.focus_entered.connect(func(): Sfx.play("hover"))
	parent.add_child(b)
	return b


# ---------- live stats ----------

## Overtime: the clock shows time survived since the final boss, plus the threat level (enemy damage).
## Small line under the clock naming the run mode and challenge ("" hides it).
## The ability button sits bottom right, or bottom left when the SWAP option puts the joystick on the right.
func place_ability_button() -> void:
	var left: bool = Global.swap_controls
	ability_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if left else Control.PRESET_BOTTOM_RIGHT)
	ability_button.offset_left = 30 if left else -170
	ability_button.offset_right = 170 if left else -30
	ability_button.offset_top = -190
	ability_button.offset_bottom = -50


## Shows the class ability button (call once at run start with the class dictionary).
## Shows the arena minimap (call once at run start; a null arena keeps it hidden).
func setup_map(arena, player) -> void:
	minimap.arena = arena
	minimap.player = player
	minimap.visible = Global.minimap_on


func setup_ability(c: Dictionary) -> void:
	ability_button.visible = true
	ability_button.icon_id = c["icon"]
	ability_button.color = c["color"]
	ability_button.label = c["ability_name"]


func set_run_tags(text: String) -> void:
	tag_label.text = text


func set_overtime(seconds: float, threat: float) -> void:
	ot_text = "OVERTIME +%s" % Global.format_time(seconds)
	time_label.add_theme_color_override("font_color", Global.C_GOLD)
	threat_label.text = "THREAT x%.1f" % threat


func update_stats(player, elapsed: float, kills: int, data: float, boss) -> void:
	var target: float = float(player.xp) / player.xp_to_next
	if target < shown_xp - 0.05:
		shown_xp = 0.0
	shown_xp = lerpf(shown_xp, target, minf(1.0, get_process_delta_time() * 10.0))
	xp_bar.value = shown_xp * 100.0
	level_label.text = "LV %d" % player.level
	time_label.text = ot_text if ot_text != "" else Global.format_time(elapsed)
	kills_label.text = "DELETED %d" % kills
	data_label.text = "DATA %d" % int(data)
	revive_label.text = ("REVIVES %d" % player.revives) if player.revives > 0 else ""
	if is_instance_valid(boss):
		boss_fade_left = 0.0
		boss_box.show()
		boss_name.text = boss.display_name + ("  [ENRAGED]" if boss.enraged else "")
		boss_bar.value = 100.0 * maxf(0.0, boss.hp) / boss.max_hp
	elif boss_fade_left > 0.0:   # boss just died: keep the emptied bar up briefly
		boss_fade_left -= get_process_delta_time()
		if boss_fade_left <= 0.0:
			boss_box.hide()
	else:
		boss_box.hide()


## Called the moment a boss dies: the bar must read empty (it was last drawn before the killing blow).
func boss_defeated() -> void:
	boss_bar.value = 0.0
	boss_fade_left = 0.8
	boss_box.show()


## Small padding so the icon fills the slot.
func _slot_box(border: Color) -> StyleBoxFlat:
	var sb := Global.make_box(Color(0.02, 0.04, 0.08, 0.85), border, 1, 4, 4)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


func refresh_loadout(game) -> void:
	for c in loadout_box.get_children():
		c.queue_free()
	for id in game.player.weapons:
		var evo: bool = not Meta.Evolutions.by_id(id).is_empty()   # evolved weapons wear the red EVOLUTION colour, like their card
		var wcol: Color = Global.EVOLUTION_RARITY["color"] if evo else Global.C_CYAN
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", _slot_box(Color(wcol, 0.85 if evo else 0.5)))
		slot.custom_minimum_size = Vector2(52, 52)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loadout_box.add_child(slot)
		var icon := IconView.new()
		icon.icon_id = id
		icon.color = wcol
		slot.add_child(icon)
		var lv := _label(str(game.player.weapons[id].level), Global.FONT_TITLE, 10, Color.WHITE, icon)
		lv.position = Vector2(26, 24)
	for i in game.max_weapons - game.player.weapons.size():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", Global.make_box(Color(0.02, 0.04, 0.08, 0.4), Color(Global.C_CYAN, 0.15), 1, 0, 4))
		empty.custom_minimum_size = Vector2(52, 52)
		loadout_box.add_child(empty)
	for c in items_box.get_children():
		items_box.remove_child(c)   # not just queue_free: the row count below must not see the old slots
		c.queue_free()
	for id in game.player.items:
		var it: Dictionary = ItemData.ITEMS[id]
		var col: Color = Global.C_RED if it["kind"] == "risky" else Global.C_GREEN
		var corrupted: bool = it["kind"] == "risky"
		if corrupted:
			col = GLITCH_COLORS[0]
		var box := _slot_box(Color(col, 0.7))
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", box)
		slot.custom_minimum_size = Vector2(44, 44)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items_box.add_child(slot)
		var icon := IconView.new()
		icon.icon_id = it["icon"]
		icon.color = col
		slot.add_child(icon)
		if corrupted:   # corrupted items flicker between the same neon colours as their card
			var glitch := Timer.new()
			glitch.wait_time = 0.09
			glitch.autostart = true
			slot.add_child(glitch)
			glitch.timeout.connect(func():
				var gc: Color = GLITCH_COLORS.pick_random()
				box.border_color = Color(gc, 0.85)
				box.bg_color = Color(gc.r * 0.14, gc.g * 0.14, gc.b * 0.14, 0.85)
				icon.color = gc)
	_layout_items(game.player.items.size())
	for c in cd_box.get_children():
		c.queue_free()
	for id in game.player.items:
		var node = game.player.items[id]
		if node is Node and node.has_method("cd_frac"):
			var cs := CooldownSlot.new()
			cs.item = node
			cs.icon_id = ItemData.ITEMS[id]["icon"]
			cs.custom_minimum_size = Vector2(44, 44)
			cd_box.add_child(cs)


## Centres the item grid, counts its rows and keeps the visible row in range.
func _layout_items(n: int) -> void:
	items_rows = maxi(1, ceili(n / float(ITEM_COLUMNS)))
	items_box.position.x = (600.0 - (minf(n, ITEM_COLUMNS) * 48.0 - 4.0)) * 0.5
	_show_item_row(clampi(items_row, 0, items_rows - 1), false)


func _show_item_row(row: int, animate := true) -> void:
	items_row = clampi(row, 0, items_rows - 1)
	items_label.text = "%d/%d" % [items_row + 1, items_rows] if items_rows > 1 else ""
	if items_tween:
		items_tween.kill()
	var y := -float(items_row * ITEM_ROW_H)
	if animate:
		items_tween = create_tween()
		items_tween.tween_property(items_box, "position:y", y, 0.12)
	else:
		items_box.position.y = y


## Swiping up / down over the item strip (or the mouse wheel) shows the next / previous row of items.
func _items_input(event: InputEvent) -> void:
	if items_rows <= 1 or not items_clip.is_visible_in_tree() or get_tree().paused:
		return
	var inside := func(pos: Vector2) -> bool: return (items_clip.get_global_transform() * Rect2(Vector2.ZERO, items_clip.size)).grow(10.0).has_point(pos)
	var down := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		pos = event.position
		down = event.pressed
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed and inside.call(event.position):
				_show_item_row(items_row + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = event.position
		down = event.pressed
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION):
		if items_swiping and absf(event.position.y - items_swipe_from.y) > 24.0:
			_show_item_row(items_row + (1 if event.position.y < items_swipe_from.y else -1))   # swipe up = next row
			items_swipe_from = event.position
		return
	else:
		return
	items_swiping = down and inside.call(pos)
	items_swipe_from = pos


## Called every frame with the (decaying) combo, its bonus text and tier. The pop on kills is separate.
func set_combo(n: int, bonus := "", tier := 0) -> void:
	var visible_now := 1.0 if n >= 5 else 0.0
	combo_label.modulate.a = visible_now
	combo_bonus_label.modulate.a = visible_now
	combo_label.text = "x%d COMBO" % n
	combo_bonus_label.text = bonus
	if tier != combo_tier_shown:
		combo_tier_shown = tier
		var col: Color = [Global.C_CYAN, Global.C_CYAN, Global.C_GREEN, Global.C_GOLD, Global.C_MAGENTA][tier]
		combo_label.add_theme_color_override("font_color", col)
		combo_bonus_label.add_theme_color_override("font_color", col.lightened(0.3))


func pop_combo() -> void:
	if combo_tween:
		combo_tween.kill()
	combo_label.scale = Vector2(1.2, 1.2)
	combo_tween = create_tween()
	combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.12)


func announce(text: String, color: Color, big := false) -> void:
	if announce_tween:
		announce_tween.kill()
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", color)
	announce_label.add_theme_font_size_override("font_size", 40 if big else 22)
	announce_label.pivot_offset = announce_label.size / 2.0
	announce_label.scale = Vector2(2.2, 2.2)
	announce_label.modulate.a = 1.0
	announce_tween = create_tween()
	announce_tween.tween_property(announce_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	announce_tween.tween_interval(1.4 if big else 1.0)
	announce_tween.tween_property(announce_label, "modulate:a", 0.0, 0.4)


func boss_warning(name: String, final: bool) -> void:
	if warning_tween:
		warning_tween.kill()
	warning_label.text = "!! WARNING !!\n%s%s" % ["FINAL BOSS: " if final else "", name]
	warning_label.modulate.a = 1.0
	warning_tween = create_tween()
	for i in 6:
		warning_tween.tween_property(warning_label, "modulate:a", 0.25, 0.22)
		warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.22)
	warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.4)
	flash(Global.C_RED, 0.3)


func flash(color: Color, strength := 0.6) -> void:
	flash_rect.color = Color(color, strength)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.6)


func hurt_flash() -> void:
	hurt_rect.modulate.a = 1.0
	create_tween().tween_property(hurt_rect, "modulate:a", 0.0, 0.5)


# ---------- upgrade offer ----------

func _build_offer_ui() -> void:
	var center := _overlay(0.72)
	offer_root = center.get_parent().get_parent()   # the dim behind the scaler
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	offer_title = _label("LEVEL UP!", Global.FONT_TITLE, 36, Global.C_CYAN, vbox)
	offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	decrypt_box = VBoxContainer.new()
	decrypt_box.add_theme_constant_override("separation", 8)
	vbox.add_child(decrypt_box)
	var dl := _label("DECRYPTING CACHE...", Global.FONT_BODY, 32, Global.C_GOLD, decrypt_box)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	decrypt_bar = ProgressBar.new()
	decrypt_bar.show_percentage = false
	decrypt_bar.custom_minimum_size = Vector2(500, 20)
	decrypt_bar.add_theme_stylebox_override("fill", Global.make_box(Global.C_GOLD, Global.C_GOLD, 0, 10, 2))
	decrypt_box.add_child(decrypt_bar)

	cards_box = HBoxContainer.new()
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.add_theme_constant_override("separation", 22)
	cards_box.custom_minimum_size = Vector2(0, CARD_H)
	vbox.add_child(cards_box)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 30)
	vbox.add_child(bottom)
	offer_hint = _label("CLICK A CARD OR PRESS 1-4", Global.FONT_BODY, 26, Color(0.6, 0.75, 0.8), bottom)
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(220, 60)
	reroll_button.pressed.connect(func():
		if not choosing:
			reroll_requested.emit())
	bottom.add_child(reroll_button)
	ban_button = Button.new()
	ban_button.custom_minimum_size = Vector2(220, 60)
	ban_button.focus_mode = Control.FOCUS_NONE
	ban_button.add_theme_color_override("font_color", Global.C_RED)
	ban_button.pressed.connect(func():
		if choosing:
			return
		ban_mode = not ban_mode
		Sfx.play("select", 0.8, -4.0, 0.0)
		_refresh_bans(Global.game.bans_left if Global.game else 0))
	bottom.add_child(ban_button)


func show_offer(title: String, color: Color, options: Array, decrypt: bool, rerolls: int) -> void:
	busy = true
	choosing = true
	ban_mode = false
	current_options = options
	_clear_rain()
	for c in cards_box.get_children():
		cards_box.remove_child(c)   # out of the layout now, so the fit below only counts the new cards
		c.queue_free()
	current_cards.clear()

	if offer_fade:
		offer_fade.kill()
	offer_root.show()
	offer_root.modulate.a = 0.0
	offer_fade = create_tween()
	offer_fade.tween_property(offer_root, "modulate:a", 1.0, 0.15)
	offer_title.text = title
	offer_title.add_theme_color_override("font_color", color)
	offer_title.pivot_offset = offer_title.size / 2.0
	offer_title.scale = Vector2(2.2, 2.2)
	create_tween().tween_property(offer_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	offer_hint.modulate.a = 0.0
	reroll_button.text = "REROLL (%d)" % rerolls
	reroll_button.disabled = rerolls <= 0
	reroll_button.visible = rerolls > 0 or Meta.stat("reroll") > 0
	_refresh_bans(Global.game.bans_left if Global.game else 0)

	decrypt_box.hide()
	if decrypt:
		decrypt_box.show()
		decrypt_bar.value = 0.0
		create_tween().tween_property(decrypt_bar, "value", 100.0, 1.2)
		for i in 12:
			await get_tree().create_timer(0.1).timeout
			Sfx.play("tick", 1.0 + i * 0.12)
		decrypt_box.hide()

	revealed_tiers.clear()
	var best_tier := 0
	var has_evo := false
	for i in options.size():
		var opt: Dictionary = options[i]
		var tier: int = opt["rarity"]["tier"]
		best_tier = maxi(best_tier, tier)
		has_evo = has_evo or opt["rarity"].get("evolution", false)
		var card := _make_card(opt, i)
		cards_box.add_child(card)
		current_cards.append(card)
		card.scale = Vector2(0.2, 0.2)
		card.modulate.a = 0.0
		card.rotation = randf_range(-0.3, 0.3)
		var delay := i * 0.13
		var tw := card.create_tween().set_parallel()
		tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		tw.tween_property(card, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(delay)
		var flash_col: Color = opt["rarity"]["color"]
		get_tree().create_timer(delay).timeout.connect(func(): _on_card_revealed(card, tier, i, flash_col))
	call_deferred("_fit_overlay", cards_box.get_parent().get_parent())   # 4-5 cards shrink to fit

	offer_ready_time = Time.get_ticks_msec() / 1000.0 + options.size() * 0.13 + 0.35
	offer_hint_default = "TAP A CARD" if Global.is_touch else "CLICK A CARD OR PRESS 1-%d" % options.size()
	offer_hint.text = offer_hint_default
	create_tween().tween_property(offer_hint, "modulate:a", 1.0, 0.3).set_delay(0.5)
	if has_evo:
		offer_title.text = "!! EVOLUTION READY !!"
		offer_title.add_theme_color_override("font_color", Global.EVOLUTION_RARITY["color"])
	elif best_tier >= 3:
		_start_rain()
		offer_title.text = "!! LEGENDARY SIGNAL !!"
		offer_title.add_theme_color_override("font_color", Global.C_GOLD)
	choosing = false
	if current_cards.size() > 0:
		current_cards[0].call_deferred("grab_focus")


var revealed_tiers := {}   # tiers whose jingle already played for the cards on screen


func _on_card_revealed(card: Button, tier: int, index: int, col: Color = Color(0, 0, 0, 0)) -> void:
	if not is_instance_valid(card):
		return
	Sfx.play("card", 1.0 + index * 0.15, 0.0, 0.0)
	if col.a == 0.0:
		col = Global.RARITIES[tier]["color"]
	if tier < 2 or revealed_tiers.has(tier):
		return   # the epic / legendary jingle and flash play once per offer, however many such cards are on show
	revealed_tiers[tier] = true
	if tier == 2:
		if not revealed_tiers.has(3):   # a legendary card on show already has the big sting; an epic one beside it stays silent
			Sfx.play("epic", 1.0, -2.0, 0.0)
		flash(col, 0.2)
	elif tier == 3:
		Sfx.play("legendary", 1.0, 0.0, 0.0)
		flash(col, 0.5)


const GLITCH_COLORS := [Color(0.95, 0.2, 0.95), Color(0.1, 1.0, 0.95), Color(0.6, 1.0, 0.15), Color(1.0, 0.2, 0.3)]   # corrupted cards flicker between these


func _make_card(opt: Dictionary, index: int) -> Button:
	var rarity: Dictionary = opt["rarity"]
	var col: Color = rarity["color"]
	var tier: int = rarity["tier"]
	var corrupted: bool = rarity["name"] == "CORRUPTED"
	if corrupted:
		col = GLITCH_COLORS[0]
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	b.pivot_offset = Vector2(CARD_W, CARD_H) / 2.0
	b.clip_contents = true
	var bg := Color(0.025, 0.03, 0.07, 0.97).lerp(Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, 0.97), 0.5)
	var normal := Global.make_box(bg, col, 3, 6 + tier * 7, 8)
	var hover := Global.make_box(bg.lightened(0.07), col.lightened(0.35), 4, 18 + tier * 8, 8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.mouse_entered.connect(func(): Sfx.play("hover"))
	b.pressed.connect(func(): _on_card_pressed(index))

	var inner_w := CARD_W - 28.0
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	b.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_right = -14
	box.offset_top = 12
	box.offset_bottom = -10

	var tag_text: String = ("[ %s ]" if tier < 3 else "<< %s >>") % rarity["name"]
	var tag_label := _label(tag_text, Global.FONT_TITLE, 11, col, box)
	_fit(tag_label, inner_w, 18, 11, 8)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(inner_w, 100)
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_holder)
	var icon := IconView.new()
	icon.icon_id = opt["icon"]
	icon.color = col.lightened(0.15)
	icon_holder.add_child(icon)
	icon.position = Vector2((inner_w - 96.0) / 2.0, 2)
	icon.size = Vector2(96, 96)

	_fit(_label(opt["title"], Global.FONT_TITLE, 14, Color.WHITE, box), inner_w, 40, 15, 8)
	_fit(_label(opt["level_text"], Global.FONT_BODY, 28, col.lightened(0.3), box), inner_w, 28, 28, 16)
	_fit(_label(opt["desc"], Global.FONT_BODY, 24, Color(0.78, 0.88, 0.95), box), inner_w, 124, 25, 12)

	if corrupted:   # a glitchy card: the border and tag flicker between neon colours and the contents twitch sideways
		var glitch := Timer.new()
		glitch.wait_time = 0.09
		glitch.autostart = true
		b.add_child(glitch)
		glitch.timeout.connect(func():
			var gc: Color = GLITCH_COLORS.pick_random()
			normal.border_color = gc
			normal.bg_color = Color(gc.r * 0.14, gc.g * 0.14, gc.b * 0.14, 0.97)
			tag_label.add_theme_color_override("font_color", gc)
			var jitter := float(randi_range(-5, 5)) if randf() < 0.3 else 0.0
			box.offset_left = 14.0 + jitter
			box.offset_right = -14.0 + jitter)
	if tier >= 2:
		var pulse := b.create_tween().set_loops()
		var big := 26.0 + tier * 10.0
		pulse.tween_property(normal, "shadow_size", int(big), 0.5).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(normal, "border_color", Color.WHITE if tier == 3 else col.lightened(0.4), 0.5)
		pulse.tween_property(normal, "shadow_size", 6 + tier * 7, 0.5).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(normal, "border_color", col, 0.5)
	return b


func _refresh_bans(bans_left: int) -> void:
	if bans_left <= 0:
		ban_mode = false
	ban_button.visible = bans_left > 0
	ban_button.text = ("BAN: ON (%d)" if ban_mode else "BAN (%d)") % bans_left
	ban_button.add_theme_stylebox_override("normal", Global.make_box(Color(0.35, 0.04, 0.07, 0.95) if ban_mode else Color(0.1, 0.02, 0.03, 0.9), Global.C_RED, 3 if ban_mode else 2, 10 if ban_mode else 0, 4))
	offer_hint.text = "TAP A CARD TO BAN IT" if ban_mode else offer_hint_default
	for c in current_cards:
		if is_instance_valid(c):
			var a: float = c.modulate.a
			c.modulate = Color(1.0, 0.45, 0.45, a) if ban_mode else Color(1, 1, 1, a)


## After a ban: swap the banned card for a fresh one in place.
func replace_card(index: int, opt: Dictionary, bans_left: int) -> void:
	current_options[index] = opt
	var old: Button = current_cards[index]
	var card := _make_card(opt, index)
	var at := old.get_index()
	cards_box.add_child(card)
	cards_box.move_child(card, at)
	old.queue_free()
	current_cards[index] = card
	card.modulate.a = 0.0
	card.scale = Vector2(0.5, 0.5)
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
	revealed_tiers.erase(opt["rarity"]["tier"])   # a card swapped in by a ban gets its own jingle
	_on_card_revealed(card, opt["rarity"]["tier"], index, opt["rarity"]["color"])
	_refresh_bans(bans_left)
	card.call_deferred("grab_focus")


func _on_card_pressed(index: int) -> void:
	if choosing or Time.get_ticks_msec() / 1000.0 < offer_ready_time or index >= current_cards.size():
		return
	if ban_mode and Global.game and Global.game.bans_left > 0:
		ban_mode = false   # one ban per toggle, so a stray tap cannot ban twice
		ban_requested.emit(index)   # (game.gd refuses to ban an evolution card)
		return
	choosing = true
	Sfx.play("select", 1.0, 0.0, 0.0)
	for i in current_cards.size():
		var c: Button = current_cards[i]
		var tw := c.create_tween().set_parallel()
		if i == index:
			tw.tween_property(c, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "modulate", Color(2, 2, 2, 1), 0.1)
			tw.chain().tween_property(c, "modulate:a", 0.0, 0.15)
		else:
			tw.tween_property(c, "scale", Vector2(0.8, 0.8), 0.2)
			tw.tween_property(c, "modulate:a", 0.0, 0.2)
	await get_tree().create_timer(0.35).timeout
	option_chosen.emit(current_options[index])


var gold_rain: Control = null


## LEGENDARY SIGNAL: golden code raining over the whole offer backdrop, behind the title and cards.
func _start_rain() -> void:
	_clear_rain()
	gold_rain = Control.new()
	gold_rain.set_script(preload("res://scripts/ui/gold_rain.gd"))
	gold_rain.cell = 4.0
	offer_root.add_child(gold_rain)
	offer_root.move_child(gold_rain, 0)


func _clear_rain() -> void:
	if is_instance_valid(gold_rain):
		gold_rain.queue_free()
	gold_rain = null


func hide_offer() -> void:
	_clear_rain()
	if offer_fade:
		offer_fade.kill()
	offer_fade = create_tween()
	offer_fade.tween_property(offer_root, "modulate:a", 0.0, 0.12)
	offer_fade.tween_callback(offer_root.hide)


# ---------- pause ----------

func _build_pause_ui() -> void:
	var center := _overlay(0.7)
	pause_root = center.get_parent().get_parent()   # the dim behind the scaler
	pause_center = center
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_label("PAUSED", Global.FONT_TITLE, 32, Global.C_CYAN, box).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_loadout = _label("", Global.FONT_BODY, 26, Color(0.75, 0.9, 1.0), box)
	pause_resume = _button("RESUME", box, _resume)
	_button("STATS", box, toggle_stats)
	# same audio and readout options as the main menu OPTIONS screen
	_pause_volume_row(box, "VOLUME", "sfx_volume", "pickup")
	_pause_volume_row(box, "MUSIC", "music_volume", "")
	_pause_volume_row(box, "EFFECTS", "fx_volume", "levelup")
	for o in [["DAMAGE NUMBERS", "damage_numbers"], ["STATUS WORDS", "status_words"], ["SWAP ABILITY BUTTON / JOYSTICK SIDES", "swap_controls"]]:
		var tg := CheckButton.new()
		tg.text = o[0]
		tg.button_pressed = Global.get(o[1])
		tg.focus_mode = Control.FOCUS_NONE
		var key: String = o[1]
		tg.toggled.connect(func(on):
			Global.set(key, on)
			Global.save()
			place_ability_button())
		box.add_child(tg)
	pause_abandon = _button("ABANDON RUN", box, func():
		pause_root.hide()
		if Global.game and Global.game.overtime and Global.game.victory:
			Global.game.cash_out()
		elif Global.game:
			Global.game.run_over = true
			Global.game._finish_run())

	_build_stats_panel()


## One labelled volume slider bound to a Global setting (as in the main menu); plays a sample sound from that group.
func _pause_volume_row(box: Control, text: String, setting: String, sample: String) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := _label(text, Global.FONT_BODY, 24, Color(0.75, 0.9, 1.0), row)
	l.custom_minimum_size = Vector2(190, 0)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Global.get(setting)
	slider.custom_minimum_size = Vector2(200, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v):
		Global.set(setting, v)
		Sfx.apply_volumes()
		Music.apply_volume()
		if sample != "":
			Sfx.play(sample, 1.0, -4.0, 0.25))
	slider.drag_ended.connect(func(_changed): Global.save())
	row.add_child(slider)


func _pause() -> void:
	joystick.release()
	get_tree().paused = true
	var game = Global.game
	var summary := "DEVICE: %s" % Meta.device_name()
	if game:
		summary += "\nUPTIME %s   LEVEL %d" % [Global.format_time(game.elapsed), game.player.level]
	pause_loadout.text = summary
	pause_abandon.text = "CASH OUT" if (game and game.overtime) else "ABANDON RUN"
	stats_open = false
	stats_slider.offset_left = 0.0
	stats_slider.offset_right = stats_width
	pause_center.offset_right = 0.0
	call_deferred("_fit_overlay", pause_center)
	pause_root.show()
	pause_resume.call_deferred("grab_focus")


func _close_or_resume() -> void:
	if stats_open:
		set_stats_open(false)
	else:
		_resume()


# ---------- stats tab ----------

func _build_stats_panel() -> void:
	var m := Global.safe_margins()
	stats_width = 560.0 if Global.is_touch else 440.0
	# the tab lives in the scaled layer; keep it to about half of the (smaller) scaled width
	stats_width = minf(stats_width, 1280.0 / Global.get_ui_scale() * 0.52)
	stats_slider = Control.new()
	stats_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_center.get_parent().add_child(stats_slider)
	stats_slider.anchor_left = 1.0
	stats_slider.anchor_right = 1.0
	stats_slider.anchor_top = 0.0
	stats_slider.anchor_bottom = 1.0
	stats_slider.offset_left = 0.0           # closed: panel is just off the right edge
	stats_slider.offset_right = stats_width

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Global.make_box(Color(0.02, 0.03, 0.07, 0.97), Global.C_CYAN, 2, 18, 6))
	stats_slider.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = m["top"] + 8.0
	panel.offset_bottom = -(m["bottom"] + 8.0)
	panel.offset_right = -m["right"]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label("STATS", Global.FONT_TITLE, 20, Global.C_CYAN, head)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(64, 52)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func():
		Sfx.play("select")
		set_stats_open(false))
	head.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ScrollFix.apply(scroll)
	col.add_child(scroll)
	stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stats_vbox)

	# the tab handle sits on the slider's left edge, so it is always visible while paused
	var tab := Button.new()
	tab.text = "S\nT\nA\nT\nS"
	tab.focus_mode = Control.FOCUS_NONE
	stats_slider.add_child(tab)
	tab.anchor_top = 0.5
	tab.anchor_bottom = 0.5
	tab.offset_left = -56.0
	tab.offset_right = 0.0
	tab.offset_top = -90.0
	tab.offset_bottom = 90.0
	tab.pressed.connect(func():
		Sfx.play("select")
		toggle_stats())


func toggle_stats() -> void:
	set_stats_open(not stats_open)


func set_stats_open(open: bool) -> void:
	stats_open = open
	if open:
		_refresh_stats()
	if stats_tween:
		stats_tween.kill()
	stats_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	stats_tween.tween_property(stats_slider, "offset_left", -stats_width if open else 0.0, 0.25)
	stats_tween.tween_property(stats_slider, "offset_right", 0.0 if open else stats_width, 0.25)
	# slide the pause window to the left so the stats tab never covers it
	stats_tween.tween_property(pause_center, "offset_right", -stats_width if open else 0.0, 0.25)


func _refresh_stats() -> void:
	for c in stats_vbox.get_children():
		c.queue_free()
	var game = Global.game
	if game == null:
		return
	var fs := 28 if Global.is_touch else 24
	for grp in StatsData.groups(game):
		if grp["rows"].is_empty():
			continue
		var head := _label(grp["name"], Global.FONT_TITLE, 14, grp["color"], stats_vbox)
		head.custom_minimum_size = Vector2(0, 40)
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		for row in grp["rows"]:
			var line := HBoxContainer.new()
			stats_vbox.add_child(line)
			var name_l := _label(row["label"], Global.FONT_BODY, fs, Color(0.75, 0.88, 0.95), line)
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if row["value"] != "":
				var val_l := _label(row["value"], Global.FONT_BODY, fs, row["tint"], line)
				val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if row["detail"] != "":
				var det := _label(row["detail"], Global.FONT_BODY, fs - 6, Color(0.5, 0.64, 0.7), stats_vbox)
				det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				det.custom_minimum_size = Vector2(stats_width - 70.0, 0)


func _resume() -> void:
	pause_root.hide()
	get_tree().paused = false


# ---------- cure prompt (final boss defeated) ----------

func _build_cure_prompt_ui() -> void:
	var center := _overlay(0.8)
	cure_root = center.get_parent().get_parent()
	var panel := PanelContainer.new()
	center.add_child(panel)
	panel.add_theme_stylebox_override("panel", Global.make_box(Color(0.03, 0.04, 0.06, 0.96), Global.C_GREEN, 2, 24, 4))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := _label("DEVICE CURED!", Global.FONT_TITLE, 30, Global.C_GREEN, box)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label("The cure is saved. Keep fighting in OVERTIME for more DATA, or cash out now.\nOvertime gets harder every minute, and a boss arrives every 3 minutes.",
		Global.FONT_BODY, 26, Color(0.85, 0.9, 1.0), box)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cure_continue = _button("CONTINUE (OVERTIME)", box, func():
		if Global.game:
			Global.game.continue_overtime())
	_button("CASH OUT", box, func():
		if Global.game:
			Global.game.cash_out())


func show_cure_prompt(device: String) -> void:
	busy = true
	get_tree().paused = true
	cure_root.show()
	cure_continue.call_deferred("grab_focus")


func hide_cure_prompt() -> void:
	cure_root.hide()


# ---------- results (death or victory) ----------

func _build_results_ui() -> void:
	var center := _overlay(0.82)
	over_root = center.get_parent().get_parent()   # the dim behind the scaler
	over_panel = PanelContainer.new()
	center.add_child(over_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	over_panel.add_child(box)
	var dev_row := HBoxContainer.new()
	dev_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dev_row.add_theme_constant_override("separation", 10)
	dev_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dev_row)
	over_device_icon = IconView.new()
	over_device_icon.custom_minimum_size = Vector2(56, 56)
	dev_row.add_child(over_device_icon)
	over_device_name = _label("", Global.FONT_TITLE, 16, Color(0.85, 0.9, 1.0), dev_row)
	over_device_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over_title = _label("SYSTEM COMPROMISED", Global.FONT_TITLE, 28, Global.C_RED, box)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat_panel := _section(box, Color(0.3, 0.55, 0.7))
	over_stats = _label("", Global.FONT_BODY, 28, Color(0.85, 0.9, 1.0), stat_panel)
	over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var data_panel := _section(box, Global.C_GOLD)
	over_data = _label("", Global.FONT_TITLE, 22, Global.C_GOLD, data_panel)
	over_data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_note_panel = _section(box, Global.C_CYAN)
	over_note = _label("", Global.FONT_BODY, 24, Global.C_CYAN, over_note_panel)
	over_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_note.custom_minimum_size = Vector2(620, 0)
	over_first = _button("RESEARCH", box, func(): Global.change_scene("res://scenes/research.tscn"))
	_button("REBOOT", box, func(): Global.change_scene("res://scenes/game.tscn"))
	_button("MAIN MENU", box, func(): Global.change_scene("res://scenes/menu.tscn"))


## A bordered section of the results screen, so stats, DATA and notes are not crammed into one box.
func _section(parent: Node, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Global.make_box(Color(0.05, 0.07, 0.1, 0.9), Color(color, 0.55), 2, 0, 6))
	parent.add_child(p)
	return p


func show_results(r: Dictionary) -> void:
	busy = true
	offer_root.hide()
	var won: bool = r["victory"] or r.get("cashed_out", false)   # cashing out always counts as the cure
	var ot: float = r.get("overtime", 0.0)
	over_title.text = ("OVERTIME OVER" if ot > 0.0 and not r.get("cashed_out", false) else "DEVICE CURED!") if won else "SYSTEM COMPROMISED"
	over_device_icon.icon_id = Meta.device_icon()
	over_device_icon.color = Meta.device_palette()
	over_device_name.text = Meta.device_name()
	over_title.add_theme_color_override("font_color", Global.C_GREEN if won else Global.C_RED)
	var border := Global.C_GREEN if won else Global.C_RED
	var sb := Global.make_box(Color(0.03, 0.04, 0.06, 0.96), border, 2, 24, 4)
	sb.content_margin_top = 22
	sb.content_margin_bottom = 18
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	over_panel.add_theme_stylebox_override("panel", sb)
	over_stats.text = "UPTIME          %s\nLEVEL           %d\nTHREATS DELETED %d\nBEST COMBO      x%d" % [
		Global.format_time(r["time"]), r["level"], r["kills"], r["combo"]]
	if Meta.run_internet():   # THE INTERNET is endless: count the bosses instead of showing a fixed 4
		over_stats.text += "\nBOSSES DELETED  %d" % (int(r["bosses"]) + int(r.get("overtime_bosses", 0)))
	else:
		over_stats.text += "\nBOSSES DEFEATED %d / 4" % r["bosses"]
	if ot > 0.0:
		over_stats.text += "\nOVERTIME        %s\nOVERTIME BOSSES %d" % [Global.format_time(ot), r.get("overtime_bosses", 0)]
	var notes := []
	if r["first_cure"]:
		notes.append("%s IS CLEAN. %s UNLOCKED: pick it on the main menu." % [Meta.device_name(), Meta.device_name(Meta.selected_device + 1)])
	if r.get("mode", "NORMAL") != "NORMAL":
		notes.append("MODE: %s" % r["mode"])
	if r.get("cure_time", 0.0) > 0.0:
		notes.append("*** FASTEST CURE: %s ***" % Global.format_time(r["cure_time"]))
	for name in r.get("achievements", []):
		notes.append(name if name.begins_with("CHALLENGE") else "ACHIEVEMENT: %s" % name)
	if r.get("pp", 0) > 0:
		notes.append("+%d PRESTIGE POINT(S): spend them in the PRESTIGE tree" % r["pp"])
	if r["new_ring"]:
		notes.append("New research ring unlocked!")
	if r["record"]:
		notes.append("*** NEW UPTIME RECORD ***")
	if r.get("overtime_record", false):
		notes.append("*** NEW OVERTIME RECORD ***")
	var can_buy := Meta.affordable_count()
	if can_buy > 0:
		notes.append("%d research upgrades affordable" % can_buy)
	over_note.text = "\n".join(notes)
	over_note_panel.visible = not notes.is_empty()
	call_deferred("_fit_overlay", over_panel.get_parent())
	over_root.show()
	over_root.modulate.a = 0.0
	create_tween().tween_property(over_root, "modulate:a", 1.0, 0.4)
	if not Music.play_sting(won):
		Sfx.play("victory" if won else "explode", 1.0 if won else 0.8, 0.0, 0.0)
	# DATA count-up
	var total: float = r["data"]
	over_data.text = "+0 DATA"
	var tw := create_tween()
	tw.tween_method(func(v: float):
		over_data.text = "+%d DATA" % int(v)
		Sfx.play("tick", 1.0 + v / maxf(total, 1.0), -6.0, 0.05), 0.0, total, 1.4).set_delay(0.4)
	over_first.call_deferred("grab_focus")


# ---------- input ----------

## Android back button: pause / resume.
func back_pressed() -> void:
	if pause_root.visible:
		_close_or_resume()
	elif not busy and not over_root.visible:
		_pause()


func _input(event: InputEvent) -> void:
	_items_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if ability_button.visible and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_Q) \
			and not offer_root.visible and not pause_root.visible and not over_root.visible:
		ability_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if pause_root.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		toggle_stats()
		get_viewport().set_input_as_handled()
		return
	if offer_root.visible and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_5 and event.shift_pressed:
			if not choosing and Global.game and Global.game.bans_left > 0 and k - KEY_1 < current_options.size():
				ban_requested.emit(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
		if k >= KEY_1 and k <= KEY_5:
			_on_card_pressed(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
		if k == KEY_R and not reroll_button.disabled and reroll_button.visible:
			reroll_requested.emit()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		if pause_root.visible:
			_close_or_resume()
		elif not busy and not over_root.visible:
			_pause()
		get_viewport().set_input_as_handled()
