extends Control
## UNLOCKS: tab ACHIEVEMENTS (progress bars, filterable) and CHALLENGES once unlocked. Both are permanent and survive reformats.
## Weapons and evolutions (status, how to get them, kills) live in the CODEX, under WEAPONS.
const ScrollFix = preload("res://scripts/ui/scroll_fix.gd")

var tab := "achievements"
var ach_filter := "all"   # achievements shown: all, done, progress, todo
var box: VBoxContainer
var tab_buttons := {}

const Achievements = preload("res://scripts/achievements.gd")


func _ready() -> void:
	Music.play_title()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := Global.safe_margins()
	# left sidebar: BACK, the title and one button per section (stacked, so nothing runs off a narrow screen); the list scrolls on the right
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
	for pair in [["achievements", "ACHIEVEMENTS"], ["challenges", "CHALLENGES"]]:
		var key: String = pair[0]
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(190, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			Sfx.play("select")
			tab = key
			_rebuild())
		b.visible = key != "challenges" or Meta.trials_available()   # challenges stay hidden until TRIAL ACCESS is bought in the PRESTIGE tree
		side.add_child(b)
		tab_buttons[key] = b
	var codex_button := Button.new()   # the CODEX lives here now (it used to be on the device map)
	codex_button.text = "CODEX"
	codex_button.custom_minimum_size = Vector2(190, 46)
	codex_button.focus_mode = Control.FOCUS_NONE
	codex_button.add_theme_color_override("font_color", Global.C_GOLD)
	codex_button.pressed.connect(func():
		Sfx.play("select")
		Global.change_scene("res://scenes/codex.tscn"))
	side.add_child(codex_button)

	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 12.0 + m["top"]
	scroll.offset_left = 222.0 + m["left"]
	scroll.offset_right = -16.0 - m["right"]
	scroll.offset_bottom = -12.0 - m["bottom"]
	ScrollFix.apply(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	_rebuild()


func _rebuild() -> void:
	for c in box.get_children():
		c.queue_free()
	if tab == "challenges" and not Meta.trials_available():
		tab = "achievements"
	for k in tab_buttons:
		tab_buttons[k].modulate = Color.WHITE if k == tab else Color(0.6, 0.65, 0.7)
	if tab == "challenges":
		_build_challenges()
		return
	_build_achievements()


func _build_challenges() -> void:
	var shown := Meta.Challenges.ALL.filter(func(c): return not (c.has("evo") and not Meta.evolutions_found.has(c["evo"])))   # an undiscovered evolution's trial stays hidden
	_heading("CHALLENGES  %d / %d" % [Meta.challenges_done.size(), shown.size()], box)
	for c in shown:
		var done: bool = Meta.challenges_done.has(c["id"])
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", Global.make_box(Color(0.03, 0.05, 0.09, 0.9),
			Global.C_GREEN if done else Color(0.4, 0.45, 0.55, 0.6), 2, 14, 2))
		box.add_child(pc)
		var col := VBoxContainer.new()
		pc.add_child(col)
		var head := Label.new()
		head.text = "%s%s" % ["DONE  " if done else "", c["name"]]
		head.add_theme_font_override("font", Global.FONT_TITLE)
		head.add_theme_font_size_override("font_size", 16)
		head.add_theme_color_override("font_color", Global.C_GREEN if done else Color(0.75, 0.8, 0.88))
		col.add_child(head)
		var d := Label.new()
		d.text = "Rule: %s.  Goal: %s.\nReward: %s (once)." % [c["rule_text"], c["goal_text"].to_lower(), c["reward_text"]]
		if not Meta.challenge_available(c):
			var req := Meta.weapon_req_text(String(c["reward"]).substr(7)).to_upper() if String(c["reward"]).begins_with("weapon:") else ""
			if req != "":
				d.text += "\n" + req + " to enable it."
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_override("font", Global.FONT_BODY)
		d.add_theme_font_size_override("font_size", 24)
		d.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
		col.add_child(d)
	_heading("Pick a challenge on the device map before you start a run.", box, 22, Color(0.55, 0.7, 0.75))


## Filter states: all, done, in progress (started a lifetime goal, not finished), not completed (not finished and not started).
func _ach_state(a: Dictionary) -> String:
	if Meta.achieved.has(a["id"]):
		return "done"
	if a["type"] == "life" and Achievements.progress(a, Meta.lifetime)[0] > 0.0:
		return "progress"
	return "todo"


func _build_achievements() -> void:
	_heading("ACHIEVEMENTS  %d / %d" % [Meta.achieved.size(), Achievements.LIST.size()], box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for f in [["all", "ALL"], ["done", "COMPLETED"], ["progress", "IN PROGRESS"], ["todo", "NOT COMPLETED"]]:
		var fb := Button.new()
		fb.text = f[1]
		fb.custom_minimum_size = Vector2(0, 46)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.focus_mode = Control.FOCUS_NONE
		fb.add_theme_font_size_override("font_size", 14)
		fb.modulate = Color.WHITE if ach_filter == f[0] else Color(0.6, 0.65, 0.7)
		var key: String = f[0]
		fb.pressed.connect(func():
			Sfx.play("select")
			ach_filter = key
			_rebuild())
		row.add_child(fb)
	var sorted := Achievements.LIST.duplicate()
	sorted.sort_custom(func(a, b): return Meta.achieved.has(a["id"]) and not Meta.achieved.has(b["id"]))   # done first
	for a in sorted:
		if ach_filter == "all" or _ach_state(a) == ach_filter:
			_achievement_row(box, a)
	_heading("Each one pays prestige points once. Permanent through reformats.", box, 22, Color(0.55, 0.7, 0.75))


func _achievement_row(parent: Node, a: Dictionary) -> void:
	var done := Meta.achieved.has(a["id"])
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Global.make_box(Color(0.03, 0.05, 0.09, 0.9),
		Global.C_GOLD if done else Color(0.4, 0.45, 0.55, 0.6), 2, 14, 2))
	parent.add_child(pc)
	var col := VBoxContainer.new()
	pc.add_child(col)
	var head := Label.new()
	head.text = "%s%s   +%d PP" % ["DONE  " if done else "", a["name"], a["pp"]]
	head.add_theme_font_override("font", Global.FONT_TITLE)
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Global.C_GOLD if done else Color(0.75, 0.8, 0.88))
	col.add_child(head)
	var d := Label.new()
	d.text = a["desc"]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_override("font", Global.FONT_BODY)
	d.add_theme_font_size_override("font_size", 24)
	d.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	col.add_child(d)
	if a["type"] == "life" and not done:   # a finished achievement no longer shows its progress bar
		var pr := Achievements.progress(a, Meta.lifetime)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.max_value = pr[1]
		bar.value = minf(pr[0], pr[1])
		col.add_child(bar)
		var t := Label.new()
		t.text = "%s / %s" % [_num(minf(pr[0], pr[1])), _num(pr[1])]
		t.add_theme_font_override("font", Global.FONT_BODY)
		t.add_theme_font_size_override("font_size", 22)
		t.add_theme_color_override("font_color", Color(0.65, 0.8, 0.85))
		col.add_child(t)


func _num(v: float) -> String:
	var n := int(v)
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fK" % (n / 1000.0)
	return str(n)


func _heading(text: String, parent: Node, fsize := 20, col := Global.C_GOLD) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long hint must never widen the list past the screen
	l.add_theme_font_override("font", Global.FONT_TITLE if fsize == 20 else Global.FONT_BODY)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)


func on_back() -> void:
	Global.change_scene("res://scenes/menu.tscn")
