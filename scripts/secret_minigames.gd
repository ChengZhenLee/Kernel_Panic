extends Control
## Paused overlay minigames of the secret rooms (the smartphone's apps). One overlay at a time: the game is paused while it is open, and
## `closed` is emitted with a result dictionary when it closes ({"ok": true} for a win, {"wrong": true} for a mistake that has a cost).
## Built by secret_rooms.gd (child of its UI layer). Everything is drawn in code from the pixel art in art/secret.

signal closed(result: Dictionary)

const PixelArt = preload("res://scripts/pixel_art.gd")

var content: VBoxContainer
var title_label: Label
var done_btn: Button
var leave_btn: Button
var _paused_by_me := false
var _busy := false          # a sequence is playing (the piano) and input is ignored
var _tones := {}
var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Global.C_CYAN))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	title_label = _lbl("", 30, Global.C_CYAN)
	v.add_child(title_label)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	v.add_child(content)
	done_btn = _btn("CLOSE", 28)
	done_btn.pressed.connect(func(): close({"ok": true}))
	v.add_child(done_btn)
	leave_btn = _btn("LEAVE", 22)
	leave_btn.modulate = Color(1, 1, 1, 0.7)
	leave_btn.pressed.connect(func(): close({"abort": true}))
	v.add_child(leave_btn)
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)


func _box(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.97)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_content_margin_all(20)
	return sb


func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Global.FONT_BODY)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", Global.FONT_BODY)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	return b


func is_open() -> bool:
	return visible


## Opens the overlay with an empty content area; the caller fills it. The game stays paused until close().
func open(title: String) -> VBoxContainer:
	for c in content.get_children():
		c.queue_free()
	title_label.text = title
	done_btn.visible = false
	leave_btn.visible = true
	_busy = false
	visible = true
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	return content


## A puzzle is solved: the CLOSE button replaces LEAVE.
func _win() -> void:
	done_btn.visible = true
	leave_btn.visible = false


func close(result := {}) -> void:
	if not visible:
		return
	visible = false
	_player.stop()
	if _paused_by_me:
		_paused_by_me = false
		get_tree().paused = false
	closed.emit(result)


# ---------------------------------------------------------------------------------------------------- a picture with a caption
## Shows a photo (a 384x288 texture) with a caption; used by the camera app's snapped photos.
func show_photo(title: String, tex: Texture2D, caption: String, lore_note := "") -> void:
	var c := open(title)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(448, 336)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.add_child(pic)
	c.add_child(_lbl(caption, 26, Color.WHITE))
	if lore_note != "":
		c.add_child(_lbl(lore_note, 20, Global.C_GOLD))
	_win()


# ---------------------------------------------------------------------------------------------------- photos: tap the corrupted parts
class PhotoView extends Control:
	var shown: Texture2D
	var truth: Texture2D
	var regions: Array = []      # [x, y, w, h] in 64x48 art pixels
	var revealed: Array = []
	var t := 0.0
	var on_tap: Callable

	func _init() -> void:
		custom_minimum_size = Vector2(448, 336)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var k := size.x / 64.0
		draw_texture_rect(shown, Rect2(Vector2.ZERO, size), false)
		for i in regions.size():
			var rg: Array = regions[i]
			var r := Rect2(rg[0] * k, rg[1] * k, rg[2] * k, rg[3] * k)
			if revealed[i]:
				draw_texture_rect_region(truth, r, Rect2(rg[0] * 6.0, rg[1] * 6.0, rg[2] * 6.0, rg[3] * 6.0))
				draw_rect(r, Color(0.45, 0.95, 0.55), false, 3.0)
				continue
			var step := 16.0   # corruption: a field of flickering coloured cells
			var f := int(t * 9.0)
			var cy := 0.0
			while cy < r.size.y:
				var cx := 0.0
				while cx < r.size.x:
					var h: int = absi(hash(Vector3i(int(cx / step) + i * 31, int(cy / step), f)))
					var col := Color.from_hsv(float(h % 360) / 360.0, 0.55 + 0.4 * float(h % 7) / 7.0, 0.35 + 0.65 * float(h % 11) / 11.0)
					draw_rect(Rect2(r.position + Vector2(cx, cy), Vector2(minf(step, r.size.x - cx), minf(step, r.size.y - cy))), col)
					cx += step
				cy += step
			var pulse := 0.5 + 0.5 * sin(t * 6.0 + i)
			draw_rect(r, Color(1.0, 0.3, 0.75, 0.55 + 0.4 * pulse), false, 4.0)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			on_tap.call(ev.position)


func photo_observe(title: String, shown: Texture2D, truth: Texture2D, regions: Array, caption: String, lore_note: String) -> void:
	var c := open(title)
	var hint := _lbl("PARTS OF THIS PHOTO ARE CORRUPTED. TAP THEM.", 22, Color(1.0, 0.5, 0.8))
	c.add_child(hint)
	var view := PhotoView.new()
	view.shown = shown
	view.truth = truth
	view.regions = regions
	for i in regions.size():
		view.revealed.append(false)
	var cap := _lbl("", 26, Color.WHITE)
	var note := _lbl("", 20, Global.C_GOLD)
	view.on_tap = func(pos: Vector2):
		var k: float = view.size.x / 64.0
		var pick := -1   # one tap restores at most one part: the nearest centre if the parts overlap
		var best := INF
		for i in regions.size():
			var rg: Array = regions[i]
			var rc := Rect2(rg[0] * k, rg[1] * k, rg[2] * k, rg[3] * k)
			if not view.revealed[i] and rc.has_point(pos) and pos.distance_to(rc.get_center()) < best:
				best = pos.distance_to(rc.get_center())
				pick = i
		if pick >= 0:
			view.revealed[pick] = true
			Sfx.play("mg_ok", 1.0 + 0.12 * pick, 0.0, 0.0)
			hint.text = "%d / %d RESTORED" % [view.revealed.count(true), regions.size()]
		if view.revealed.count(true) == regions.size():
			view.shown = view.truth
			hint.text = "PHOTO RESTORED"
			cap.text = caption
			note.text = lore_note
			Sfx.play("app_done", 1.0, 0.0, 0.0)
			_win()
			view.on_tap = func(_p): pass
	c.add_child(view)
	c.add_child(cap)
	c.add_child(note)


# ---------------------------------------------------------------------------------------------------- notes: a caesar cipher
static func caesar(text: String, shift: int) -> String:
	var out := ""
	for i in text.length():
		var ch := text.unicode_at(i)
		if ch >= 65 and ch <= 90:
			out += char(65 + posmod(ch - 65 + shift, 26))
		else:
			out += text[i]
	return out


func cipher(title: String, plain: String, shift: int, hint: String, lore_note: String) -> void:
	var c := open(title)
	var coded := caesar(plain, shift)
	c.add_child(_lbl("THE NOTE IS ENCRYPTED. SHIFT EVERY LETTER BACK UNTIL IT READS AS A MESSAGE.", 20, Color(0.7, 0.8, 1.0)))
	var enc := _lbl(coded, 28, Color(1.0, 0.8, 0.4))
	enc.custom_minimum_size = Vector2(760, 0)
	c.add_child(enc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var minus := _btn("<", 34)
	var plus := _btn(">", 34)
	minus.custom_minimum_size = Vector2(90, 64)
	plus.custom_minimum_size = Vector2(90, 64)
	var sh := _lbl("SHIFT 0", 30, Color.WHITE)
	sh.custom_minimum_size = Vector2(220, 0)
	row.add_child(minus)
	row.add_child(sh)
	row.add_child(plus)
	c.add_child(row)
	var preview := _lbl("", 28, Color(0.6, 1.0, 0.8))
	preview.custom_minimum_size = Vector2(760, 0)
	c.add_child(preview)
	var msg := _lbl("", 22, Color(1.0, 0.5, 0.5))
	var go := _btn("DECRYPT", 30)
	var state := {"shift": 0, "tries": 0}
	var refresh := func():
		sh.text = "SHIFT %d" % state["shift"]
		preview.text = caesar(coded, -int(state["shift"]))
	minus.pressed.connect(func():
		state["shift"] = posmod(int(state["shift"]) - 1, 26)
		Sfx.play("mg_ok", 0.7 + 0.03 * int(state["shift"]), -6.0, 0.0)
		refresh.call())
	plus.pressed.connect(func():
		state["shift"] = posmod(int(state["shift"]) + 1, 26)
		Sfx.play("mg_ok", 0.7 + 0.03 * int(state["shift"]), -6.0, 0.0)
		refresh.call())
	go.pressed.connect(func():
		if int(state["shift"]) == shift:
			msg.text = "DECRYPTED."
			msg.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			Sfx.play("app_done", 1.0, 0.0, 0.0)
			go.visible = false
			minus.disabled = true
			plus.disabled = true
			c.add_child(_lbl(lore_note, 20, Global.C_GOLD))
			_win()
		else:
			state["tries"] = int(state["tries"]) + 1
			msg.text = "STILL GIBBERISH." if int(state["tries"]) < 3 else "STILL GIBBERISH. " + hint
			Sfx.play("mg_bad", 1.0, 0.0, 0.0))
	c.add_child(msg)
	c.add_child(go)
	refresh.call()


# ---------------------------------------------------------------------------------------------------- messages: reply to the pending message
## rounds: [{"from": "...", "text": "...", "options": [...], "correct": 0}], finale: the full context shown after the last right answer.
func chat(title: String, rounds: Array, finale: String, lore_note: String) -> void:
	var c := open(title)
	var log := _lbl("", 22, Color(0.75, 0.9, 0.85))
	log.custom_minimum_size = Vector2(780, 0)
	log.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.add_child(log)
	var pending := _lbl("", 30, Color(0.5, 1.0, 0.7))
	pending.custom_minimum_size = Vector2(780, 0)
	c.add_child(pending)
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	c.add_child(opts)
	var streak_l := _lbl("", 22, Global.C_GOLD)
	c.add_child(streak_l)
	var state := {"i": 0, "log": ""}
	var holder := {}   # the round function calls itself through this (a lambda captures plain variables by value)
	holder["show"] = func():
		for ch in opts.get_children():
			ch.queue_free()
		var rd: Dictionary = rounds[state["i"]]
		pending.text = "%s: %s" % [rd["from"], rd["text"]]
		streak_l.text = "RIGHT REPLIES IN A ROW: %d / %d" % [state["i"], rounds.size()]
		log.text = state["log"]
		var order: Array = range(rd["options"].size())
		order.shuffle()
		for k in order:
			var b := _btn(rd["options"][k], 24)
			b.pressed.connect(func():
				if k == int(rd["correct"]):
					Sfx.play("mg_ok", 1.0 + 0.15 * state["i"], 0.0, 0.0)
					state["log"] += "%s: %s\nYOU: %s\n" % [rd["from"], rd["text"], rd["options"][k]]
					state["i"] += 1
					if state["i"] >= rounds.size():
						for ch in opts.get_children():
							ch.queue_free()
						pending.text = ""
						streak_l.text = "FULL CONVERSATION"
						log.text = state["log"] + "\n" + finale
						c.add_child(_lbl(lore_note, 20, Global.C_GOLD))
						Sfx.play("app_done", 1.0, 0.0, 0.0)
						_win()
					else:
						holder["show"].call()
				else:
					Sfx.play("mg_bad", 1.0, 0.0, 0.0)
					close({"wrong": true}))
			opts.add_child(b)
	holder["show"].call()


# ---------------------------------------------------------------------------------------------------- music: simon says on piano tiles
func _tone(freq: float) -> AudioStreamWAV:
	var key := int(freq * 10.0)
	if _tones.has(key):
		return _tones[key]
	var sr := 22050
	var n := int(sr * 0.7)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var tm := float(i) / sr
		var env := exp(-tm * 4.5) * minf(1.0, tm * 120.0)
		var v := (sin(TAU * freq * tm) + 0.45 * sin(TAU * freq * 2.0 * tm) + 0.2 * sin(TAU * freq * 3.01 * tm)) * env * 0.4
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = data
	_tones[key] = w
	return w


## A piano key: the rendered note (assets/audio/sfx/piano_<i>.wav, tools/gen_sfx_apps.py); the runtime sine tone below is only a fallback if the file is missing.
func _play_note(i: int, freq: float) -> void:
	if Sfx.streams.has("piano_%d" % i):
		Sfx.play("piano_%d" % i, 1.0, -2.0, 0.0)
	else:
		_play_tone(freq)


func _play_tone(freq: float) -> void:
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = _tone(freq)
	p.volume_db = -8.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## keys: [{"name": "E", "freq": 659.3, "color": Color}], sequence: indices into keys played in rounds of `lengths`.
func piano(title: String, keys: Array, sequence: Array, lengths: Array, reveal_text: String, reveal_stream: AudioStream, lore_note: String) -> void:
	var c := open(title)
	var status := _lbl("", 26, Color.WHITE)
	c.add_child(status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var btns := []
	var state := {"round": 0, "pos": 0, "len": lengths[0]}
	var flash := func(i: int, on: bool):
		if i >= btns.size() or not is_instance_valid(btns[i]):
			return
		var b: Button = btns[i]
		var sb := StyleBoxFlat.new()
		var col: Color = keys[i]["color"]
		sb.bg_color = col if on else col.darkened(0.55)
		sb.border_color = Color.WHITE if on else Color(0, 0, 0, 0.6)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
	var play_seq: Callable
	play_seq = func():
		_busy = true
		state["pos"] = 0
		status.text = "LISTEN (%d NOTES)" % state["len"]
		await get_tree().create_timer(0.6).timeout
		if not visible or not is_instance_valid(status):
			return
		for n in int(state["len"]):
			if not visible or not is_instance_valid(status):
				return
			var ki: int = sequence[n]
			flash.call(ki, true)
			_play_note(ki, keys[ki]["freq"])
			await get_tree().create_timer(0.42).timeout
			flash.call(ki, false)
			await get_tree().create_timer(0.14).timeout
		if not visible or not is_instance_valid(status):
			return
		status.text = "YOUR TURN: REPEAT IT"
		_busy = false
	for i in keys.size():
		var b := Button.new()
		b.text = keys[i]["name"]
		b.add_theme_font_override("font", Global.FONT_BODY)
		b.add_theme_font_size_override("font_size", 34)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(120, 280)
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		btns.append(b)
		row.add_child(b)
		flash.call(i, false)
		var ii := i
		b.pressed.connect(func():
			if _busy:
				return
			flash.call(ii, true)
			_play_note(ii, keys[ii]["freq"])
			get_tree().create_timer(0.2).timeout.connect(func(): flash.call(ii, false))
			if sequence[state["pos"]] != ii:
				Sfx.play("mg_bad", 1.0, 0.0, 0.0)
				status.text = "WRONG NOTE. LISTEN AGAIN."
				play_seq.call()
				return
			state["pos"] += 1
			if state["pos"] >= int(state["len"]):
				state["round"] += 1
				if state["round"] >= lengths.size():
					_busy = true
					status.text = reveal_text
					Sfx.play("app_done", 1.0, 0.0, 0.0)
					c.add_child(_lbl(lore_note, 20, Global.C_GOLD))
					if reveal_stream != null:
						_player.stream = reveal_stream
						_player.volume_db = -4.0
						_player.play()
						get_tree().create_timer(14.0).timeout.connect(func(): if _player.playing: _player.stop())
					_win()
				else:
					state["len"] = lengths[state["round"]]
					status.text = "GOOD. A LONGER ONE."
					play_seq.call())
	play_seq.call()
