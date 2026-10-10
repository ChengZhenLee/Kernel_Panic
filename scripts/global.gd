extends Node
const FD = preload("res://scripts/fx/fd.gd")
## Autoload: shared colors, fonts, theme, settings, CRT overlay and scene fades.

var FONT_BODY: Font = load("res://assets/fonts/VT323-Regular.ttf")
var FONT_TITLE: Font = load("res://assets/fonts/PressStart2P-Regular.ttf")

const C_BG := Color(0.02, 0.02, 0.06)
const C_CYAN := Color(0.25, 1.0, 0.9)
const C_MAGENTA := Color(1.0, 0.25, 0.75)
const C_GREEN := Color(0.35, 1.0, 0.45)
const C_ORANGE := Color(1.0, 0.55, 0.15)
const C_RED := Color(1.0, 0.22, 0.3)
const C_GOLD := Color(1.0, 0.84, 0.25)
const C_PURPLE := Color(0.72, 0.4, 1.0)

const RARITIES := [
	{"name": "COMMON", "color": Color(0.65, 0.85, 0.9), "weight": 70.0, "power": 1.0, "tier": 0},
	{"name": "RARE", "color": Color(0.3, 0.6, 1.0), "weight": 24.0, "power": 1.5, "tier": 1},
	{"name": "EPIC", "color": Color(0.75, 0.38, 1.0), "weight": 5.0, "power": 2.0, "tier": 2},
	{"name": "LEGENDARY", "color": Color(1.0, 0.84, 0.25), "weight": 1.0, "power": 3.0, "tier": 3},
]
## Evolution cards: a red rarity of their own (tier 3, so they pay out like Legendary). Never rolled; game.gd offers a ready evolution
## as the first card with EVO_CHANCE.
const EVOLUTION_RARITY := {"name": "EVOLUTION", "color": Color(1.0, 0.18, 0.2), "weight": 0.0, "power": 3.0, "tier": 3, "evolution": true}
const LUCK_K := 10.0

var sfx_volume := 0.7   # VOLUME: master for everything (music + effects)
var fx_volume := 1.0    # EFFECTS: gameplay sounds and menu / upgrade sounds together
var music_volume := 0.7   # background music
var ui_volume := 1.0    # unused (merged into fx_volume); kept so old saves still load
var screen_shake := true
var crt_enabled := true
var is_mobile := false
const UI_SCALES := [1.0, 1.25, 1.5]   # in-run HUD and control size: small / medium / large
const UI_NAMES := ["SMALL", "MEDIUM", "LARGE"]
var ui_size := 1   # fixed at MEDIUM (the UI SIZE option was removed)
var minimap_on := true       # radar minimap in runs
var damage_numbers := true   # floating damage numbers over hit enemies
var swap_controls := false   # ability button on the left and the joystick on the right
var status_words := true     # floating status combo words (SHATTER, MELTDOWN, TOXIC FLARE)
var dev_mode := false        # DEV: UNLOCK ALL, everything unlocked for testing (see Meta.set_dev_mode; the real save is backed up)
var dev_money := false       # DEV: INFINITE CURRENCY, research costs nothing (works with or without dev_mode)
var seen_help := false       # the How to Play screen opens automatically on the very first launch
var is_touch := false
var joystick_vec := Vector2.ZERO  # written by the on-screen joystick, read by the player
var best_time := 0.0
var best_overtime := 0.0   # longest overtime survived after a final boss (seconds)

var ui_theme: Theme
var game = null  # set by the game scene while it is running

var _crt_rect: ColorRect
var _fade_rect: ColorRect
const SAVE_PATH := "user://kernel_panic.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(C_BG)
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	is_touch = is_mobile or DisplayServer.is_touchscreen_available()
	if is_mobile:
		crt_enabled = false
	_load()
	ui_theme = _build_theme()
	get_tree().root.theme = ui_theme
	apply_menu_scale(ProjectSettings.get_setting("application/run/main_scene"))

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 99
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 100
	add_child(crt_layer)
	_crt_rect = ColorRect.new()
	_crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/crt.gdshader")
	_crt_rect.material = mat
	crt_layer.add_child(_crt_rect)
	_crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt_rect.visible = crt_enabled


func get_ui_scale() -> float:
	return UI_SCALES[ui_size]


## Menus, map, research and How to Play grow with UI SIZE by scaling the whole window's content.
## The run itself stays at x1 (the world must not zoom); its HUD and overlays scale themselves.
func apply_menu_scale(scene_path := "") -> void:
	var in_run := scene_path.ends_with("game.tscn")
	get_tree().root.content_scale_factor = 1.0 if in_run else get_ui_scale()


func set_crt(on: bool) -> void:
	crt_enabled = on
	_crt_rect.visible = on
	save()


func change_scene(path: String) -> void:
	var t := create_tween()
	t.tween_property(_fade_rect, "color:a", 1.0, 0.2)
	await t.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	apply_menu_scale(path)
	var t2 := create_tween()
	t2.tween_property(_fade_rect, "color:a", 0.0, 0.3)


## Android back button / gesture: forwarded to the current scene's on_back().
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var s = get_tree().current_scene
		if s and s.has_method("on_back"):
			s.on_back()


## Margins (in viewport units) that keep UI clear of notches and rounded corners on phones.
func safe_margins() -> Dictionary:
	var m := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not is_mobile:
		return m
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var vp := get_viewport().get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return m
	var k := vp / screen
	m["left"] = safe.position.x * k.x
	m["top"] = safe.position.y * k.y
	m["right"] = (screen.x - safe.end.x) * k.x
	m["bottom"] = (screen.y - safe.end.y) * k.y
	return m


## How much luck has paid off, from 0 (none) towards 1 (never reached). LUCK_K is the luck at which
## it is halfway (+1000% luck): raise it to make luck pay off more slowly.
func luck_curve(luck: float) -> float:
	luck = maxf(luck, 0.0)
	return luck / (luck + LUCK_K)


func roll_rarity(luck := 0.0) -> Dictionary:
	# no hard cap: each rarity's weight slides from its normal weight towards its mirror
	# (common <-> legendary, rare <-> epic) as luck saturates, so max luck is ~70% legendary, never 100%
	var s := luck_curve(luck)
	var total := 0.0
	var weights := []
	for r in RARITIES:
		var mirror: float = RARITIES[RARITIES.size() - 1 - r["tier"]]["weight"]
		var w: float = lerpf(r["weight"], mirror, s)
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in RARITIES.size():
		roll -= weights[i]
		if roll <= 0.0:
			return RARITIES[i]
	return RARITIES[0]


# ---------- drawing helpers used by game objects ----------

func glow_circle(ci: CanvasItem, pos: Vector2, r: float, col: Color, strength := 1.0) -> void:
	FD.circle(ci, pos, r * 2.4, Color(col, 0.05 * strength))
	FD.circle(ci, pos, r * 1.6, Color(col, 0.12 * strength))


const RUN_MINUTES := 12.0   # the final boss arrives here; overtime begins after it

## Overtime scaling (run minutes past RUN_MINUTES). Enemy health compounds and damage ramps up, so runs
## end eventually. DATA rewards stay roughly linear, so overtime can never be the best DATA farm.
func overtime_hp_mult(run_minutes: float) -> float:
	return pow(1.2, maxf(0.0, run_minutes - RUN_MINUTES))


func overtime_dmg_mult(run_minutes: float) -> float:
	var ot := maxf(0.0, run_minutes - RUN_MINUTES)
	return 1.0 + 0.3 * ot + 0.02 * ot * ot


func format_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]


# ---------- settings persistence ----------

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fx_volume", fx_volume)
	cfg.set_value("settings", "ui_volume", ui_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "crt", crt_enabled)
	cfg.set_value("settings", "minimap_on", minimap_on)
	cfg.set_value("settings", "damage_numbers", damage_numbers)
	cfg.set_value("settings", "status_words", status_words)
	cfg.set_value("settings", "swap_controls", swap_controls)
	cfg.set_value("settings", "dev_mode", dev_mode)
	cfg.set_value("settings", "dev_money", dev_money)
	cfg.set_value("settings", "seen_help", seen_help)
	cfg.set_value("stats", "best_time", best_time)
	cfg.set_value("stats", "best_overtime", best_overtime)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	sfx_volume = cfg.get_value("settings", "sfx_volume", sfx_volume)
	fx_volume = cfg.get_value("settings", "fx_volume", fx_volume)
	ui_volume = cfg.get_value("settings", "ui_volume", ui_volume)
	music_volume = cfg.get_value("settings", "music_volume", music_volume)
	screen_shake = cfg.get_value("settings", "screen_shake", screen_shake)
	crt_enabled = false   # the CRT filter is gone for good (ignores old saves)
	minimap_on = cfg.get_value("settings", "minimap_on", true)
	damage_numbers = cfg.get_value("settings", "damage_numbers", true)
	status_words = cfg.get_value("settings", "status_words", true)
	swap_controls = cfg.get_value("settings", "swap_controls", false)
	dev_mode = cfg.get_value("settings", "dev_mode", false)
	dev_money = cfg.get_value("settings", "dev_money", false)
	seen_help = cfg.get_value("settings", "seen_help", false)
	best_time = cfg.get_value("stats", "best_time", 0.0)
	best_overtime = cfg.get_value("stats", "best_overtime", 0.0)


# ---------- UI theme (terminal / neon look) ----------

func make_box(bg: Color, border: Color, border_w := 2, glow := 0, radius := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(border, 0.45)
	sb.shadow_size = glow
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font = FONT_BODY
	th.default_font_size = 28

	th.set_stylebox("normal", "Button", make_box(Color(0.03, 0.06, 0.1, 0.92), Color(C_CYAN, 0.55)))
	th.set_stylebox("hover", "Button", make_box(Color(0.06, 0.2, 0.24, 0.95), C_CYAN, 2, 10))
	th.set_stylebox("focus", "Button", make_box(Color(0.06, 0.2, 0.24, 0.95), C_CYAN, 2, 10))
	th.set_stylebox("pressed", "Button", make_box(Color(C_CYAN, 0.9), C_CYAN, 2, 14))
	th.set_stylebox("disabled", "Button", make_box(Color(0.03, 0.04, 0.06, 0.8), Color(0.3, 0.3, 0.35)))
	th.set_color("font_color", "Button", Color(C_CYAN, 0.85))
	th.set_color("font_hover_color", "Button", Color(0.85, 1.0, 1.0))
	th.set_color("font_focus_color", "Button", Color(0.85, 1.0, 1.0))
	th.set_color("font_pressed_color", "Button", C_BG)
	th.set_color("font_hover_pressed_color", "Button", C_BG)

	th.set_color("font_color", "Label", Color(0.8, 0.95, 1.0))
	var check := StyleBoxFlat.new()
	check.bg_color = Color(0, 0, 0, 0)
	check.content_margin_top = 10
	check.content_margin_bottom = 10
	th.set_stylebox("normal", "CheckButton", check)
	th.set_stylebox("hover", "CheckButton", check)
	th.set_stylebox("pressed", "CheckButton", check)
	th.set_color("font_color", "CheckButton", Color(C_CYAN, 0.85))
	th.set_color("font_hover_color", "CheckButton", Color(0.85, 1.0, 1.0))
	th.set_color("font_focus_color", "CheckButton", Color(0.85, 1.0, 1.0))
	th.set_color("font_pressed_color", "CheckButton", Color(C_CYAN, 0.85))
	th.set_color("font_hover_pressed_color", "CheckButton", Color(0.85, 1.0, 1.0))
	th.set_stylebox("focus", "CheckButton", make_box(Color(0, 0, 0, 0), Color(C_CYAN, 0.6), 1))

	th.set_stylebox("panel", "PanelContainer", make_box(Color(0.02, 0.03, 0.07, 0.95), C_CYAN, 2, 18, 4))

	var bar_bg := make_box(Color(0.02, 0.05, 0.08, 0.9), Color(C_CYAN, 0.5), 1, 0, 2)
	bar_bg.content_margin_top = 0
	bar_bg.content_margin_bottom = 0
	th.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := make_box(C_CYAN, C_CYAN, 0, 8, 2)
	th.set_stylebox("fill", "ProgressBar", bar_fill)

	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(C_CYAN, 0.3)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", slider)
	var grab := StyleBoxFlat.new()
	grab.bg_color = C_CYAN
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	th.set_stylebox("grabber_area", "HSlider", grab)
	th.set_stylebox("grabber_area_highlight", "HSlider", grab)
	return th
