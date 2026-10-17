extends Node
## Autoload: sound effects. Recorded/rendered files in assets/audio/sfx replace the synthesized sounds below; any missing file keeps its in-code version.
## Sounds are built from soft, band-limited waveforms (a few harmonics at most, nothing above 9 kHz)
## with smooth envelopes, and played through a dedicated "SFX" bus that has a gentle low-pass filter and
## a limiter, so loud moments never clip. Only one jingle (level up / epic / legendary / victory) plays
## at a time, and frequently repeated sounds are rate-limited so they are not fatiguing.

const RATE := 44100
# [harmonic number, relative level]. Few, weak harmonics = a soft tone instead of a buzzy one.
const HARMONICS := {
	"sine": [[1, 1.0]],
	"tri": [[1, 1.0], [3, 0.11]],
	"square": [[1, 1.0], [3, 0.30], [5, 0.12]],
	"saw": [[1, 1.0], [2, 0.35], [3, 0.15]],
}
const JINGLES := ["levelup", "epic", "legendary", "legendary_pick", "victory"]
# sounds on the "UI" bus (menus, cards and upgrade jingles); everything else is a gameplay effect on "FX"
const UI_SOUNDS := ["menu_start", "card", "reform", "hover", "select", "tick", "deny", "buy", "levelup", "epic", "legendary", "legendary_pick", "victory"]
## Recorded effects (assets/audio/sfx/<file>.wav) that replace the synthesized sound of the same name.
## "poison", "shock", "burn", "reform" and "boss_final" have no synth version; they are played only when a file exists.
const SAMPLE_DIR := "res://assets/audio/sfx/"
const SAMPLES := {
	"hit": "enemy_hit", "pickup": "pickup", "hurt": "player_hurt", "zap": "laser_zap", "freeze": "freeze",
	"wildfire": "burn", "rail": "sniper_hit", "impact": "heavy_hit", "impact_s": "shotgun_blast", "levelup": "level_up",
	"kill": "enemy_die", "combo": "combo_tier", "ban": "ban", "start_run": "start_run", "boss_defeat": "boss_defeat",
	"burn": "burn", "poison": "poison", "shock": "shock_soft", "frost_pulse": "frost_pulse", "reform": "reform", "boss_final": "boss_lucifer_sting",
	"hz_arc": "hazard_arc", "hz_jam": "hazard_jam", "hz_well": "hazard_well", "hz_flux": "hazard_flux", "hz_flux_slow": "hazard_flux_slow", "hz_frost": "hazard_frost",
	"legendary": "legendary", "legendary_pick": "legendary_pick", "epic": "epic", "buy": "buy",
	"hover": "ui_hover", "select": "ui_select", "tick": "ui_tick", "card": "ui_card", "deny": "ui_deny", "menu_start": "ui_start",
	"shoot": "weapon_packet", "explode": "explosion", "alarm": "alert_siren", "heal": "regen_tick",
	"hz_fan": "hazard_fan", "hz_vent_warn": "hazard_vent_warn", "hz_vent": "hazard_vent", "hz_strike_warn": "hazard_strike_warn", "hz_strike": "hazard_strike",
}
## New per-ability / per-item / pickup sounds (assets/audio/sfx/<name>.wav, same name as the sound), loaded when present.
const EXTRA_SAMPLES := ["ab_restore", "ab_overclock", "ab_lockdown", "ab_phase", "ab_deepscan", "ab_purge", "ab_railstrike", "ab_pause", "ab_wildfire",
	"ab_deepfreeze", "ab_thunderstorm", "ab_super", "thunder_bolt_0", "thunder_bolt_1", "thunder_bolt_2", "it_totem_drop", "it_totem_pulse",
	"it_beacon_drop", "it_decoy_drop", "it_decoy_tick", "it_decoy_blast", "it_backfire", "it_killstreak", "it_flashpoint", "it_shatter", "it_plague",
	"it_rage", "it_drone_shot", "it_striker_dash", "it_guardian_block", "it_collector", "it_chain", "pk_heal", "pk_magnet", "pk_purge", "pk_cache",
	"charge_rail", "charge_rail_s",
	"weapon_firewall", "weapon_keys", "weapon_scanner", "weapon_ping", "weapon_quarantine", "weapon_tesla", "en_spy_shot", "en_sentry_fan", "en_sentry_warp",
	"en_nano_lock", "en_nano_beam", "en_ram_charge", "en_zip_arm", "en_mite_lunge", "en_botnet_dash", "en_rootkit_blink", "en_boss_attack",
	"player_death", "device_cure", "achievement",
	"ice_crack_1", "ice_crack_2", "ice_shatter", "portal_hum", "portal_enter", "portal_exit", "thaw", "lore_found",
	"app_open", "app_close", "app_tick", "pw_deny", "pw_grant", "glitch_wave", "switch_on", "switch_off",
	"spot_enter", "spot_tick", "spot_done", "cp_ok", "cp_bad", "dig_tick", "dig_done", "key_press", "mg_ok", "mg_bad", "shutter", "app_done",
	"piano_0", "piano_1", "piano_2", "piano_3", "piano_4", "piano_5", "printer_feed", "printer_jam",
	"door_unlock", "door_open", "door_close", "locker_open", "badge_get",
	"rack_tone_0", "rack_tone_1", "rack_tone_2", "rack_tone_3", "rack_wrong", "rack_solved", "aisle_open", "stream_warn"]
const SAMPLE_GAIN := {   # per-sound level trim, so every recorded effect lands at a consistent loudness (active RMS, pre-bus): frequent -24 dB, gameplay -22, stings -24..-27, below the ability sounds. Measured offline from the .wav files; re-measure after re-rendering a sound
	"hover": 0.09,
	"tick": 0.09,
	"card": 0.20,
	"select": 0.13,
	"deny": 0.14,
	"menu_start": 0.15,
	"ab_deepfreeze": 0.55,
	"ab_deepscan": 0.44,
	"ab_lockdown": 0.19,
	"ab_overclock": 0.27,
	"ab_pause": 0.63,
	"ab_phase": 0.27,
	"ab_purge": 0.49,
	"ab_railstrike": 0.39,
	"ab_restore": 0.38,
	"ab_super": 0.48,
	"ab_thunderstorm": 0.22,
	"ab_wildfire": 0.27,
	"ban": 0.21,
	"boss_defeat": 0.15,
	"boss_final": 0.55,
	"burn": 1.00,
	"buy": 0.18,
	"spot_enter": 0.32,
	"spot_tick": 0.27,
	"spot_done": 0.27,
	"cp_ok": 0.32,
	"cp_bad": 0.22,
	"dig_tick": 0.27,
	"dig_done": 0.21,
	"key_press": 0.45,
	"mg_ok": 0.27,
	"mg_bad": 0.27,
	"shutter": 0.31,
	"app_done": 0.21,
	"piano_0": 0.43,
	"piano_1": 0.35,
	"piano_2": 0.47,
	"piano_3": 0.31,
	"piano_4": 0.27,
	"piano_5": 0.29,
	"printer_feed": 0.35,
	"printer_jam": 0.37,
	"rack_tone_0": 0.41,
	"rack_tone_1": 0.35,
	"rack_tone_2": 0.41,
	"rack_tone_3": 0.34,
	"rack_wrong": 0.28,
	"rack_solved": 0.2,
	"aisle_open": 0.41,
	"stream_warn": 0.27,
	"door_unlock": 0.41,
	"door_open": 0.51,
	"door_close": 0.25,
	"locker_open": 0.29,
	"badge_get": 0.34,
	"switch_on": 0.43,
	"switch_off": 0.43,
	"app_open": 0.3,
	"app_close": 0.32,
	"app_tick": 0.45,
	"pw_deny": 0.35,
	"pw_grant": 0.26,
	"glitch_wave": 0.2,
	"charge_rail": 0.58,
	"charge_rail_s": 0.53,
	"combo": 0.29,
	"epic": 0.19,
	"freeze": 0.38,
	"frost_pulse": 1.00,
	"hit": 0.36,
	"hurt": 0.23,
	"hz_arc": 0.89,
	"hz_fan": 1.00,
	"hz_flux": 0.68,
	"hz_flux_slow": 0.68,
	"hz_frost": 1.00,
	"hz_jam": 0.81,
	"hz_strike": 0.84,
	"hz_strike_warn": 0.88,
	"hz_vent": 0.92,
	"hz_vent_warn": 0.66,
	"hz_well": 0.56,
	"impact": 0.40,
	"impact_s": 0.56,
	"it_backfire": 0.38,
	"it_beacon_drop": 0.48,
	"it_chain": 0.60,
	"it_collector": 0.33,
	"it_decoy_blast": 0.41,
	"it_decoy_drop": 0.57,
	"it_decoy_tick": 0.32,
	"it_drone_shot": 0.53,
	"it_flashpoint": 0.46,
	"it_guardian_block": 0.60,
	"it_killstreak": 0.47,
	"it_plague": 0.69,
	"it_rage": 0.49,
	"it_shatter": 0.55,
	"it_striker_dash": 0.54,
	"it_totem_drop": 0.52,
	"it_totem_pulse": 0.39,
	"kill": 0.26,
	"legendary": 0.25,
	"legendary_pick": 0.27,
	"levelup": 0.31,
	"pickup": 0.37,
	"pk_cache": 0.44,
	"pk_heal": 0.41,
	"pk_magnet": 0.62,
	"pk_purge": 0.46,
	"poison": 0.36,
	"rail": 0.75,
	"reform": 0.32,
	"shock": 0.79,
	"start_run": 0.51,
	"thunder_bolt_0": 0.35,
	"thunder_bolt_1": 0.41,
	"thunder_bolt_2": 0.37,
	"wildfire": 1.00,
	"zap": 0.26,
	"shoot": 0.25,
	"explode": 0.22,
	"alarm": 0.22,
	"heal": 0.21,
	"weapon_firewall": 0.20,
	"weapon_keys": 0.25,
	"weapon_scanner": 0.22,
	"weapon_ping": 0.24,
	"weapon_quarantine": 0.25,
	"weapon_tesla": 0.32,
	"en_spy_shot": 0.30,
	"en_sentry_fan": 0.22,
	"en_sentry_warp": 0.25,
	"en_nano_lock": 0.09,
	"en_nano_beam": 0.31,
	"en_ram_charge": 0.27,
	"en_zip_arm": 0.17,
	"en_mite_lunge": 0.26,
	"en_botnet_dash": 0.31,
	"en_rootkit_blink": 0.28,
	"en_boss_attack": 0.24,
	"player_death": 0.29,
	"device_cure": 0.23,
	"achievement": 0.27,
}
const MIN_GAPS := {"weapon_keys": 0.12, "weapon_scanner": 0.2, "weapon_firewall": 0.3, "weapon_ping": 0.1, "en_spy_shot": 0.08, "en_mite_lunge": 0.1, "en_botnet_dash": 0.1, "en_sentry_fan": 0.1, "explode": 0.04, "burn": 0.15, "poison": 0.15, "shock": 0.15, "hit": 0.06, "kill": 0.07, "pickup": 0.05, "shoot": 0.06, "zap": 0.08, "hover": 0.05, "tick": 0.03}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var last_play := {}
var sfx_bus := -1   # the shared "SFX" bus: low-pass + limiter, master effects volume
var fx_bus := -1
var ui_bus := -1
var jingle_player: AudioStreamPlayer = null
var jingle_name := ""
var ann_bus := -1   # the "ANN" bus (announcer voice): send Master + limiter, never ducked
var ann_player: AudioStreamPlayer = null
var ann_queue: Array[String] = []
var ann_current := ""
var ann_last_pos := 0.0
var ann_resumes := 0
var duck_db := 0.0   # FX and UI are pulled down by this while an announcement plays


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bus()
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	ann_player = AudioStreamPlayer.new()   # dedicated: the pool above can never steal it
	ann_player.bus = "ANN"
	add_child(ann_player)

	# [[start Hz, end Hz, seconds], ...], waveform, loudness, decay
	streams["shoot"] = _synth([[900.0, 450.0, 0.05]], "tri", 0.20, 5.0)
	# a soft thump with a very short noise tick on top, so hits read as crisp without being hissy
	streams["hit"] = _layer(_synth([[230.0, 110.0, 0.045]], "tri", 0.15, 5.0), _synth([[0.0, 0.0, 0.012]], "click", 0.12, 8.0))
	streams["kill"] = _synth([[520.0, 130.0, 0.12]], "tri", 0.13, 3.0)
	streams["pickup"] = _synth([[700.0, 900.0, 0.06]], "sine", 0.20, 4.0)
	streams["hurt"] = _synth([[240.0, 80.0, 0.22]], "saw", 0.26, 3.0)
	streams["zap"] = _synth([[1500.0, 250.0, 0.1]], "tri", 0.12, 4.0)
	streams["card"] = _synth([[0.0, 0.0, 0.08]], "noise", 0.07, 9.0)
	streams["hover"] = _synth([[800.0, 800.0, 0.03]], "sine", 0.08, 6.0)
	streams["select"] = _synth([[523.0, 523.0, 0.05], [784.0, 784.0, 0.09]], "tri", 0.13, 4.0)
	streams["explode"] = _synth([[0.0, 0.0, 0.55]], "rumble", 0.38, 5.0)
	streams["heal"] = _synth([[523.0, 523.0, 0.06], [784.0, 784.0, 0.06], [1047.0, 1047.0, 0.14]], "tri", 0.2, 3.0)
	streams["tick"] = _synth([[1200.0, 1200.0, 0.02]], "sine", 0.07, 6.0)
	streams["deny"] = _synth([[180.0, 140.0, 0.12]], "tri", 0.12, 3.0)
	streams["buy"] = _synth([[660.0, 660.0, 0.04], [990.0, 990.0, 0.08]], "tri", 0.2, 3.0)
	streams["boss"] = _synth([[110.0, 55.0, 0.5], [110.0, 55.0, 0.5]], "saw", 0.26, 1.5)
	streams["alarm"] = _synth([[698.0, 698.0, 0.12], [523.0, 523.0, 0.12], [698.0, 698.0, 0.12], [523.0, 523.0, 0.12]], "tri", 0.1, 0.5)
	# class abilities: a falling charged whine plus a thump (RAIL STRIKE), a rumble with a rising crackle (WILDFIRE),
	# a bright quick crack (THUNDERSTORM bolt) and a falling icy chime (DEEP FREEZE)
	streams["rail"] = _layer(_synth([[2200.0, 300.0, 0.28]], "tri", 0.16, 3.0), _synth([[0.0, 0.0, 0.3]], "rumble", 0.2, 4.0))
	streams["wildfire"] = _layer(_synth([[0.0, 0.0, 0.5]], "rumble", 0.26, 3.0), _synth([[300.0, 900.0, 0.35]], "tri", 0.08, 3.0))
	streams["thunder"] = _layer(_synth([[2400.0, 200.0, 0.1]], "tri", 0.12, 5.0), _synth([[0.0, 0.0, 0.2]], "rumble", 0.16, 6.0))
	streams["freeze"] = _synth([[1568.0, 1568.0, 0.07], [1319.0, 1319.0, 0.07], [1047.0, 1047.0, 0.07], [784.0, 784.0, 0.25]], "sine", 0.16, 3.0)
	# ability impact: the OOMPF when a cast lands (a deep thump, a noise crack and a bright shimmer), bigger for a SUPER cast.
	streams["impact"] = _layer(_layer(_synth([[150.0, 38.0, 0.38]], "sine", 0.55, 3.5), _synth([[0.0, 0.0, 0.28]], "rumble", 0.34, 6.0)), _synth([[900.0, 300.0, 0.16]], "tri", 0.14, 8.0))
	streams["impact_s"] = _layer(_layer(_synth([[170.0, 30.0, 0.6]], "sine", 0.6, 2.8), _synth([[0.0, 0.0, 0.5]], "rumble", 0.4, 4.0)), _layer(_synth([[1400.0, 400.0, 0.3]], "tri", 0.16, 5.0), _synth([[2093.0, 2093.0, 0.5]], "sine", 0.07, 3.0)))
	# ability charge-ups: one rising sound per windup style, 0.4s (normal) and 0.8s (super, "_s")
	for style in ["rail", "fire", "storm", "ice", "heal", "clock", "lock", "scan"]:
		streams["charge_" + style] = _charge(style, 0.4)
		streams["charge_" + style + "_s"] = _charge(style, 0.8)
	# jingles: lower, shorter and softer than before
	streams["levelup"] = _synth([[523.0, 523.0, 0.07], [659.0, 659.0, 0.07], [784.0, 784.0, 0.07], [1047.0, 1047.0, 0.2]], "tri", 0.14, 2.5)
	streams["epic"] = _synth([[392.0, 392.0, 0.07], [523.0, 523.0, 0.07], [659.0, 659.0, 0.07], [784.0, 784.0, 0.07], [1047.0, 1047.0, 0.28]], "tri", 0.16, 2.0)
	streams["legendary"] = _synth([
		[262.0, 262.0, 0.065], [330.0, 330.0, 0.065], [392.0, 392.0, 0.065], [523.0, 523.0, 0.065],
		[330.0, 330.0, 0.065], [392.0, 392.0, 0.065], [523.0, 523.0, 0.065], [659.0, 659.0, 0.065],
		[523.0, 523.0, 0.065], [659.0, 659.0, 0.065], [784.0, 784.0, 0.065], [1047.0, 1047.0, 0.4]
	], "tri", 0.15, 1.5)
	# the payoff when a Legendary card is PICKED (the "legendary" sting above plays when it is revealed):
	# a short rising fanfare ending on a long, bright held note
	streams["legendary_pick"] = _synth([[784.0, 784.0, 0.08], [1047.0, 1047.0, 0.08], [1319.0, 1319.0, 0.55]], "tri", 0.17, 1.4)
	streams["victory"] = _synth([
		[392.0, 392.0, 0.12], [523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12],
		[659.0, 659.0, 0.12], [784.0, 784.0, 0.12], [1047.0, 1047.0, 0.12], [1319.0, 1319.0, 0.6]
	], "tri", 0.2, 1.2)
	_load_samples()
	apply_volumes()


## Swaps in the recorded files; any that is missing keeps its synthesized version.
func _load_samples() -> void:
	for sound in SAMPLES:
		var path: String = SAMPLE_DIR + SAMPLES[sound] + ".wav"
		if ResourceLoader.exists(path):
			streams[sound] = load(path)
	for sound in EXTRA_SAMPLES:
		var path2: String = SAMPLE_DIR + sound + ".wav"
		if ResourceLoader.exists(path2):
			streams[sound] = load(path2)


## Buses: "FX" (gameplay) and "UI" (interface + upgrades) share the one EFFECTS volume and both feed
## "SFX", which has a gentle low-pass (softens any remaining brightness) and a limiter (no clipping, ever).
## Music has its own bus. Everything ends in "Master", which the VOLUME slider controls.
func _setup_bus() -> void:
	sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		fx_bus = AudioServer.get_bus_index("FX")
		ui_bus = AudioServer.get_bus_index("UI")
		_setup_ann_bus()
		apply_volumes()
		return
	AudioServer.add_bus()
	sfx_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(sfx_bus, "SFX")
	AudioServer.set_bus_send(sfx_bus, "Master")
	for name in ["FX", "UI"]:
		AudioServer.add_bus()
		var b := AudioServer.bus_count - 1
		AudioServer.set_bus_name(b, name)
		AudioServer.set_bus_send(b, "SFX")
	fx_bus = AudioServer.get_bus_index("FX")
	ui_bus = AudioServer.get_bus_index("UI")
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 7000.0
	AudioServer.add_bus_effect(sfx_bus, lowpass)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -2.0
	limiter.threshold_db = -8.0
	AudioServer.add_bus_effect(sfx_bus, limiter)
	_setup_ann_bus()
	apply_volumes()


## "ANN": the announcer voice. Straight to Master with its own limiter, so it is not low-passed or ducked with the effects.
func _setup_ann_bus() -> void:
	ann_bus = AudioServer.get_bus_index("ANN")
	if ann_bus >= 0:
		return
	AudioServer.add_bus()
	ann_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(ann_bus, "ANN")
	AudioServer.set_bus_send(ann_bus, "Master")
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -2.0
	lim.threshold_db = -8.0
	AudioServer.add_bus_effect(ann_bus, lim)


## Push the volume settings to the buses (call after changing any of them).
## VOLUME = Master (music + all effects); EFFECTS = gameplay and menu/upgrade sounds together.
func apply_volumes() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(Global.sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(master, Global.sfx_volume <= 0.001)
	AudioServer.set_bus_volume_db(sfx_bus, -3.0)   # was +3 dB makeup; effects were too loud, so -6 dB overall; the limiter still catches peaks
	var e := linear_to_db(maxf(Global.fx_volume, 0.0001))
	AudioServer.set_bus_volume_db(fx_bus, e + duck_db)
	AudioServer.set_bus_volume_db(ui_bus, e + duck_db)
	if ann_bus >= 0:
		AudioServer.set_bus_volume_db(ann_bus, e)
		AudioServer.set_bus_mute(ann_bus, Global.fx_volume <= 0.001)
	AudioServer.set_bus_mute(fx_bus, Global.fx_volume <= 0.001)
	AudioServer.set_bus_mute(ui_bus, Global.fx_volume <= 0.001)


## A sound that happens somewhere in the world: quieter the farther it is from the player, silent beyond ~1100 px.
func play_at(sound: String, pos: Vector2, pitch := 1.0, volume_db := 0.0, min_gap := 0.03) -> void:
	var near := 1.0
	if Global.game and Global.game.player:
		near = 1.0 - clampf(pos.distance_to(Global.game.player.global_position) / 1100.0, 0.0, 1.0)
	if near <= 0.0:
		return
	play(sound, pitch, volume_db - 14.0 * (1.0 - near), min_gap)


func play(sound: String, pitch := 1.0, volume_db := 0.0, min_gap := 0.03) -> void:
	var is_ui := sound in UI_SOUNDS
	if not streams.has(sound) or Global.sfx_volume <= 0.001 or Global.fx_volume <= 0.001:
		return
	var now := Time.get_ticks_msec() / 1000.0
	# callers that pass 0 want the sound every time (rarity stings); everything else is rate-limited
	var gap := min_gap if min_gap <= 0.0 else maxf(min_gap, MIN_GAPS.get(sound, 0.0))
	if now - last_play.get(sound, -1.0) < gap:
		return
	last_play[sound] = now
	# jingles are never cut off by each other any more: stopping one mid-ring made a click, and the card rarity stings (legendary then epic) chopped each other
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	if sound in JINGLES:
		jingle_player = p
		jingle_name = sound
	p.bus = "UI" if is_ui else "FX"
	p.stream = streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db + (linear_to_db(SAMPLE_GAIN[sound]) if SAMPLE_GAIN.has(sound) else 0.0)
	p.play()


## The announcer's voice lines (assets/audio/announcer/<key>.wav, loaded on first use). Returns false when the file is missing so the caller can fall back to a siren.
## They never touch the effect pool: one dedicated player on the "ANN" bus plays them one at a time from a queue
## (max ANN_MAX_QUEUED waiting, duplicates dropped, "defeated_*" jumps ahead), ducks FX/UI while talking, and resumes a clip that stops early.
const ANNOUNCER_DIR := "res://assets/audio/announcer/"
const ANNOUNCER_GAIN := 0.4   # the voice clips are rendered about 12 dB hotter than the effects
const ANN_MAX_QUEUED := 3
const ANN_DUCK_DB := -10.0
func announce(key: String, delay := 0.0) -> bool:
	var id := "an_" + key
	if not streams.has(id):
		var path := ANNOUNCER_DIR + key + ".wav"
		if not ResourceLoader.exists(path):
			return false
		streams[id] = load(path)
	if delay > 0.0:
		get_tree().create_timer(delay, true, false, true).timeout.connect(_ann_enqueue.bind(key))   # real time: slow motion must not stretch it
	else:
		_ann_enqueue(key)
	return true


func _ann_enqueue(key: String) -> void:
	if Global.sfx_volume <= 0.001 or Global.fx_volume <= 0.001:
		return
	if key == ann_current or ann_queue.has(key):
		return
	if key == "boss_defeated" or key == "boss_enraged" or key.begins_with("defeated_"):
		ann_queue.push_front(key)
	else:
		ann_queue.append(key)
	while ann_queue.size() > ANN_MAX_QUEUED:
		ann_queue.remove_at(_ann_drop_index())
	if ann_current == "":
		_ann_next()


## Oldest waiting line that is not a boss-defeated line.
func _ann_drop_index() -> int:
	for i in ann_queue.size():
		if not (ann_queue[i] == "boss_defeated" or ann_queue[i] == "boss_enraged" or ann_queue[i].begins_with("defeated_")):
			return i
	return ann_queue.size() - 1


func _ann_next() -> void:
	if ann_queue.is_empty():
		ann_current = ""
		duck_db = 0.0
		apply_volumes()
		return
	ann_current = ann_queue.pop_front()
	ann_last_pos = 0.0
	ann_resumes = 0
	ann_player.stream = streams["an_" + ann_current]
	ann_player.pitch_scale = 1.0
	ann_player.volume_db = linear_to_db(ANNOUNCER_GAIN)
	ann_player.play()
	duck_db = ANN_DUCK_DB
	apply_volumes()


func _process(_delta: float) -> void:
	if ann_current == "":
		return
	var length := ann_player.stream.get_length()
	if ann_player.playing:
		ann_last_pos = ann_player.get_playback_position()
	elif ann_last_pos < length - 0.25 and ann_resumes < 5:
		ann_resumes += 1   # stopped before its end (device hiccup, engine stop): carry on where it left off
		ann_player.play(ann_last_pos)
	else:
		_ann_next()


## The charge-up sound for a windup style (see fx/windup.gd), `secs` long. Negative decay = a swell that builds toward the cast.
func _charge(style: String, secs: float) -> AudioStreamWAV:
	match style:
		"rail":   # rising electrical whine over a faint hum
			return _layer(_synth([[300.0, 2600.0, secs]], "tri", 0.14, -1.6), _synth([[90.0, 220.0, secs]], "saw", 0.07, -1.0))
		"fire":   # building heat: a rumble that swells under a climbing growl
			return _layer(_synth([[0.0, 0.0, secs]], "rumble", 0.3, -1.4), _synth([[70.0, 240.0, secs]], "saw", 0.1, -1.0))
		"storm":  # gathering static: crackle ticks over a rising hum
			return _layer(_crackle(secs), _synth([[140.0, 900.0, secs]], "tri", 0.1, -1.4))
		"ice":    # crystallizing: a rising run of chimes
			var notes := [784.0, 988.0, 1175.0, 1319.0, 1568.0, 1976.0, 2349.0, 2637.0]
			var count := 4 if secs < 0.6 else 8
			var chime := []
			for i in count:
				chime.append([notes[i], notes[i], secs / count])
			return _synth(chime, "sine", 0.16, 2.5)
		"heal":   # a warm swelling chord
			return _layer(_synth([[260.0, 520.0, secs]], "sine", 0.18, -1.0), _synth([[390.0, 780.0, secs]], "sine", 0.12, -1.0))
		"clock":  # accelerating ticks
			var ticks := []
			var left2 := secs
			var step := secs * 0.22
			while left2 > 0.02:
				var d := minf(left2, maxf(0.03, step))
				ticks.append([900.0 + (secs - left2) * 1500.0, 900.0 + (secs - left2) * 1500.0, d * 0.4])
				ticks.append([0.0, 0.0, d * 0.6])
				left2 -= d
				step *= 0.72
			return _synth(ticks, "tri", 0.16, 4.0)
		"lock":   # a heavy servo clamp closing: low sweep plus a rumble
			return _layer(_synth([[420.0, 90.0, secs]], "square", 0.1, -0.8), _synth([[0.0, 0.0, secs]], "rumble", 0.16, -1.0))
		"scan":   # radar sweep: a swept sine
			return _synth([[500.0, 1800.0, secs]], "sine", 0.16, -0.8)
	return _synth([[400.0, 1200.0, secs]], "tri", 0.12, -1.0)


## Random crackle of short noise bursts, `secs` long (static for THUNDERSTORM's charge-up).
func _crackle(secs: float) -> AudioStreamWAV:
	var n := int(secs * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var i := 0
	while i < n:
		var gap := int(randf_range(0.012, 0.04) * RATE)
		var burst_len := int(randf_range(0.002, 0.007) * RATE)
		i += gap
		var level := 0.1 + 0.35 * float(i) / n   # the crackle gets denser and louder toward the cast
		for k in burst_len:
			if i + k >= n:
				break
			data.encode_s16((i + k) * 2, int((randf() * 2.0 - 1.0) * level * 32767.0))
		i += burst_len
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Mixes `over` into the start of `base` (both 16-bit mono at RATE).
func _layer(base: AudioStreamWAV, over: AudioStreamWAV) -> AudioStreamWAV:
	var a := base.data
	var b := over.data
	for i in range(0, mini(a.size(), b.size()), 2):
		a.encode_s16(i, clampi(a.decode_s16(i) + b.decode_s16(i), -32768, 32767))
	base.data = a
	return base


func _synth(segments: Array, wave: String, vol: float, decay: float) -> AudioStreamWAV:
	var total := 0
	for seg in segments:
		total += int(seg[2] * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var harm: Array = HARMONICS.get(wave, [])
	var norm := 0.0
	for h in harm:
		norm += h[1]
	var phase := 0.0
	var lp := 0.0
	var pos := 0
	for seg in segments:
		var f0: float = seg[0]
		var f1: float = seg[1]
		var n := int(seg[2] * RATE)
		var attack := minf(0.012 * RATE, n * 0.4)    # smooth start (no click)
		var release := minf(0.010 * RATE, n * 0.4)   # smooth end (no click)
		for i in n:
			var t := float(i) / n
			var f := lerpf(f0, f1, t)
			phase += f / RATE
			var s := 0.0
			if wave == "noise":        # softened noise: low-passed so it is not hissy
				lp += (randf() * 2.0 - 1.0 - lp) * 0.2
				s = lp * 2.6
			elif wave == "click":      # unfiltered noise: only for a few milliseconds of attack on impacts
				s = randf() * 2.0 - 1.0
			elif wave == "rumble":     # low rumble for explosions
				lp += (randf() * 2.0 - 1.0 - lp) * 0.1
				s = lp * 3.1
			else:
				for h in harm:
					if f * h[0] < 9000.0:
						s += h[1] * sin(TAU * h[0] * phase)
				s /= norm
			var env := smoothstep(0.0, attack, float(i)) * smoothstep(0.0, release, float(n - i)) * exp(-decay * t)
			data.encode_s16(pos, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
			pos += 2
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
