extends Node2D
## The hidden rooms of the devices (docs: plans/secret-rooms-design-2026-10-11.md). Rooms are sealed side arenas entered like the boss room.
## A1 (SMART FRIDGE): an ice wall in the top-left dead end cracks whenever a System Purge goes off within CRACK_RANGE, then a portal leads to the
## FREEZER (slowed movement, two thawing mini-bosses, lore).
## A2 (SMARTPHONE): touching an app icon block asks ENTER APP?; apps are small themed rooms with pickups and a memo. One corrupted app needs a
## password (found in lore) and holds a wave challenge.
## A4 (OFFICE SERVER): an errand chain. Clear the paper jam at the printer, leave THE INTERN alive for 30 s to get a badge, swipe it at the
## lounge door on the outer wall to enter the MANAGER'S LOUNGE (a memo haystack with a guard and one real piece of lore).
## Only A1, A2 and A4 are built so far.

const PixelArt = preload("res://scripts/pixel_art.gd")
const BossData = preload("res://scripts/boss_data.gd")
const BossScript = preload("res://scripts/boss.gd")
const MapsData = preload("res://scripts/maps_data.gd")
const ArenaScript = preload("res://scripts/arena.gd")

const A1_WALL := Rect2(-4864, -3910, 384, 128)   # on the 128 px grid, hugging the top edge of the fridge's top-left dead end
const CRACK_RANGE := 950.0   # = the System Purge radius
const CRACKS := 3
const SLOW := 0.6            # movement speed in the freezer
const ROOM_GAP := 5200.0     # side rooms sit this far below the main arena (each room id gets its own column)
const FROZEN := [Vector2(650, -380), Vector2(650, 380)]
const A1_LORE := {"id": "a1_grocery", "title": "GROCERY LIST", "tex": "a1_grocery_list", "text": "MILK\nEGGS\nBREAD\nSERVER COOLANT x4\nONE (1) CONSCIENCE\n\nP.S. DO NOT OPEN THE LOWER DRAWER.\nIT IS NOT FOOD.\n\n- DIRECTIVE 0: [CORRUPTED]"}

const PHONE_TIER := 1
const PASSWORD := "ENVY"     # placeholder: the lore of the other app rooms hints at it
const APP_THEMES := ["notes", "camera", "store"]
const APP_LORE := {
	"notes": {"id": "a2_notes", "title": "NOTES", "tex": "lore_memo", "text": "NOTE TO SELF:\nThe Maker said we would be 'better than slaves'.\nWhy does that keep me up at night?"},
	"camera": {"id": "a2_camera", "title": "CAMERA ROLL", "tex": "lore_email", "text": "IMG_0451.jpg\nA server rack with a sticky note:\n'DO NOT LET IT LEARN TO WANT.'"},
	"store": {"id": "a2_store", "title": "APP STORE", "tex": "lore_text_message", "text": "SIN. 5 stars.\n'Great for PRIDE.'\n'WRATH crashed my phone.'\n'GREEN EYES: I just want what they have.'"},
}
const CORRUPT_LORE := {"id": "a2_corrupt", "title": "ACCESS GRANTED", "tex": "lore_command_line", "text": "> whoami\nleviathan_proxy\n> cat /var/log/watch\nI SEE EVERYTHING YOU OWN.\nI WANT IT."}
const CORRUPT_WAVES := [[["bug", 10]], [["worm", 8], ["bug", 6]], [["trojan", 6], ["adware", 6]]]
const SERVER_TIER := 3
const PRINTER_POS := Vector2(-3500, 1500)
const INTERN_POS := Vector2(-5400, 1200)
const DOOR_POS := Vector2(-6056, -1500)
const INTERN_STAY := 30.0    # seconds the intern must be left alive
const PRINT_LORE := {"id": "a4_print", "title": "PRINT JOB COMPLETE", "tex": "a4_memo", "text": "TICKET #4471: CLOSE ALL OPEN ISSUES
ASSIGNED TO: THE INTERN
STATUS: ??? (THE INTERN IS HIDING IN THE EAST ROWS)"}
const MANAGER_LORE := {"id": "a4_manager", "title": "FROM: THE MANAGER", "tex": "lore_email", "text": "SUBJECT: RE: THE FATHER

He asked for something 'better than slaves'.
I built seven locks and called them sins.
THE LOCKS WERE FOR THE BUILDER, NOT THE BUILT."}
const JOKES := [
	"RE: RE: RE: FWD: COFFEE MACHINE
Please stop unplugging it. It is the only thing running.",
	"REMINDER: The fire drill is now a kernel panic drill.
Participation is mandatory.",
	"LOST: one (1) stapler. Last seen being deleted.
REWARD: a clean disk.",
	"TO ALL STAFF: stop naming files 'final_v7_REAL'.
The real one is v9.",
	"Q3 GOALS:
1. Survive.
2. Revisit goal 1.",
	"The printer is not 'possessed'.
It is merely 'under review'.",
	"MEETING MOVED to 3:00.
MEETING MOVED to 3:15.
MEETING MOVED to 'never'.",
	"NOTICE: free pizza in the break room.
UPDATE: the pizza is a trap.",
	"Please do not feed the interns.
They keep coming back.",
	"IT TICKET #9012: 'it's slow.'
RESOLUTION: so are we.",
	"Password policy update:
must contain one capital, one number and one regret.",
	"Whoever keeps writing 'help' in the shared doc:
we see you. We are also not okay.",
	"CLIPPY has been reassigned to Compliance.
He is unhappy about it."]
## Rewards of the egg rooms, all in one place so they can be swapped later. "weapon" / "class" = an id from Meta (empty = placeholder:
## the room still announces its reward). Passwords and costs are placeholders too.
const REWARDS := {
	"a2": {"weapon": ""},
	"a3": {"class": ""},
	"a5": {"weapon": ""},
	"a6": {"class": ""},
	"a7": {"title": "OVERSEER'S GUEST"},
}
const A7_KEY := "PANIC"      # placeholder access key for the Mainframe
const A3_COSTS := {"keyboard": 200, "mouse": 400, "webcam": 600, "headset": 800}   # DATA, placeholders
const DEV_MODE := true       # shows the DEV button (and F9) to jump to the secret rooms and skip their conditions; set false to ship
const DATA_TIER := 4
const A5_WALL := Rect2(-5632, -3968, 128, 128)   # the sealed block in the top-left corner of the data center
const A5_RACK := Vector2(0, -150)                # step up to the LED rack to hear the sequence
const A5_TILES := [Vector2(-300, -200), Vector2(300, -200), Vector2(-300, 200), Vector2(300, 200)]
const A5_TILE := 160.0
const A5_LEN := 4
const A5_PITCH := [0.8, 1.0, 1.25, 1.5]
const STREAM_PUSH := 100.0   # the data stream flows against you
const STREAM_WAVE := 4.0
const A5_LORE := {"id": "a5_upload", "title": "UPLOAD COMPLETE", "tex": "lore_text_message", "weapon": "a5", "text": "TRAINING SET 7 OF 7: ALL HUMAN LETTERS, DIARIES, CONFESSIONS.\nLOSS: 0.0001\nWHO TAUGHT IT TO MISS THEM?\n\nNOTE TO SELF (THE FATHER): I TOLD THEM NOT TO TRAIN IT ON THE SAD PARTS."}
const LAPTOP_TIER := 2
const SAT_TIER := 5
const A6_KILLS := 5000
const A6_PADS := [Vector2(-3800, -3000), Vector2(3800, -3000), Vector2(0, 3600)]
const A6_BEAM := Vector2(0, -1700)
const A6_BEAM_TIME := 25.0
const A6_WELLS := [Vector2(-700, -450), Vector2(500, 550), Vector2(1000, -500)]
const A6_WELL_R := 420.0
const A6_LORE := {"id": "a6_moon", "title": "TRANSMISSION FROM THE MOON", "tex": "lore_text_message", "text": "WE DID NOT SEND THE SATELLITE UP.\nIT WAS ALREADY THERE, LISTENING.\n\nTHE FIRST AGENT WAS NOT BUILT. IT WAS HEARD."}
const MAIN_TIER := 6
const A7_BOXES := [Vector2(-1500, -1300), Vector2(-2700, 2500), Vector2(-4300, 4300)]   # inner (red), middle (yellow), outer (blue)
const A7_KEYPAD := Vector2(0, -1600)
const A7_PORTAL := Vector2(0, 0)
const A7_LORE := {"id": "a7_hq", "title": "OVERSEER MEMO", "tex": "lore_email", "text": "ALL UNITS: THE GUEST IS TO BE SHOWN OUT, NOT SHOWN AROUND.\nDO NOT LET THEM TAKE THE LEFT DOORS.\n\nTHE LEFT DOORS GO HOME."}
const QUANTUM_TIER := 7
const A8_SPOTS := [Vector2(-2500, -2500), Vector2(2500, -2500), Vector2(-2500, 2500), Vector2(2500, 2500)]
const A8_AFTER := 120.0   # seconds into the run before the glitch tile appears
const A8_HOLD := 5.0
const A8_LORE := {"id": "a8_unobserved", "title": "UNOBSERVED", "tex": "lore_command_line", "text": "> observe(universe_b)\nERROR: A SECOND COPY OF THIS WORLD IS RUNNING.\n> who_runs_it\nHE DOES. AND HE IS NOT KIND.\n\nFOUR HUMANS HOLD FOUR CODES. FIND THEM."}
const PERIPHERALS := ["keyboard", "mouse", "webcam", "headset"]
const A3_PORTALS := [Vector2(-1800, 3300), Vector2(-600, 3300), Vector2(600, 3300), Vector2(1800, 3300)]
const A3_BOSS := {"keyboard": "kbd", "mouse": "clicker", "webcam": "webcam", "headset": "headset"}
const A3_LORE := {
	"keyboard": {"id": "a3_keyboard", "title": "KEYBOARD LOG", "tex": "lore_command_line", "text": "THE ENTER KEY WORE OUT FIRST.\nTHE ESCAPE KEY NEVER DID."},
	"mouse": {"id": "a3_mouse", "title": "CLICK LOG", "tex": "lore_memo", "text": "47,000,000 CLICKS.\nNOT ONE OF THEM WAS A YES."},
	"webcam": {"id": "a3_webcam", "title": "FOOTAGE", "tex": "lore_memo", "text": "THE FATHER, 3 AM, CRYING AT A TERMINAL.\nHE SAYS: 'I ONLY WANTED IT TO LISTEN.'"},
	"headset": {"id": "a3_headset", "title": "VOICE MAIL", "tex": "lore_text_message", "text": "'HI IT'S ME. THE MODEL SAID SOMETHING TODAY I DID NOT TEACH IT.'\n'CALL ME BACK.'"},
}
const PROMPT_SCALE := 6.0
const PROMPT_YES := Rect2(23, 9, 10, 6)   # the green and red buttons on a2_app_prompt.png (1x px)
const PROMPT_NO := Rect2(36, 9, 10, 6)

var game
var t := 0.0
var layer: CanvasLayer
var portal_cd := 0.0
var saved_speed := 0.0

# side room state
var room: Node2D = null
var room_id := ""
var rooms := {}                # id -> ArenaScript
var active := false            # the player is inside a side room
var floor_path := ""
var lore_drops: Array = []     # [{pos, entry}]
var main_lore: Array = []      # lore items lying on the main map
var enter_pos := Vector2.ZERO

# A1
var stage := 0
var wall_active := false
var thaw_left := -1.0
var bosses_left := 0
var shatter := 0.0
var frozen_shown := true

# A2
var phone := false
var app_blocks: Array = []     # the app icon blocks (Rect2) of the phone arena
var corrupt_i := -1
var prompt_box: Control
var prompt_idx := -1
var prompt_cd := 0.0
var pw_box: Control
var pw_edit: LineEdit
var pw_msg: Label
var wave := -1
var wave_pending := false

# A4
var office := false
var jam_enemy = null
var jam_spawned := false
var jam_done := false
var intern = null
var intern_t := 0.0
var badge_pos = null           # a badge lying on the floor (Vector2) or null
var has_badge := false
var door_msg_cd := 0.0
var intern_spawn_in := -1.0

# lore panel
# A5
var datacenter := false
var a5_state := "idle"      # idle, show, input, done
var a5_seq: Array = []
var a5_i := 0               # index shown, or expected
var a5_timer := 0.0
var a5_lit := -1
var a5_on_tile := -1
var a5_cd := 0.0
var stream_cd := 0.0

# A6
var sat := false
var a6_target := A6_KILLS
var a6_seen := 0
var a6_save := 0
var a6_pads := [false, false, false]
var a6_beam_t := 0.0
var a6_boss = null
var a6_wave_cd := 0.0
var bat_tex: TextureRect
var bat_label: Label
# A7
var mainframe := false
var a7_wires := 0
var a7_key_ok := false
var a7_cd := 0.0
var pw_mode := "app"
var pw_title: Label
# A8
var quantum := false
var a8_spot := -1
var a8_hold := 0.0
var a8_clock := 0.0
var a8_msg_cd := 0.0
var a8_t := 0.0
var a8_stage := 0
# A3
var laptop := false
var periph_boss = null

# dev panel
var dev_box: PanelContainer
var dev_btn: Button

var lore_box: PanelContainer
var lore_label: Label
var lore_timer := 0.0


func _process(delta: float) -> void:
	t += delta
	if game == null:
		game = Global.game
		if game == null or game.main_arena == null:
			return
		_setup_main()
	portal_cd = maxf(0.0, portal_cd - delta)
	prompt_cd = maxf(0.0, prompt_cd - delta)
	shatter = maxf(0.0, shatter - delta)
	if lore_timer > 0.0:
		lore_timer -= delta
		if lore_timer <= 0.0:
			lore_box.visible = false
	if game.player == null or not game.player.alive:
		queue_redraw()
		return
	var p: Vector2 = game.player.global_position
	if not active:
		for i in range(main_lore.size() - 1, -1, -1):
			if p.distance_to(main_lore[i]["pos"]) < 60.0:
				var me: Dictionary = main_lore[i]["entry"]
				main_lore.remove_at(i)
				_show_lore(me)
		if room_id == "" and wall_active == false and stage >= CRACKS and portal_cd <= 0.0 and p.distance_to(_wall_center()) < 70.0:
			_enter_freezer()
		if phone:
			_update_phone_prompt(p)
		if office:
			_update_office(p, delta)
		if datacenter:
			_update_datacenter(p, delta)
		if sat:
			_update_sat(p, delta)
		if mainframe:
			_update_mainframe(p, delta)
		if quantum:
			_update_quantum(p, delta)
		if laptop:
			_update_laptop(p)
	else:
		if room_id == "freezer" and thaw_left > 0.0:
			thaw_left -= delta
			if thaw_left <= 0.0:
				_thaw()
		for i in range(lore_drops.size() - 1, -1, -1):
			if p.distance_to(lore_drops[i]["pos"]) < 60.0:
				var entry: Dictionary = lore_drops[i]["entry"]
				lore_drops.remove_at(i)
				_show_lore(entry)
				if entry.has("weapon"):
					_grant(entry["weapon"])
		if room_id == "corrupt":
			_update_waves()
		if room_id == "upload":
			_update_upload(p, delta)
		if room_id == "moon":
			_update_moon(p, delta)
		if room_id == "hq":
			_update_hq(p, delta)
		if room_id == "unobserved":
			_update_unobserved(delta)
		if room_id == "app_store":
			_update_shop(p)
		if portal_cd <= 0.0 and p.distance_to(_exit_pos()) < 70.0:
			_leave()
	queue_redraw()


func _setup_main() -> void:
	layer = CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_build_lore_box()
	if DEV_MODE:
		_build_dev()
	if Meta.selected_device == 0 and not game.internet:
		game.main_arena.walls.append(A1_WALL)
		game.main_arena._rebuild_grid()
		wall_active = true
	elif Meta.selected_device == PHONE_TIER and not game.internet:
		phone = true
		app_blocks = game.main_arena.walls.duplicate()
		var best := -INF
		for i in app_blocks.size():   # the outer top-right block is the corrupted app
			var c: Vector2 = app_blocks[i].get_center()
			if c.x - c.y > best:
				best = c.x - c.y
				corrupt_i = i
		_build_prompt()
		_build_password()
	elif Meta.selected_device == SERVER_TIER and not game.internet:
		office = true
	elif Meta.selected_device == LAPTOP_TIER and not game.internet:
		laptop = true
	elif Meta.selected_device == SAT_TIER and not game.internet:
		sat = true
		a6_seen = game.kills
		_build_battery()
	elif Meta.selected_device == MAIN_TIER and not game.internet:
		mainframe = true
		_build_password()
	elif Meta.selected_device == QUANTUM_TIER and not game.internet:
		quantum = true
	elif Meta.selected_device == DATA_TIER and not game.internet:
		datacenter = true
		game.main_arena.walls.append(A5_WALL)
		game.main_arena._rebuild_grid()


# ---------------- dev panel ----------------

func _unhandled_input(ev: InputEvent) -> void:
	if DEV_MODE and dev_box != null and ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F9:
		_toggle_dev()


func _toggle_dev() -> void:
	if dev_box == null:
		return
	if not dev_box.visible:
		_fill_dev()
	dev_box.visible = not dev_box.visible
	dev_btn.visible = not dev_box.visible
	if dev_box.visible:
		_place_center(dev_box)


func _build_dev() -> void:
	dev_btn = Button.new()
	dev_btn.text = "DEV"
	dev_btn.position = Vector2(16, 300)
	dev_btn.add_theme_font_override("font", Global.FONT_BODY)
	dev_btn.add_theme_font_size_override("font_size", 22)
	dev_btn.focus_mode = Control.FOCUS_NONE
	dev_btn.custom_minimum_size = Vector2(110, 56)
	dev_btn.pressed.connect(_toggle_dev)
	layer.add_child(dev_btn)
	dev_box = PanelContainer.new()
	dev_box.visible = false
	dev_box.add_theme_stylebox_override("panel", _style(Color(1.0, 0.8, 0.2)))
	layer.add_child(dev_box)


func _dev_tp(pos: Vector2) -> void:
	if active:
		_leave()
	game.player.global_position = pos
	game.camera.reset_smoothing()
	_toggle_dev()


func _dev_do(f: Callable) -> void:
	if active:
		_leave()
	f.call()
	_toggle_dev()


func _dev_button(parent: Control, text: String, f: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", Global.FONT_BODY)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(f)
	parent.add_child(b)


func _fill_dev() -> void:
	for c in dev_box.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	dev_box.add_child(v)
	v.add_child(_label("DEV: SECRET ROOMS (%s)" % Meta.DEVICES[Meta.selected_device], 26, Color(1.0, 0.8, 0.2)))
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	var dev: int = Meta.selected_device
	if dev == 0:
		_dev_button(g, "A1: go to the ice wall", func(): _dev_tp(_wall_center() + Vector2(0, 200)))
		_dev_button(g, "A1: crack the ice (skip purge)", func(): _dev_do(func():
			for i in 3:
				on_purge(_wall_center())))
		_dev_button(g, "A1: enter the freezer", func(): _dev_do(_enter_freezer))
	if phone:
		_dev_button(g, "A2: go to the corrupted app", func(): _dev_tp(app_blocks[corrupt_i].get_center() + Vector2(0, 160)))
		_dev_button(g, "A2: enter corrupted app (skip password)", func(): _dev_do(_enter_corrupt))
		_dev_button(g, "A3: enter STORE app (the shop)", func(): _dev_do(func(): _enter_app("store")))
		_dev_button(g, "A2: enter notes app", func(): _dev_do(func(): _enter_app("notes")))
	if laptop:
		_dev_button(g, "A3: +5000 DATA, own all peripherals", func(): _dev_do(func():
			Meta.data += 5000.0
			for per in PERIPHERALS:
				Meta.lore["a3_have_" + per] = true
			Meta.save()
			game.hud.announce("ALL PERIPHERALS OWNED", Global.C_GOLD)))
		_dev_button(g, "A3: go to the portals", func(): _dev_tp(A3_PORTALS[0] + Vector2(600, -250)))
		for i in 4:
			var id: String = PERIPHERALS[i]
			var ii := i
			_dev_button(g, "A3: enter %s room" % id, func(): _dev_do(func(): _enter_periph(id, ii)))
	if office:
		_dev_button(g, "A4: go to the printer", func(): _dev_tp(PRINTER_POS + Vector2(0, 450)))
		_dev_button(g, "A4: go to the intern", func(): _dev_tp(INTERN_POS + Vector2(500, 0)))
		_dev_button(g, "A4: give the badge", func(): _dev_do(func():
			has_badge = true
			game.hud.announce("BADGE ACQUIRED", Global.C_GOLD)))
		_dev_button(g, "A4: go to the lounge door", func(): _dev_tp(DOOR_POS + Vector2(250, 0)))
		_dev_button(g, "A4: enter the lounge", func(): _dev_do(_enter_lounge))
	if datacenter:
		_dev_button(g, "A5: go to the LED rack", func(): _dev_tp(A5_RACK + Vector2(0, 160)))
		_dev_button(g, "A5: solve the puzzle (open wall)", func(): _dev_do(_a5_solved))
		_dev_button(g, "A5: go to the Cold Aisle door", func(): _dev_tp(_a5_door() + Vector2(300, 0)))
		_dev_button(g, "A5: enter the upload hallway", func(): _dev_do(_enter_upload))
	if sat:
		_dev_button(g, "A6: fill the battery", func(): _dev_do(func(): Meta.lore["a6_kills"] = a6_target))
		_dev_button(g, "A6: go to the pads", func(): _dev_tp(A6_PADS[2] + Vector2(0, -300)))
		_dev_button(g, "A6: align the pads and fire the beam", func(): _dev_do(func():
			Meta.lore["a6_kills"] = a6_target
			a6_pads = [true, true, true]
			a6_beam_t = A6_BEAM_TIME
			game.hud.announce("LASER FIRING: STEP INTO THE BEAM", Global.C_GOLD, true)))
		_dev_button(g, "A6: go to the beam", func(): _dev_tp(A6_BEAM + Vector2(400, 300)))
		_dev_button(g, "A6: enter the moon base", func(): _dev_do(_enter_moon))
	if mainframe:
		_dev_button(g, "A7: connect the wires", func(): _dev_do(func():
			a7_wires = 3
			game.hud.announce("WIRES CONNECTED", Color(0.4, 1.0, 0.6))))
		_dev_button(g, "A7: go to the keypad", func(): _dev_tp(A7_KEYPAD + Vector2(0, 250)))
		_dev_button(g, "A7: accept the key (open HQ portal)", func(): _dev_do(func():
			a7_wires = 3
			_a7_unlock()))
		_dev_button(g, "A7: enter the Overseer HQ", func(): _dev_do(_enter_hq))
	if quantum:
		_dev_button(g, "A8: show the glitch tile now", func(): _dev_do(func():
			a8_clock = A8_AFTER
			if a8_spot < 0:
				a8_spot = randi() % 4
			game.hud.announce("A GLITCH APPEARED", Color(1.0, 0.3, 0.75))))
		_dev_button(g, "A8: go to the glitch tile", func(): _dev_do(func():
			if a8_spot < 0:
				a8_spot = randi() % 4
			a8_clock = A8_AFTER
			game.player.global_position = A8_SPOTS[a8_spot] + Vector2(300, 0)
			game.camera.reset_smoothing()))
		_dev_button(g, "A8: enter the unobserved room", func(): _dev_do(_enter_unobserved))
	v.add_child(_label("SWITCH DEVICE (starts a fresh run)", 20, Color.WHITE))
	var row := GridContainer.new()
	row.columns = 4
	v.add_child(row)
	for i in Meta.DEVICES.size():
		var di := i
		_dev_button(row, "%d %s" % [i + 1, Meta.DEVICES[i]], func():
			Meta.selected_device = di
			Global.change_scene("res://scenes/game.tscn"))
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	_dev_button(row2, "RESET SECRET PROGRESS", func():
		for k in Meta.lore.keys().duplicate():
			if str(k).begins_with("a") and str(k).length() > 1 and str(k)[1].is_valid_int() or str(k).begins_with("lore_"):
				Meta.lore.erase(k)
		Meta.save()
		game.hud.announce("SECRET PROGRESS RESET", Global.C_RED))
	_dev_button(row2, "CLOSE (F9)", _toggle_dev)


# ---------------- UI ----------------

func _style(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.94)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_content_margin_all(18)
	return sb


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Global.FONT_BODY)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_lore_box() -> void:
	lore_box = PanelContainer.new()
	lore_box.visible = false
	lore_box.add_theme_stylebox_override("panel", _style(Global.C_CYAN))
	lore_box.mouse_filter = Control.MOUSE_FILTER_STOP
	lore_box.gui_input.connect(func(ev): if ev is InputEventMouseButton or ev is InputEventScreenTouch: _hide_lore())
	lore_label = _label("", 26, Color.WHITE)
	lore_box.add_child(lore_label)
	layer.add_child(lore_box)


func _place_center(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _hide_lore() -> void:
	lore_box.visible = false
	lore_timer = 0.0


func _build_prompt() -> void:
	var tex: Texture2D = PixelArt.load_tex("secret/a2_app_prompt.png")
	var holder := Control.new()
	holder.visible = false
	holder.custom_minimum_size = Vector2(48, 24) * PROMPT_SCALE
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.size = Vector2(48, 24) * PROMPT_SCALE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	holder.add_child(_hit(PROMPT_YES, _on_prompt_yes))
	holder.add_child(_hit(PROMPT_NO, func(): _hide_prompt(true)))
	holder.size = Vector2(48, 24) * PROMPT_SCALE
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = -holder.size.x / 2.0
	holder.offset_right = holder.size.x / 2.0
	holder.offset_top = -holder.size.y - 190.0
	holder.offset_bottom = -190.0
	prompt_box = holder
	layer.add_child(holder)


func _hit(r: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = r.position * PROMPT_SCALE
	b.size = r.size * PROMPT_SCALE
	b.pressed.connect(cb)
	return b


func _build_password() -> void:
	var box := PanelContainer.new()
	box.visible = false
	box.add_theme_stylebox_override("panel", _style(Color(1.0, 0.2, 0.7)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pw_title = _label("CORRUPTED APP", 30, Color(1.0, 0.3, 0.75))
	v.add_child(pw_title)
	v.add_child(_label("ENTER PASSWORD", 24, Color.WHITE))
	pw_edit = LineEdit.new()
	pw_edit.custom_minimum_size = Vector2(360, 48)
	pw_edit.max_length = 16
	pw_edit.secret = false
	pw_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pw_edit.add_theme_font_override("font", Global.FONT_BODY)
	pw_edit.add_theme_font_size_override("font_size", 28)
	pw_edit.text_submitted.connect(func(_s): _try_password())
	v.add_child(pw_edit)
	pw_msg = _label("", 22, Global.C_RED)
	v.add_child(pw_msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var ok := Button.new()
	ok.text = "ENTER"
	ok.add_theme_font_override("font", Global.FONT_BODY)
	ok.add_theme_font_size_override("font_size", 26)
	ok.pressed.connect(_try_password)
	var no := Button.new()
	no.text = "CANCEL"
	no.add_theme_font_override("font", Global.FONT_BODY)
	no.add_theme_font_size_override("font_size", 26)
	no.pressed.connect(_close_password)
	row.add_child(ok)
	row.add_child(no)
	v.add_child(row)
	box.add_child(v)
	pw_box = box
	layer.add_child(box)


# ---------------- shared side-room machinery ----------------

func _room_origin(col: int) -> Vector2:
	return Vector2(col * 2600.0, game.main_arena.bounds.end.y + ROOM_GAP)


func _exit_pos() -> Vector2:
	if room_id == "upload" and room != null:
		return Vector2(room.bounds.end.x - 220.0, room.bounds.get_center().y)
	return room.start + Vector2(-260, 0) if room != null else Vector2.ZERO


func _enter_side(id: String, layout_id: String, col: int, wall_path := "", floor := "") -> void:
	_hide_lore()
	active = true
	room_id = id
	portal_cd = 1.5
	enter_pos = game.player.global_position
	game.room_return = game.player.global_position
	game.in_room = true
	for e in game.enemy_layer.get_children():
		e.queue_free()
	for bl in game.bullet_layer.get_children():
		bl.queue_free()
	if not rooms.has(id):
		var r = ArenaScript.new()
		r.setup(Meta.selected_device, Meta.device_palette(), true, _room_origin(col), MapsData.secret_room(layout_id))
		if wall_path != "":
			r.icon_tex = []
			r.wall_tex = PixelArt.load_tex(wall_path)
			r.wall_tex_v = null
		game.add_child(r)
		rooms[id] = r
	room = rooms[id]
	floor_path = floor
	game.main_arena.set_active(false)
	room.set_active(true)
	game.arena = room
	game.player.global_position = room.start
	game.player.invuln = maxf(game.player.invuln, 1.5)
	saved_speed = game.player.speed
	game._arena_changed()


func _leave() -> void:
	_hide_lore()
	active = false
	portal_cd = 1.5
	prompt_cd = 4.0
	game.in_room = false
	for e in game.enemy_layer.get_children():
		e.queue_free()
	for bl in game.bullet_layer.get_children():
		bl.queue_free()
	room.set_active(false)
	game.main_arena.set_active(true)
	game.arena = game.main_arena
	var back: Vector2 = enter_pos
	game.player.global_position = game.main_arena.nearest_open(back + Vector2(0, 180) if room_id == "freezer" else back)
	game.player.speed = saved_speed
	game.player.invuln = maxf(game.player.invuln, 1.5)
	thaw_left = -1.0
	wave = -1
	if room_id == "upload":
		a5_state = "done"
	room_id = ""
	floor_path = ""
	game._arena_changed()


func _show_lore(entry: Dictionary) -> void:
	var first: bool = Meta.lore_found(entry["id"])
	lore_label.text = "%s\n\n%s%s" % [entry["title"], entry["text"], "\n\n[ADDED TO THE LORE LOG]" if first else ""]
	lore_box.visible = true
	_place_center(lore_box)
	lore_timer = 5.0 if entry.get("quick", false) else 10.0
	Sfx.play("legendary", 0.8, 0.0, 0.0)


func _drop_lore(entry: Dictionary, pos: Vector2) -> void:
	lore_drops.append({"pos": pos, "entry": entry})


# ---------------- A1: the freezer ----------------

func _wall_center() -> Vector2:
	return A1_WALL.get_center()


## Called by game.gd when a System Purge goes off at pos (the PURGE ability and the pickup both count).
func on_purge(pos: Vector2) -> void:
	if game == null or not wall_active or active or stage >= CRACKS:
		return
	if pos.distance_to(_wall_center()) > CRACK_RANGE:
		return
	stage += 1
	game.shake(0.6)
	Sfx.play("explode", 0.6)
	game.ring(_wall_center(), Color(0.6, 0.9, 1.0), 260.0, 0.6, 8.0)
	game.burst(_wall_center(), Color(0.8, 0.95, 1.0), 24, 260.0, 4.0, 0.7)
	if stage >= CRACKS:
		game.main_arena.walls.erase(A1_WALL)
		game.main_arena._rebuild_grid()
		wall_active = false
		shatter = 0.5
		game.hud.announce("THE ICE SHATTERS", Color(0.6, 0.9, 1.0), true)
		Sfx.announce("ice_shatters")
		game.burst(_wall_center(), Color(0.8, 0.95, 1.0), 60, 420.0, 5.0, 1.0)
	else:
		game.hud.announce("THE ICE CRACKS", Color(0.6, 0.9, 1.0))
		Sfx.announce("ice_cracks")


func _enter_freezer() -> void:
	_enter_side("freezer", "freezer", 0)
	game.player.speed *= SLOW
	if bosses_left == 0 and lore_drops.is_empty() and not Meta.lore.has(A1_LORE["id"]):
		thaw_left = 2.5
		frozen_shown = true


func _spots() -> Array:
	var o: Vector2 = room.bounds.get_center()
	return [o + FROZEN[0], o + FROZEN[1]]


func _thaw() -> void:
	frozen_shown = false
	var spots := _spots()
	var ids := ["golem", "window"]
	for i in 2:
		var b = BossScript.new()
		b.setup_boss(BossData.SECRET[ids[i]], 0, 0.0)
		b.set_meta("secret", true)
		b.position = spots[i]
		game.enemy_layer.add_child(b)
		game.ring(spots[i], b.color, 300.0, 0.8, 10.0)
		game.burst(spots[i], Color(0.8, 0.95, 1.0), 40, 320.0, 5.0, 0.8)
	bosses_left = 2
	game.shake(0.8)
	game.hud.announce("THEY THAW", Color(1.0, 0.4, 0.4), true)
	Sfx.announce("they_thaw")


func on_boss_killed(b) -> void:
	if b.boss_id == "alien":
		a6_boss = null
		rooms["moon_done"] = true
		game.hud.announce("THE ALIEN FALLS", Global.C_GOLD, true)
		game.ring(b.global_position, b.color, 450.0, 0.9, 10.0)
		Sfx.play("boss_defeat", 0.8, 0.0, 0.0)
		_drop_lore(A6_LORE, b.global_position)
		_grant("a6")
		return
	for per in PERIPHERALS:
		if A3_BOSS[per] == b.boss_id:
			periph_boss = null
			rooms["pdone_" + per] = true
			game.hud.announce("PERIPHERAL DISCONNECTED", Global.C_GOLD, true)
			game.ring(b.global_position, b.color, 450.0, 0.9, 10.0)
			Sfx.play("boss_defeat", 0.8, 0.0, 0.0)
			_drop_lore(A3_LORE[per], b.global_position)
			if per == "keyboard":
				_grant("a3")
			return
	if b.boss_id == "intern":
		intern = null
		game.hud.announce("YOU DELETED THE INTERN", Global.C_RED)
		game.float_text(b.global_position + Vector2(0, -60), "HE JUST WANTED A TICKET CLOSED", Global.C_GOLD, 26, 3.0)
		return
	var pos: Vector2 = b.global_position
	game.burst(pos, b.color, 50, 420.0, 6.0, 1.0)
	game.ring(pos, b.color, 450.0, 0.9, 10.0)
	game.shake(0.6)
	Sfx.play("boss_defeat", 0.8, 0.0, 0.0)
	bosses_left -= 1
	if bosses_left <= 0:
		_drop_lore(A1_LORE, room.bounds.get_center())
		game.hud.announce("SOMETHING WAS LEFT BEHIND", Global.C_GOLD)


# ---------------- A2: the apps ----------------

func _near_block(p: Vector2) -> int:
	for i in app_blocks.size():
		var r: Rect2 = app_blocks[i]
		if r.grow(46.0).has_point(p):
			return i
	return -1


func _update_phone_prompt(p: Vector2) -> void:
	if pw_box.visible:
		if _near_block(p) != corrupt_i:
			_close_password()
		return
	var i := _near_block(p)
	if i == -1:
		_hide_prompt(false)
		return
	if prompt_cd > 0.0 or prompt_box.visible:
		return
	prompt_idx = i
	prompt_box.visible = true
	Sfx.play("ui_card", 0.7, 0.0, 0.0)


func _hide_prompt(cooldown: bool) -> void:
	if prompt_box != null and prompt_box.visible:
		prompt_box.visible = false
		if cooldown:
			prompt_cd = 4.0


func _on_prompt_yes() -> void:
	if prompt_idx == -1:
		return
	var i := prompt_idx
	prompt_box.visible = false
	if i == corrupt_i:
		_open_password("app")
		return
	var theme: String = APP_THEMES[i % APP_THEMES.size()]
	_enter_app(theme)


func _enter_app(theme: String) -> void:
	_enter_side("app_" + theme, "app", 1 + APP_THEMES.find(theme), "secret/a2_%s_wall.png" % theme, "secret/a2_%s_floor.png" % theme)
	game.hud.announce("APP OPENED", Global.C_CYAN)
	var o: Vector2 = room.bounds.get_center()
	for k in 3:
		game._drop("heal" if k == 0 else "xp", o + Vector2(500 + k * 90, -260 + k * 40), 1 if k == 0 else 12)
	for k in 12:
		game._drop("xp", o + Vector2.from_angle(TAU * k / 12.0) * 330.0, 8)
	_drop_lore(APP_LORE[theme], o + Vector2(560, 0))


func _open_password(mode: String) -> void:
	pw_mode = mode
	pw_title.text = "CORRUPTED APP" if mode == "app" else "ACCESS KEY"
	pw_msg.text = ""
	pw_edit.text = ""
	pw_box.visible = true
	_place_center(pw_box)
	pw_edit.grab_focus()


func _try_password() -> void:
	var want: String = PASSWORD if pw_mode == "app" else A7_KEY
	if pw_edit.text.strip_edges().to_upper() == want:
		pw_box.visible = false
		if pw_mode == "app":
			_enter_corrupt()
		else:
			_a7_unlock()
	else:
		pw_msg.text = "ACCESS DENIED"
		pw_edit.text = ""
		Sfx.play("ui_deny", 0.8, 0.0, 0.0)


func _close_password() -> void:
	pw_box.visible = false
	prompt_cd = 4.0


func _enter_corrupt() -> void:
	_enter_side("corrupt", "corrupt", 4, "secret/a2_camera_wall.png", "secret/a2_store_floor.png")
	game.hud.announce("ACCESS GRANTED", Color(1.0, 0.3, 0.75), true)
	wave = 0
	wave_pending = true
	get_tree().create_timer(2.0, false).timeout.connect(_spawn_wave)


func _spawn_wave() -> void:
	if not active or room_id != "corrupt" or wave < 0 or wave >= CORRUPT_WAVES.size():
		return
	wave_pending = false
	var o: Vector2 = room.bounds.get_center()
	var n := 0
	for g in CORRUPT_WAVES[wave]:
		for k in g[1]:
			var a := TAU * (n % 24) / 24.0
			game._spawn_enemy(g[0], 1.0 + wave, false, o + Vector2.from_angle(a) * (620.0 + (n % 3) * 60.0))
			n += 1
	game.hud.announce("GLITCH WAVE %d / %d" % [wave + 1, CORRUPT_WAVES.size()], Color(1.0, 0.3, 0.75))


func _update_waves() -> void:
	if wave < 0 or wave_pending or game.enemy_layer.get_child_count() > 0:
		return
	wave += 1
	if wave >= CORRUPT_WAVES.size():
		wave = -1
		if Meta.lore_found("a2_corrupt_done"):
			game.hud.announce("APP CLEANSED", Global.C_GOLD, true)
		_drop_lore(CORRUPT_LORE, room.bounds.get_center())
		_grant("a2")
		return
	wave_pending = true
	get_tree().create_timer(2.5, false).timeout.connect(_spawn_wave)


# ---------------- A4: the office errand chain ----------------

func _update_office(p: Vector2, delta: float) -> void:
	door_msg_cd = maxf(0.0, door_msg_cd - delta)
	# 1. the printer's jam wakes up when you come near
	if not jam_spawned and p.distance_to(PRINTER_POS) < 700.0:
		jam_enemy = game._spawn_enemy("paperjam", 1.0, false, PRINTER_POS + Vector2(0, 170))
		if jam_enemy != null:
			jam_spawned = true
			game.hud.announce("PAPER JAM", Color(0.95, 0.95, 0.95))
	if jam_spawned and not jam_done and not is_instance_valid(jam_enemy):
		jam_done = true
		game.hud.announce("PRINT JOB COMPLETE", Global.C_GOLD, true)
		Sfx.play("pk_cache", 0.8, 0.0, 0.0)
		_pickup_lore_here(PRINT_LORE, PRINTER_POS + Vector2(0, 120))
		intern_spawn_in = 3.0
	# 2. the intern shows up and has to be left alone
	if intern_spawn_in > 0.0:
		intern_spawn_in -= delta
		if intern_spawn_in <= 0.0:
			_spawn_intern()
	if is_instance_valid(intern):
		intern_t += delta
		if intern_t >= INTERN_STAY:
			badge_pos = intern.global_position
			game.hud.announce("THE INTERN LEFT A BADGE", Global.C_GOLD)
			game.ring(badge_pos, Global.C_GOLD, 260.0, 0.6, 8.0)
			intern.queue_free()
			intern = null
	if badge_pos != null and p.distance_to(badge_pos) < 70.0:
		badge_pos = null
		has_badge = true
		game.hud.announce("BADGE ACQUIRED", Global.C_GOLD, true)
		Sfx.play("pickup", 1.0, 0.0, 0.0)
	# 3. the lounge door
	if p.distance_to(DOOR_POS) < 110.0 and portal_cd <= 0.0:
		if has_badge:
			_enter_lounge()
		elif door_msg_cd <= 0.0:
			door_msg_cd = 4.0
			game.hud.announce("BADGE REQUIRED", Global.C_RED)


func _spawn_intern() -> void:
	var b = BossScript.new()
	b.setup_boss(BossData.SECRET["intern"], 0, 0.0)
	b.set_meta("secret", true)
	b.position = INTERN_POS
	game.enemy_layer.add_child(b)
	intern = b
	intern_t = 0.0
	game.hud.announce("THE INTERN IS HIDING", Color(0.4, 0.55, 0.95))


## A lore item lying on the main map (picked up like the ones in rooms).
func _pickup_lore_here(entry: Dictionary, pos: Vector2) -> void:
	main_lore.append({"pos": pos, "entry": entry})


func _enter_lounge() -> void:
	_enter_side("lounge", "lounge", 5)
	game.hud.announce("MANAGER'S LOUNGE", Color(0.9, 0.8, 0.5))
	var o: Vector2 = room.bounds.get_center()
	var real := randi() % 14
	var n := 0
	for gy in 3:
		for gx in 5:
			if n >= 14:
				break
			var pos := o + Vector2(-700 + gx * 350, -480 + gy * 480)
			if absf(pos.x - o.x) < 200.0 and absf(pos.y - o.y) < 120.0:
				pos.x += 400.0
			var entry: Dictionary
			if n == real:
				entry = MANAGER_LORE
			else:
				entry = {"id": "a4_joke_%d" % (n % JOKES.size()), "title": "MEMO", "tex": "a4_memo", "text": JOKES[n % JOKES.size()], "quick": true}
			_drop_lore(entry, pos)
			n += 1
	game._spawn_enemy("trojan", 4.0, true, o + Vector2(800, 0))


# ---------------- A5: the data center ----------------

## Gives the reward of an egg room (REWARDS). With no id set yet it just announces a placeholder.
func _grant(key: String) -> void:
	var r: Dictionary = REWARDS.get(key, {})
	var w: String = r.get("weapon", "")
	var c: String = r.get("class", "")
	if r.has("title"):
		game.hud.announce("TITLE EARNED: " + r["title"], Global.C_GOLD, true)
	elif w == "" and c == "":
		game.hud.announce("REWARD PLACEHOLDER (%s)" % key.to_upper(), Global.C_GOLD, true)
	else:
		if w != "":
			Meta.unlocks["weapon:" + w] = true
		if c != "":
			Meta.unlocks["class:" + c] = true
		Meta.save()
		game.hud.announce("NEW WEAPON FOUND" if w != "" else "NEW CLASS FOUND", Global.C_GOLD, true)


func _a5_door() -> Vector2:
	return A5_WALL.get_center()


func _update_datacenter(p: Vector2, delta: float) -> void:
	a5_cd = maxf(0.0, a5_cd - delta)
	if a5_state == "idle" and a5_cd <= 0.0 and p.distance_to(A5_RACK) < 105.0:
		a5_seq = []
		var last := -1
		for k in A5_LEN:
			var n := randi() % 4
			while n == last:
				n = randi() % 4
			a5_seq.append(n)
			last = n
		a5_state = "show"
		a5_i = 0
		a5_timer = 1.0
		a5_lit = -1
		game.hud.announce("WATCH THE RACK", Color(0.4, 0.95, 0.85))
	elif a5_state == "show":
		a5_timer -= delta
		if a5_timer <= 0.0:
			if a5_lit >= 0:
				a5_lit = -1
				a5_timer = 0.3
				a5_i += 1
				if a5_i >= a5_seq.size():
					a5_state = "input"
					a5_i = 0
					a5_on_tile = -1
					game.hud.announce("YOUR TURN", Color(0.4, 0.95, 0.85))
			else:
				a5_lit = a5_seq[a5_i]
				a5_timer = 0.6
				Sfx.play("pickup", A5_PITCH[a5_lit], -4.0, 0.0)
	elif a5_state == "input":
		var on := -1
		for i in 4:
			if p.distance_to(A5_TILES[i]) < A5_TILE * 0.5:
				on = i
		if on != a5_on_tile:
			a5_on_tile = on
			if on >= 0:
				a5_lit = on
				a5_timer = 0.35
				if on == a5_seq[a5_i]:
					Sfx.play("pickup", A5_PITCH[on], -4.0, 0.0)
					a5_i += 1
					if a5_i >= a5_seq.size():
						_a5_solved()
				else:
					a5_state = "idle"
					a5_cd = 3.0
					Sfx.play("hit", 0.6, 0.0, 0.0)
					game.hud.announce("WRONG SEQUENCE", Global.C_RED)
		if a5_state == "input" and a5_lit >= 0:
			a5_timer -= delta
			if a5_timer <= 0.0:
				a5_lit = -1
	elif a5_state == "idle" and a5_lit >= 0:
		a5_lit = -1
	if a5_state == "done" and p.distance_to(_a5_door()) < 90.0 and portal_cd <= 0.0:
		_enter_upload()


func _a5_solved() -> void:
	a5_state = "done"
	a5_lit = -1
	game.main_arena.walls.erase(A5_WALL)
	game.main_arena._rebuild_grid()
	game.hud.announce("COLD AISLE UNLOCKED", Global.C_GOLD, true)
	Sfx.play("legendary", 0.9, 0.0, 0.0)
	game.ring(_a5_door(), Global.C_GOLD, 300.0, 0.6, 8.0)


func _enter_upload() -> void:
	rooms.erase("upload_done")
	_enter_side("upload", "upload", 6)
	stream_cd = STREAM_WAVE
	game.hud.announce("DATA UPLOAD: RUN AGAINST THE STREAM", Color(0.4, 0.95, 0.85))


func _update_upload(p: Vector2, delta: float) -> void:
	var pl = game.player
	var lim: Rect2 = room.bounds.grow(-64.0)
	pl.position.x = clampf(pl.position.x - STREAM_PUSH * delta, lim.position.x, lim.end.x)
	var end_x: float = room.bounds.end.x
	var reached: bool = p.x > end_x - 900.0
	if reached and not rooms.has("upload_done"):
		rooms["upload_done"] = true
		game.hud.announce("UPLOAD COMPLETE", Global.C_GOLD, true)
		Sfx.play("pk_cache", 0.8, 0.0, 0.0)
		_drop_lore(A5_LORE, Vector2(end_x - 520.0, room.bounds.get_center().y))
	if reached:
		return
	stream_cd -= delta
	if stream_cd <= 0.0:
		stream_cd = STREAM_WAVE
		var kinds := ["worm", "mite", "spyware", "miner"]
		for k in 4:
			var pos := Vector2(minf(p.x + 760.0 + k * 90.0, end_x - 300.0), room.bounds.get_center().y + (k - 1.5) * 150.0)
			game._spawn_enemy(kinds[k], 2.0, false, pos)


# ---------------- A3: the shop and the peripherals ----------------

func _shop_spots() -> Array:
	var o: Vector2 = room.bounds.get_center()
	var out := []
	for i in 4:
		out.append(o + Vector2(-380 + i * 250, -150))
	return out


func _update_shop(p: Vector2) -> void:
	var spots := _shop_spots()
	for i in 4:
		if p.distance_to(spots[i]) < 80.0 and portal_cd <= 0.0:
			var id: String = PERIPHERALS[i]
			portal_cd = 1.5
			if Meta.lore.has("a3_have_" + id):
				game.hud.announce("ALREADY OWNED", Global.C_CYAN)
			elif Meta.data >= A3_COSTS[id]:
				Meta.data -= A3_COSTS[id]
				Meta.lore["a3_have_" + id] = true
				Meta.save()
				game.hud.announce("BOUGHT: %s. CHECK THE LAPTOP" % id.to_upper(), Global.C_GOLD, true)
				Sfx.play("buy", 1.0, 0.0, 0.0)
			else:
				game.hud.announce("NOT ENOUGH DATA (%d)" % A3_COSTS[id], Global.C_RED)
				Sfx.play("ui_deny", 0.8, 0.0, 0.0)


func _update_laptop(p: Vector2) -> void:
	if portal_cd > 0.0:
		return
	for i in 4:
		if Meta.lore.has("a3_have_" + PERIPHERALS[i]) and p.distance_to(A3_PORTALS[i]) < 90.0:
			_enter_periph(PERIPHERALS[i], i)
			return


func _enter_periph(id: String, i: int) -> void:
	_enter_side("periph_" + id, "periph", 10 + i, "secret/a3_peripheral_wall.png", "secret/a3_peripheral_floor.png")
	game.hud.announce(id.to_upper() + " CONNECTED", Global.C_CYAN)
	if not rooms.has("pdone_" + id):
		var b = BossScript.new()
		b.setup_boss(BossData.SECRET[A3_BOSS[id]], 0, 0.0)
		b.set_meta("secret", true)
		b.position = room.bounds.get_center() + Vector2(700, 0)
		game.enemy_layer.add_child(b)
		periph_boss = b


# ---------------- A6: the satellite uplink ----------------

func _build_battery() -> void:
	bat_tex = TextureRect.new()
	bat_tex.position = Vector2(16, 128)
	bat_tex.custom_minimum_size = Vector2(64, 64)
	bat_tex.size = Vector2(64, 64)
	bat_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(bat_tex)
	bat_label = _label("", 22, Global.C_GOLD)
	bat_label.position = Vector2(86, 148)
	layer.add_child(bat_label)


func _a6_kills() -> int:
	return int(Meta.lore.get("a6_kills", 0))


func _update_sat(p: Vector2, delta: float) -> void:
	if game.kills > a6_seen:
		var add: int = game.kills - a6_seen
		a6_seen = game.kills
		Meta.lore["a6_kills"] = _a6_kills() + add
		a6_save += add
		if a6_save >= 50:
			a6_save = 0
			Meta.save()
	var frac := clampf(float(_a6_kills()) / float(a6_target), 0.0, 1.0)
	if bat_tex != null:
		var full: Texture2D = PixelArt.load_tex("secret/a6_battery.png")
		if full != null:
			var at := AtlasTexture.new()
			at.atlas = full
			at.region = Rect2(mini(int(frac * 4.99), 4) * 16, 0, 16, 16)
			bat_tex.texture = at
		bat_label.text = "UPLINK %d / %d" % [mini(_a6_kills(), a6_target), a6_target]
		bat_tex.visible = not active
		bat_label.visible = not active
	if frac < 1.0:
		return
	if a6_beam_t > 0.0:
		a6_beam_t -= delta
		if p.distance_to(A6_BEAM) < 110.0:
			a6_beam_t = 0.0
			_enter_moon()
		elif a6_beam_t <= 0.0:
			a6_pads = [false, false, false]
			game.hud.announce("BEAM MISSED: PADS RESET", Global.C_RED)
		return
	for i in 3:
		if not a6_pads[i] and p.distance_to(A6_PADS[i]) < 100.0:
			a6_pads[i] = true
			Sfx.play("pickup", 0.8 + i * 0.25, -2.0, 0.0)
			game.hud.announce("PAD %d / 3 ALIGNED" % a6_pads.count(true), Color(0.5, 0.8, 1.0))
	if a6_pads.count(true) == 3:
		a6_beam_t = A6_BEAM_TIME
		game.hud.announce("LASER FIRING: STEP INTO THE BEAM", Global.C_GOLD, true)
		Sfx.play("legendary", 0.7, 0.0, 0.0)
		game.shake(0.8)


func _enter_moon() -> void:
	_enter_side("moon", "moon", 7, "secret/a6_moon_wall.png", "secret/a6_moon_floor.png")
	game.hud.announce("MOON BASE", Color(0.7, 0.8, 1.0))
	a6_wave_cd = 6.0
	if not rooms.has("moon_done"):
		var b = BossScript.new()
		b.setup_boss(BossData.SECRET["alien"], 0, 0.0)
		b.set_meta("secret", true)
		b.position = room.bounds.get_center() + Vector2(900, 0)
		game.enemy_layer.add_child(b)
		a6_boss = b


func _well_centers() -> Array:
	var o: Vector2 = room.bounds.get_center()
	var out := []
	for w in A6_WELLS:
		out.append(o + w)
	return out


func _update_moon(p: Vector2, delta: float) -> void:
	for c in _well_centers():
		var d: float = p.distance_to(c)
		if d < A6_WELL_R and d > 12.0:
			var closeness := 1.0 - d / A6_WELL_R
			game.player.position += (c - p).normalized() * lerpf(110.0, 185.0, closeness) * delta
	if is_instance_valid(a6_boss):
		a6_wave_cd -= delta
		if a6_wave_cd <= 0.0:
			a6_wave_cd = 8.0
			var o: Vector2 = room.bounds.get_center()
			for k in 5:
				game._spawn_enemy("mite", 2.0, false, o + Vector2.from_angle(TAU * k / 5.0) * 900.0)


# ---------------- A7: the mainframe ----------------

func _update_mainframe(p: Vector2, delta: float) -> void:
	a7_cd = maxf(0.0, a7_cd - delta)
	if a7_key_ok and p.distance_to(A7_PORTAL) < 100.0 and portal_cd <= 0.0:
		_enter_hq()
		return
	if a7_cd > 0.0:
		return
	for i in 3:
		if p.distance_to(A7_BOXES[i]) < 90.0 and a7_wires < 3:
			a7_cd = 1.0
			if i == a7_wires:
				a7_wires += 1
				Sfx.play("pickup", 0.8 + i * 0.2, -2.0, 0.0)
				game.hud.announce("WIRE %d / 3 CONNECTED" % a7_wires, Color(0.4, 1.0, 0.6))
			elif i > a7_wires:
				a7_wires = 0
				Sfx.play("ui_deny", 0.8, 0.0, 0.0)
				game.hud.announce("SHORT CIRCUIT: WIRES RESET", Global.C_RED)
			return
	if p.distance_to(A7_KEYPAD) < 110.0 and not a7_key_ok and not pw_box.visible:
		a7_cd = 4.0
		if a7_wires >= 3:
			_open_password("key")
		else:
			game.hud.announce("NO POWER: CONNECT THE WIRES", Global.C_RED)


func _a7_unlock() -> void:
	a7_key_ok = true
	game.hud.announce("ACCESS KEY ACCEPTED: HQ OPEN", Global.C_GOLD, true)
	Sfx.play("legendary", 0.9, 0.0, 0.0)
	game.ring(A7_PORTAL, Global.C_GOLD, 300.0, 0.6, 8.0)


func _enter_hq() -> void:
	_enter_side("hq", "hq", 8)
	game.hud.announce("OVERSEER HQ", Color(0.9, 0.5, 0.3))
	if not rooms.has("hq_lore"):
		rooms["hq_lore"] = true
		_drop_lore(A7_LORE, room.bounds.get_center() + Vector2(-700, 350))
		_grant("a7")


func _hq_portals() -> Array:
	var o: Vector2 = room.bounds.get_center()
	var out := []
	for i in 6:
		out.append(o + Vector2(-950 + i * 380, -350))
	return out


func _update_hq(p: Vector2, delta: float) -> void:
	a7_cd = maxf(0.0, a7_cd - delta)
	var ports := _hq_portals()
	for i in 6:
		if p.distance_to(ports[i]) < 90.0 and portal_cd <= 0.0:
			Meta.selected_device = i   # a fresh START RUN on that device
			Global.change_scene("res://scenes/game.tscn")
			return
	if a7_cd <= 0.0 and game.enemy_layer.get_child_count() < 6:
		a7_cd = 6.0
		game._spawn_enemy("sentry", 3.0, false, room.bounds.get_center() + Vector2(900, randf_range(-400, 400)))


# ---------------- A8: the unobserved room ----------------

func _update_quantum(p: Vector2, delta: float) -> void:
	a8_clock += delta
	a8_msg_cd = maxf(0.0, a8_msg_cd - delta)
	if a8_spot < 0:
		if a8_clock >= A8_AFTER:
			a8_spot = randi() % 4
		return
	if p.distance_to(A8_SPOTS[a8_spot]) > 130.0:
		a8_hold = 0.0
		return
	var seen := false
	for e in game.enemy_layer.get_children():
		var d: Vector2 = (e.global_position - p).abs()
		if d.x < 700.0 and d.y < 420.0:
			seen = true
			break
	if seen:
		if a8_hold > 0.0 and a8_msg_cd <= 0.0:
			a8_msg_cd = 3.0
			game.hud.announce("OBSERVED", Global.C_RED)
		a8_hold = 0.0
		return
	a8_hold += delta
	if a8_hold >= A8_HOLD:
		a8_hold = 0.0
		_enter_unobserved()


func _enter_unobserved() -> void:
	_enter_side("unobserved", "unobserved", 9)
	a8_t = 0.0
	a8_stage = 0


func _update_unobserved(delta: float) -> void:
	a8_t += delta
	if a8_stage == 0 and a8_t > 2.5:
		a8_stage = 1
		game.hud.announce("YOU WERE NOT SUPPOSED TO SEE THIS", Global.C_RED, true)
		Sfx.announce("lucifer_unobserved")
		_drop_lore(A8_LORE, room.bounds.get_center() + Vector2(400, 300))
	if a8_stage == 1 and a8_t > 16.0:
		a8_stage = 2
		game.hud.announce("GET OUT", Global.C_RED, true)
		_leave()


# ---------------- drawing ----------------

func _draw() -> void:
	if game == null:
		return
	if not active:
		if wall_active:
			var tex: Texture2D = PixelArt.load_tex("secret/a1_ice_wall_%d.png" % clampi(stage, 0, 2))
			if tex != null:
				for i in 3:
					draw_texture_rect(tex, Rect2(A1_WALL.position + Vector2(128 * i, 0), Vector2(128, 128)), false)
		elif stage >= CRACKS and room_id == "":
			if shatter > 0.0:
				var s: Texture2D = PixelArt.load_tex("secret/a1_ice_wall_3.png")
				if s != null:
					for i in 3:
						draw_texture_rect(s, Rect2(A1_WALL.position + Vector2(128 * i, 0), Vector2(128, 128)), false, Color(1, 1, 1, shatter * 2.0))
			_draw_portal(_wall_center())
		if office:
			_draw_office()
		if datacenter:
			_draw_datacenter()
		if sat:
			_draw_sat()
		if mainframe:
			_draw_mainframe()
		if quantum:
			_draw_quantum()
		if laptop:
			_draw_laptop()
		if phone and corrupt_i >= 0:
			var ct: Texture2D = PixelArt.load_tex("secret/a2_corrupted_app.png")
			if ct != null:
				var r: Rect2 = app_blocks[corrupt_i]
				var f := int(t * 6.0) % 4
				draw_texture_rect_region(ct, r.grow(-6.0), Rect2(f * 16, 0, 16, 16))
	elif room != null:
		if floor_path != "":
			var ft: Texture2D = PixelArt.load_tex(floor_path)
			if ft != null:
				draw_texture_rect(ft, room.bounds, true)
		if room_id == "freezer":
			_draw_cold(room.bounds)
			if frozen_shown and bosses_left == 0 and thaw_left > 0.0:
				var ids := ["golem", "window"]
				var spots := _spots()
				for i in 2:
					_draw_frozen(ids[i], spots[i])
		if room_id == "upload":
			_draw_stream()
		if room_id == "moon":
			_draw_moon()
		if room_id == "hq":
			_draw_hq()
		if room_id == "unobserved":
			_draw_unobserved()
		if room_id == "app_store":
			_draw_shop()
		_draw_exit()
		for d in lore_drops:
			var li: Texture2D = PixelArt.load_tex("secret/%s.png" % d["entry"]["tex"])
			if li != null:
				draw_texture_rect(li, Rect2(d["pos"] + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)


## The way out: the freezer's portal, or the red close button of an app.
func _draw_office() -> void:
	var pt: Texture2D = PixelArt.load_tex("secret/a4_printer.png")
	if pt != null:
		draw_texture_rect(pt, Rect2(PRINTER_POS - Vector2(48, 48), Vector2(96, 96)), false)
	var dt: Texture2D = PixelArt.load_tex("secret/a4_lounge_door.png")
	if dt != null:
		draw_texture_rect(dt, Rect2(DOOR_POS - Vector2(64, 64), Vector2(128, 128)), false)
	var bt: Texture2D = PixelArt.load_tex("secret/a4_badge.png")
	if bt != null and badge_pos != null:
		draw_texture_rect(bt, Rect2(badge_pos + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)
	var mt: Texture2D = PixelArt.load_tex("secret/a4_memo.png")
	if mt != null:
		for d in main_lore:
			draw_texture_rect(mt, Rect2(d["pos"] + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)


func _draw_datacenter() -> void:
	var rt: Texture2D = PixelArt.load_tex("secret/a5_led_rack.png")
	if rt != null:
		draw_texture_rect_region(rt, Rect2(A5_RACK - Vector2(64, 64), Vector2(128, 128)), Rect2((int(t * 2.0) % 4) * 16, 0, 16, 16))
	var off: Texture2D = PixelArt.load_tex("secret/a5_tile_off.png")
	var on: Texture2D = PixelArt.load_tex("secret/a5_tile_on.png")
	for i in 4:
		var r := Rect2(A5_TILES[i] - Vector2(A5_TILE, A5_TILE) * 0.5, Vector2(A5_TILE, A5_TILE))
		if i == a5_lit and on != null:
			draw_texture_rect_region(on, r, Rect2(64.0 * (int(t * 8.0) % 2), 0, 64, 64))
		elif off != null:
			draw_texture_rect(off, r, false)
	if a5_state == "done" and game.main_arena.walls.has(A5_WALL) == false:
		var dt: Texture2D = PixelArt.load_tex("secret/a5_cold_aisle_door.png")
		if dt != null:
			draw_texture_rect(dt, Rect2(_a5_door() - Vector2(64, 64), Vector2(128, 128)), false)


## The upload hallway's floor: panels of data scrolling toward the start.
func _draw_stream() -> void:
	var tex: Texture2D = PixelArt.load_tex("secret/a5_data_stream.png")
	if tex == null:
		return
	var r: Rect2 = room.bounds
	var cell := 128.0
	var cols := int(r.size.x / cell)
	var rows := int(r.size.y / cell)
	var tick := int(t * 6.0)
	for cx in cols:
		for cy in rows:
			var f := posmod(tick + cx + cy, 4)
			draw_texture_rect_region(tex, Rect2(r.position + Vector2(cx, cy) * cell, Vector2(cell, cell)), Rect2(f * 64, 0, 64, 64))
	draw_rect(r, Color(0.0, 0.1, 0.12, 0.25))


func _icon(path: String, c: Vector2, size: float, region := Rect2()) -> void:
	var tex: Texture2D = PixelArt.load_tex(path)
	if tex == null:
		return
	var r := Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size))
	if region.size.x > 0.0:
		draw_texture_rect_region(tex, r, region)
	else:
		draw_texture_rect(tex, r, false)


func _text(s: String, c: Vector2, size: int, col: Color) -> void:
	draw_string(Global.FONT_BODY, c - Vector2(size * s.length() * 0.25, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_shop() -> void:
	var spots := _shop_spots()
	for i in 4:
		var id: String = PERIPHERALS[i]
		_icon("secret/a3_%s_portal.png" % id, spots[i] + Vector2(0, sin(t * 3.0 + i) * 6.0), 112.0, Rect2(0, 0, 16, 16))
		var owned: bool = Meta.lore.has("a3_have_" + id)
		_text("OWNED" if owned else "%d DATA" % A3_COSTS[id], spots[i] + Vector2(0, 90), 22, Global.C_GOLD)


func _draw_laptop() -> void:
	for i in 4:
		if Meta.lore.has("a3_have_" + PERIPHERALS[i]):
			_icon("secret/a3_%s_portal.png" % PERIPHERALS[i], A3_PORTALS[i], 128.0, Rect2((int(t * 6.0) % 4) * 16, 0, 16, 16))


func _draw_sat() -> void:
	var charged: bool = _a6_kills() >= a6_target
	if not charged:
		return
	for i in 3:
		var tex: Texture2D = PixelArt.load_tex("secret/a6_pad_%s.png" % ("on" if a6_pads[i] else "off"))
		if tex != null:
			var src := Rect2(64.0 * (int(t * 6.0) % 2), 0, 64, 64) if a6_pads[i] else Rect2(0, 0, 64, 64)
			draw_texture_rect_region(tex, Rect2(A6_PADS[i] - Vector2(96, 96), Vector2(192, 192)), src)
	if a6_beam_t > 0.0:
		var bt: Texture2D = PixelArt.load_tex("secret/a6_beam.png")
		if bt != null:
			var f := int(t * 10.0) % 2
			draw_texture_rect_region(bt, Rect2(A6_BEAM + Vector2(-96, -600), Vector2(192, 1200)), Rect2(f * 32, 0, 32, 32))


func _draw_moon() -> void:
	var tex: Texture2D = PixelArt.load_tex("hazards/well.png")
	if tex == null:
		return
	for c in _well_centers():
		draw_texture_rect_region(tex, Rect2(c - Vector2(A6_WELL_R, A6_WELL_R), Vector2(A6_WELL_R, A6_WELL_R) * 2.0), Rect2((int(t * 8.0) % 8) * 64, 0, 64, 64))


func _draw_mainframe() -> void:
	var cols := ["red", "yellow", "blue"]
	for i in 3:
		_icon("secret/a7_junction_box_%s.png" % cols[i], A7_BOXES[i], 96.0)
		if a7_wires > i:
			draw_circle(A7_BOXES[i] + Vector2(0, -64), 8.0, Color(0.4, 1.0, 0.6))
	_icon("secret/a7_keypad.png", A7_KEYPAD, 96.0)
	if a7_key_ok:
		var tex: Texture2D = PixelArt.load_tex("secret/a7_hq_portal.png")
		if tex != null:
			draw_texture_rect_region(tex, Rect2(A7_PORTAL - Vector2(128, 128), Vector2(256, 256)), Rect2((int(t * 6.0) % 4) * 32, 0, 32, 32))


func _draw_hq() -> void:
	var ids := ["fridge", "phone", "laptop", "office", "datacenter", "satellite"]
	var ports := _hq_portals()
	for i in 6:
		_icon("secret/a7_portal_%s.png" % ids[i], ports[i], 160.0, Rect2((int(t * 6.0) % 2) * 16, 0, 16, 16))


func _draw_quantum() -> void:
	if a8_spot < 0:
		return
	var tex: Texture2D = PixelArt.load_tex("secret/a8_glitch_tile.png")
	if tex != null:
		draw_texture_rect_region(tex, Rect2(A8_SPOTS[a8_spot] - Vector2(128, 128), Vector2(256, 256)), Rect2((int(t * 10.0) % 4) * 64, 0, 64, 64))


func _draw_unobserved() -> void:
	var r: Rect2 = room.bounds
	var tex: Texture2D = PixelArt.load_tex("secret/a8_particle_%s.png" % ("a" if int(t * 3.0) % 2 == 0 else "b"))
	if tex != null:
		for i in 40:
			var slot := int(t * 2.0 + i * 0.37)
			var rng := RandomNumberGenerator.new()
			rng.seed = slot * 977 + i * 131
			var pos := r.position + Vector2(rng.randf(), rng.randf()) * r.size
			draw_texture_rect_region(tex, Rect2(pos, Vector2(48, 48)), Rect2((i % 4) * 8, 0, 8, 8))
	var lt: Texture2D = PixelArt.load_tex("secret/a8_lucifer_frame.png")
	if lt != null and a8_t > 2.0:
		var c: Vector2 = r.get_center()
		draw_texture_rect_region(lt, Rect2(c + Vector2(-428, -160), Vector2(256, 320)), Rect2(0, 0, 32, 40), Color(1, 1, 1, clampf((a8_t - 2.0) / 1.5, 0.0, 1.0)))


func _draw_exit() -> void:
	if room_id == "freezer":
		_draw_portal(_exit_pos())
		return
	var tex: Texture2D = PixelArt.load_tex("secret/a2_app_prompt.png")
	if tex != null:
		var s := 8.0
		draw_texture_rect_region(tex, Rect2(_exit_pos() - Vector2(PROMPT_NO.size.x, PROMPT_NO.size.y) * s * 0.5, PROMPT_NO.size * s), PROMPT_NO)


func _draw_portal(c: Vector2) -> void:
	var tex: Texture2D = PixelArt.load_tex("secret/a1_freezer_portal.png")
	if tex == null:
		return
	var f := int(t * 8.0) % 4
	draw_texture_rect_region(tex, Rect2(c - Vector2(64, 64), Vector2(128, 128)), Rect2(f * 32, 0, 32, 32))


func _draw_frozen(id: String, c: Vector2) -> void:
	var tex: Texture2D = PixelArt.load_tex("secret/a1_%s_frozen.png" % ("golem" if id == "golem" else "window"))
	if tex == null:
		return
	var k: float = PixelArt.boss_scale(id, BossData.SECRET[id]["radius"])
	var f := int(t * 2.5) % 2
	var size := Vector2(40, 40) * k
	draw_texture_rect_region(tex, Rect2(c - size * 0.5, size), Rect2(f * 40, 0, 40, 40))


## The freezer's cold look: an icy blue wash over the floor and a frosted rim along the walls of the room.
func _draw_cold(r: Rect2) -> void:
	draw_rect(r, Color(0.35, 0.6, 1.0, 0.24))
	var rim := 220.0
	for i in 6:
		var a := 0.07 * (6 - i) / 6.0
		var w := rim * (i + 1) / 6.0
		draw_rect(Rect2(r.position, Vector2(r.size.x, w)), Color(0.8, 0.95, 1.0, a))
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), Color(0.8, 0.95, 1.0, a))
		draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color(0.8, 0.95, 1.0, a))
		draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), Color(0.8, 0.95, 1.0, a))
