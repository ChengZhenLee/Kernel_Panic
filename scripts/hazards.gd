extends Node2D
const FD = preload("res://scripts/fx/fd.gd")
## One environmental hazard per device (THE INTERNET mixes them). Zones only affect the player, never walls: nothing blocks movement.
## Damage is a share of max HP so it scales with any build. Two families:
##   FIXED (frost, jam, arc, fan, well): built into the device. They sit at the same spots, and fans blow the same way, every run,
##     placed from a seed of the device tier across the arena. They never move or vanish.
##   EVENT (vent, strike, flux): pop up at random spots near you, do their thing once, then fade away.
## Types by device tier: 0 frost (slow), 1 jam (slower weapons), 2 vent (telegraphed burst), 3 arc (lightning strikes inside the zone and shocks),
## 4 fan (wind push, each fan its own fixed direction), 5 strike (orbital strikes near you), 6 well (gravity pull), 7 flux (weapons alternate fast and slow).

const PixelArt = preload("res://scripts/pixel_art.gd")
const ArenaScript = preload("res://scripts/arena.gd")
const TYPES := [
	{"id": "frost", "mode": "fixed", "name": "FROST PATCHES", "text": "Cold patches slow you down. They sit in the same spots every run", "color": Color(0.55, 0.85, 1.0), "r": 190.0},
	{"id": "jam", "mode": "fixed", "name": "SIGNAL JAMMERS", "text": "Dead zones slow your weapons to a crawl. They sit in the same spots every run", "color": Color(1.0, 0.35, 0.75), "r": 200.0},
	{"id": "vent", "mode": "event", "name": "HEAT VENTS", "text": "Vents burst open at random near you, erupt once after a warning and set you on fire, then cool off", "color": Color(1.0, 0.5, 0.15), "r": 80.0},
	{"id": "arc", "mode": "fixed", "name": "LIVE WIRES", "text": "Lightning strikes inside the zone and shocks you. The wires sit in the same spots every run", "color": Color(0.95, 0.9, 0.3), "r": 130.0},
	{"id": "fan", "mode": "fixed", "name": "COOLING FANS", "text": "Strong wind pushes you around. Each fan sits in the same spot and blows the same way every run", "color": Color(0.4, 0.9, 0.7), "r": 230.0},
	{"id": "strike", "mode": "event", "name": "ORBITAL STRIKES", "text": "A giant laser beam crashes down at random near you after a warning, then fades", "color": Color(1.0, 0.3, 0.3), "r": 85.0},
	{"id": "well", "mode": "fixed", "name": "GRAVITY WELLS", "text": "Wells drag you hard toward their centre, harder the closer you get. They sit in the same spots every run", "color": Color(0.7, 0.5, 1.0), "r": 360.0},
	{"id": "flux", "mode": "event", "name": "QUANTUM FLUX", "text": "Rifts open at random near you and swing your weapons between fast and slow, then fade away", "color": Color(0.85, 0.9, 1.0), "r": 150.0},
]
## THUNDER STRIKES: a hazard of the smartphone's WEATHER app (not tied to a device). Like an orbital strike, but a bolt of lightning that also shocks.
const THUNDER := {"id": "thunder", "mode": "event", "name": "THUNDER STRIKES", "text": "Dark clouds drop lightning near you: a ring shows the spot, then a bolt lands there after a second. It hurts and shocks anything inside", "color": Color(1.0, 0.9, 0.4), "r": 90.0}
const THUNDER_FRAC := 0.18   # of max HP, plus a shock
## THE INTERNET: fixed zones of every fixed kind are baked into the floor chunk by chunk, and all three event kinds pop up near you.
const MIXED := {"id": "mixed", "mode": "mixed", "name": "MIXED HAZARDS", "text": "Every kind of hazard is scattered across the net, and vents, orbital strikes and flux rifts flare up near you", "color": Color(0.4, 0.95, 0.85), "r": 140.0}
const FIXED_IDS := ["frost", "jam", "arc", "fan", "well"]
## THE INTERNET: how often each fixed kind is picked for a chunk. Frost is drawn heavier because its patches are small and easy to miss.
const NET_FIXED_WEIGHTS := {"frost": 3.0, "jam": 2.0, "arc": 2.0, "fan": 2.0, "well": 2.0}
const AREA_PER_ZONE := 2200000.0   # fixed zones: one per this many px² of arena
const FIXED_MIN := 10
const FIXED_MAX := 28
const START_CLEAR := 520.0         # no fixed zone this close to where you spawn
const NET_CHUNK := 1000.0          # THE INTERNET: one chance of a fixed zone per chunk (same size as the wall chunks)
const NET_CHANCE := 0.35
## Event hazards at threat 0: [spawn gap min, max], max alive, life (s), spawn distance [min, max] from you.
## The minimum distance keeps them from landing right on top of you; EVENT_SPACING keeps them apart from each other.
const EVENTS := {
	"vent": {"gap": [3.0, 4.5], "max": 2, "life": 4.7, "dist": [200.0, 620.0]},
	"flux": {"gap": [6.0, 9.0], "max": 1, "life": 14.0, "dist": [280.0, 660.0]},
	"strike": {"gap": [4.5, 6.5], "max": 2, "life": 3.0, "dist": [170.0, 440.0]},
}
## THE INTERNET runs all three events at once, so each gets a slower gap there (same caps, life and distances).
## Strikes are over in under 2s while vents and rifts linger, so strikes get the shortest gap to be seen about as often.
const NET_EVENT_GAPS := {"vent": [7.0, 10.0], "flux": [12.0, 16.0], "strike": [4.0, 6.0]}
const EVENT_SPACING := 80.0     # extra px between the edges of two live event zones
const EVENT_GAP_THREAT := 0.15  # per threat level: event timers run this much faster (x1.75 at threat 5)
const EVENT_MAX_THREAT := 0.5   # per threat level: extra live events allowed (+2 at threat 5)
const EVENT_R_THREAT := 0.08     # per threat level: event zones grow this much (x1.4 at threat 5)
const EVENT_BURST_EVERY := 3    # every this many threat levels, each spawn drops one more event at once
const ART_R := {"vent": 19.5, "strike": 19.5, "thunder": 28.0}   # radius (page px) of the ring in the vent / strike sheets, drawn at the zone radius
const FADE_IN := 0.35
const FADE_OUT := 0.8
const STRIKE_FADE_OUT := 0.8   # the strike's scorch mark fades over the last stretch of its life (beam at 1.3 s, particles gone by 2.0 s)
const VENT_CYCLE := 4.0
const ARC_CYCLE := 3.0
const BURN_TIME := 3.0
const BURN_TICK := 0.5
const BURN_FRAC := 0.02     # of max HP per tick
const SHOCK_SLOW_TIME := 1.2
const FLUX_PHASE := 4.0   # seconds the rift stays fast, then slow (a full swing is twice this)
const STRIKE_FRAC := 0.4    # orbital laser: massive one-off hit

var kind: Dictionary
var zones := []          # {pos, r, t, hit, id, col, [ang], [life], [chunk]}
var event_timers := {}   # event id -> seconds to the next one
var net_chunks := {}     # THE INTERNET: chunks whose fixed zone (or lack of one) is live
var cd_now := 1.0
var burn_t := 0.0
var burn_tick := 0.0
var shock_t := 0.0
var player


func _ready() -> void:
	z_index = 0   # drawn after the game node but first among its children (see game.gd), so the opaque cached floor never covers it
	player = get_parent().player
	kind = MIXED if get_parent().internet else TYPES[Meta.selected_device % TYPES.size()]
	Meta.codex_see("hazard:" + kind["id"])
	for id in _event_ids():
		event_timers[id] = randf_range(1.0, 2.5)
	if kind["mode"] == "fixed":
		_place_fixed(get_parent().arena)


static func info(tier: int) -> Dictionary:
	return TYPES[tier % TYPES.size()]


static func by_id(id: String) -> Dictionary:
	for h in TYPES:
		if h["id"] == id:
			return h
	return {}


func _event_ids() -> Array:
	if kind["mode"] == "event":
		return [kind["id"]]
	if kind["mode"] == "mixed":
		return ["vent", "flux", "strike"]
	return []


## Lays out the device's fixed zones from a seed of the device tier, so every run of that device gets the same spots and directions.
func _place_fixed(arena) -> void:
	if arena == null or arena.open_cells.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("kp-hazards-%d" % Meta.selected_device)
	var area: float = arena.bounds.size.x * arena.bounds.size.y
	var want := clampi(int(area / AREA_PER_ZONE), FIXED_MIN, FIXED_MAX)
	var cells: Array = arena.open_cells
	for _attempt in 600:
		if zones.size() >= want:
			break
		var cell: Vector2i = cells[rng.randi() % cells.size()]
		var pos: Vector2 = arena.bounds.position + (Vector2(cell) + Vector2(rng.randf(), rng.randf())) * ArenaScript.CELL
		var r: float = kind["r"] * rng.randf_range(0.9, 1.15)
		if pos.distance_to(arena.start) < START_CLEAR + r:
			continue
		var crowded := false
		for z in zones:
			if z["pos"].distance_to(pos) < z["r"] + r + 140.0:
				crowded = true
				break
		if crowded:
			continue
		zones.append(_fixed_zone(kind, pos, r, rng))


func _fixed_zone(k: Dictionary, pos: Vector2, r: float, rng: RandomNumberGenerator) -> Dictionary:
	var z := {"pos": pos, "r": r, "t": rng.randf() * 4.0, "hit": false, "id": k["id"], "col": k["color"]}
	if k["id"] == "fan":   # each fan has its own fixed direction
		z["ang"] = rng.randf() * TAU
	return z


## THE INTERNET: each floor chunk near you gets its fixed zone (or none) from a hash of its coordinates, so places keep their hazards.
func _tick_net_chunks(pp: Vector2) -> void:
	var field = get_parent().arena
	var seed_v: int = field.seed_value if field != null else 0
	var pc := Vector2i(floori(pp.x / NET_CHUNK), floori(pp.y / NET_CHUNK))
	for z in zones.duplicate():
		if z.has("chunk") and (z["chunk"] - pc).length_squared() > 9:
			zones.erase(z)
	for c in net_chunks.keys():
		if (c - pc).length_squared() > 9:
			net_chunks.erase(c)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := pc + Vector2i(dx, dy)
			if net_chunks.has(c):
				continue
			net_chunks[c] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(c.x * 15731 + seed_v, c.y * 789221 - seed_v))
			if rng.randf() > NET_CHANCE:
				continue
			var k: Dictionary = by_id(_net_fixed_pick(rng))
			var pos := (Vector2(c) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))) * NET_CHUNK
			if pos.length() < START_CLEAR or (field != null and not field.is_open(pos)):
				continue
			var z := _fixed_zone(k, pos, k["r"] * rng.randf_range(0.9, 1.15), rng)
			z["chunk"] = c
			zones.append(z)
			Meta.codex_see("hazard:" + k["id"])


## THE INTERNET: a fixed kind for a chunk, weighted by NET_FIXED_WEIGHTS.
static func _net_fixed_pick(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in FIXED_IDS:
		total += NET_FIXED_WEIGHTS[id]
	var roll := rng.randf() * total
	for id in FIXED_IDS:
		roll -= NET_FIXED_WEIGHTS[id]
		if roll < 0.0:
			return id
	return FIXED_IDS[0]


## Event hazards: when its timer runs out, pop one up (more at a higher threat level) at a random spot near you,
## outside the minimum distance and clear of other live events.
func _tick_events(delta: float, pp: Vector2) -> void:
	var threat: int = Meta.run_threat()
	for id in event_timers.keys():
		event_timers[id] -= delta
		if event_timers[id] > 0.0:
			continue
		var ev: Dictionary = EVENTS[id]
		var gap: Array = NET_EVENT_GAPS[id] if kind["mode"] == "mixed" else ev["gap"]
		event_timers[id] = randf_range(gap[0], gap[1]) / (1.0 + EVENT_GAP_THREAT * threat)
		var cap: int = ev["max"] + int(EVENT_MAX_THREAT * threat)
		var alive := 0
		for z in zones:
			if z["id"] == id:
				alive += 1
		var k: Dictionary = by_id(id)
		for _n in mini(1 + floori(float(threat) / EVENT_BURST_EVERY), cap - alive):
			var r: float = (k["r"] if id == "strike" else k["r"] * randf_range(0.9, 1.15)) * (1.0 + EVENT_R_THREAT * threat)
			var sp = _event_spot(pp, r, ev["dist"])
			if sp == null:
				break
			zones.append({"pos": sp, "r": r, "t": 0.0, "hit": false, "id": id, "col": k["color"], "life": ev["life"]})
			Meta.codex_see("hazard:" + id)


## A random open spot in the ring around you that keeps clear of other live event zones, or null if none turns up.
func _event_spot(pp: Vector2, r: float, dist: Array):
	var arena = get_parent().arena
	for _attempt in 10:
		var sp := pp + Vector2.from_angle(randf() * TAU) * randf_range(dist[0], dist[1])
		if arena != null:
			sp = arena.nearest_open(sp)
		if sp.distance_to(pp) < dist[0] * 0.8:   # a wall pushed it back toward you
			continue
		var clear := true
		for z in zones:
			if z.has("life") and z["pos"].distance_to(sp) < z["r"] + r + EVENT_SPACING:
				clear = false
				break
		if clear:
			return sp
	return null


## 0..1 visibility of an event zone (fixed zones are always 1).
static func zone_fade(z: Dictionary) -> float:
	if not z.has("life"):
		return 1.0
	if z["id"] == "strike" or z["id"] == "thunder":
		return clampf((z["life"] - z["t"]) / STRIKE_FADE_OUT, 0.0, 1.0)   # the scorch mark fades after the beam instead of popping out
	return clampf(z["t"] / FADE_IN, 0.0, 1.0) * clampf((z["life"] - z["t"]) / FADE_OUT, 0.0, 1.0)


## A thunder strike at pos (the WEATHER app's storm calls this); it plays out like an orbital strike.
func spawn_thunder(pos: Vector2, r := 90.0) -> void:
	Meta.codex_see("hazard:thunder")
	zones.append({"pos": pos, "r": r, "t": 0.0, "hit": false, "id": "thunder", "col": THUNDER["color"], "life": 2.2})


## Runs the thunder zones only (the other hazards are switched off inside rooms).
func _tick_thunder(delta: float, pp: Vector2) -> void:
	_tick_status(delta)
	for z in zones.duplicate():
		if z["id"] != "thunder":
			continue
		z["t"] += delta
		if z["t"] >= z["life"]:
			zones.erase(z)
			continue
		var d: float = z["pos"].distance_to(pp)
		if z["t"] >= 0.6 and not z.get("warned", false):
			z["warned"] = true
			_snd("hz_strike_warn", d, z, 1.0)
		if z["t"] >= 1.3 and not z["hit"]:
			z["hit"] = true
			_snd("hz_strike", d, z, 1.0)
			if d < z["r"]:
				_hurt(THUNDER_FRAC)
				shock_t = SHOCK_SLOW_TIME
			Global.game.burst(z["pos"], z["col"], 40, 420.0, 6.0, 0.7)
			Global.game.ring(z["pos"], Color(0.7, 0.85, 1.0), z["r"] * 1.4, 0.4, 8.0)
			Global.game.shake(0.3)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(z["pos"]) < z["r"] + e.radius:
					e.take_damage(150.0)


func _process(delta: float) -> void:
	queue_redraw()
	if not player.alive:
		return
	if Global.game and Global.game.time_stop > 0.0:
		return   # PAUSE ability
	if get_parent().in_room:   # no device hazards inside a boss room (the thunder of a secret room's storm still runs)
		_tick_thunder(delta, player.global_position)
		player.hazard_speed = 0.5 if shock_t > 0.0 else 1.0
		player.hazard_push = Vector2.ZERO
		if not is_equal_approx(cd_now, 1.0):
			cd_now = 1.0
			player.hazard_cd = 1.0
			player.recalc()
		return
	var pp: Vector2 = player.global_position
	_tick_status(delta)
	if kind["mode"] == "mixed":
		_tick_net_chunks(pp)
	_tick_events(delta, pp)
	var speed_mult := 1.0
	var cd_mult := 1.0
	var push := Vector2.ZERO
	for z in zones.duplicate():
		z["t"] += delta
		if z.has("life") and z["t"] >= z["life"]:
			zones.erase(z)
			continue
		var d: float = z["pos"].distance_to(pp)
		var inside: bool = d < z["r"]
		if inside and not z.get("was_in", false):   # stepping into a zone makes its sound (the timed ones have their own cues below)
			match String(z["id"]):
				"frost": _snd("hz_frost", d, z, 1.0)
				"jam": _snd("hz_jam", d, z, 1.0)
				"fan": _snd("hz_fan", d, z, 1.0)
				"well": _snd("hz_well", d, z, 1.0)
				"flux": _snd(_flux_sound(z["t"]), d, z, 1.0)
		z["was_in"] = inside
		match String(z["id"]):
			"frost":
				if inside:
					speed_mult = 0.6
			"jam":
				if inside:
					cd_mult = 2.8
			"vent":   # one eruption per vent, then it cools off and fades
				if z["t"] >= 2.4 and not z.get("warned", false):
					z["warned"] = true
					_snd("hz_vent_warn", d, z, 1.0)
				if z["t"] >= 3.2 and not z["hit"]:
					z["hit"] = true
					_snd("hz_vent", d, z, 1.0)
					if inside:
						_hurt(0.06)
						_ignite()
					Global.game.burst(z["pos"], z["col"], 14, 240.0, 4.0, 0.5)
			"arc":
				var on := fmod(z["t"], ARC_CYCLE) < 1.2
				if on:
					if Sfx.streams.has("hz_arc"):   # the recorded multi-zap, once per burst of lightning
						var burst_no := int(z["t"] / ARC_CYCLE)
						if burst_no != z.get("zap_burst", -1):
							z["zap_burst"] = burst_no
							_snd("hz_arc", d, z, 1.0)
					else:   # no file: one synth zap per lightning bolt (a new slot every 1/8 s, two bolts each)
						var slot := int(z["t"] * 8.0)
						if slot != z.get("zap_slot", -1):
							z["zap_slot"] = slot
							var near := 1.0 - clampf((d - z["r"]) / 700.0, 0.0, 1.0)
							if near > 0.0:
								for b in 2:
									Sfx.play("zap", randf_range(0.85, 1.5), -4.0 - 18.0 * (1.0 - near) - 3.0 * b, 0.0)
				if on and inside:
					z["tick"] = z.get("tick", 0.0) + delta
					if z["tick"] >= 0.5:
						z["tick"] = 0.0
						_hurt(0.03)
						_shock()
			"fan":
				if inside:
					push = Vector2.from_angle(z.get("ang", 0.0)) * 120.0
			"well":
				if inside and d > 12.0:
					# a real gravity well: a firm pull at the rim that ramps up toward the core, but always below base walking speed (210) so you can escape
					var closeness := 1.0 - clampf(d / z["r"], 0.0, 1.0)
					push = (z["pos"] - pp).normalized() * lerpf(110.0, 185.0, closeness)
			"flux":
				var phase := int(z["t"] / FLUX_PHASE)
				if inside and phase != z.get("flux_phase", phase):
					_snd(_flux_sound(z["t"]), d, z, 1.0)   # the field flips between fast (rising) and slow (falling) every FLUX_PHASE seconds
				z["flux_phase"] = phase
				if inside and zone_fade(z) > 0.5:
					cd_mult = 0.55 if fmod(z["t"], FLUX_PHASE * 2.0) < FLUX_PHASE else 1.8
			"strike":
				if z["t"] >= 0.6 and not z.get("warned", false):
					z["warned"] = true
					_snd("hz_strike_warn", d, z, 1.0)
				if z["t"] >= 1.3 and not z["hit"]:
					z["hit"] = true
					_snd("hz_strike", d, z, 1.0)
					if inside:
						_hurt(STRIKE_FRAC)
					Global.game.burst(z["pos"], z["col"], 40, 420.0, 6.0, 0.7)
					Global.game.ring(z["pos"], z["col"], z["r"] * 1.4, 0.4, 8.0)
					Global.game.shake(0.2)
					for e in get_tree().get_nodes_in_group("enemies"):   # strikes hurt threats too
						if e.global_position.distance_to(z["pos"]) < z["r"] + e.radius:
							e.take_damage(150.0)
	if shock_t > 0.0:
		speed_mult = minf(speed_mult, 0.5)
	player.hazard_speed = speed_mult
	player.hazard_push = push
	if not is_equal_approx(cd_mult, cd_now):
		cd_now = cd_mult
		player.hazard_cd = cd_mult
		player.recalc()


## Flux cue by phase: the rising sweep while weapons are fast, its reverse (falling) while they are slow.
func _flux_sound(t: float) -> String:
	return "hz_flux" if fmod(t, FLUX_PHASE * 2.0) < FLUX_PHASE else "hz_flux_slow"


## A hazard sound, quieter the farther the zone is from you (silent about 700 px past its edge).
func _snd(sound: String, d: float, z: Dictionary, pitch: float) -> void:
	var near := 1.0 - clampf((d - z["r"]) / 700.0, 0.0, 1.0)
	if near > 0.0:
		Sfx.play(sound, pitch, -3.0 - 18.0 * (1.0 - near), 0.0)


func _ignite() -> void:
	if burn_t <= 0.0 and Global.game:
		Global.game.float_text(player.global_position + Vector2(0, -50), "BURN", Color(1.0, 0.5, 0.1), 22, 0.6)
	burn_t = BURN_TIME


func _shock() -> void:
	if shock_t <= 0.0 and Global.game:
		Global.game.float_text(player.global_position + Vector2(0, -50), "SHOCK", Color(1.0, 0.95, 0.3), 22, 0.6)
	shock_t = SHOCK_SLOW_TIME


func _tick_status(delta: float) -> void:
	shock_t = maxf(0.0, shock_t - delta)
	if burn_t > 0.0:
		burn_t -= delta
		burn_tick += delta
		if burn_tick >= BURN_TICK:
			burn_tick = 0.0
			_hurt(BURN_FRAC)


func _hurt(frac: float) -> void:
	player.take_damage(player.max_hp * frac)


## Sheet frame for the timed zones, so the art plays once on the zone's own clock instead of looping on the sheet's 0.8 s one.
## Flux: 4 green (fast) frames then 4 red (slow) ones, the clock hand stepping once per FLUX_PHASE / 4, same clock as the weapons.
## Vent: 5 idle frames, 2 warning, 1 eruption, held to match the warning (2.3 s) and burst (3.2 s) timings.
func _art_frame(z: Dictionary) -> int:
	return frame_at(String(z["id"]), z["t"])


## Same mapping by hazard id and clock, so the codex plays the timed zones exactly like a run.
static func frame_at(id: String, t: float) -> int:
	match id:
		"flux":
			var cyc := fmod(t, FLUX_PHASE * 2.0)
			var half := 0 if cyc < FLUX_PHASE else 1
			return half * 4 + clampi(int(fmod(cyc, FLUX_PHASE) / FLUX_PHASE * 4.0), 0, 3)
		"vent":   # 24 frames: 0-5 idle loop (10 fps), 6-13 warning over 2.3-3.2 s, 14-23 eruption over 3.2-4.0 s then held
			if t < 2.3:
				return int(t * 10.0) % 6
			if t < 3.2:
				return 6 + clampi(int((t - 2.3) / 0.9 * 8.0), 0, 7)
			return 14 + clampi(int((t - 3.2) / 0.8 * 10.0), 0, 9)
		"arc":   # bolts (frames 0-2, 6-7) while the zone is live, the quiet frames (3-5) between volleys
			var ph := fmod(t, ARC_CYCLE)
			if ph < 1.2:
				return [0, 1, 2, 6, 7][int(ph / 0.12) % 5]
			return 3 + int((ph - 1.2) / 0.6) % 3
		"strike", "thunder":   # 20 frames: 0-11 telegraph over 1.3 s, 12-15 beam impact over 0.25 s, 16-19 crater cooling over 1.55-2.2 s, last frame held while the zone fades out
			if t < 1.3:
				return clampi(int(t / 1.3 * 12.0), 0, 11)
			if t < 1.55:
				return 12 + clampi(int((t - 1.3) / 0.25 * 4.0), 0, 3)
			return 16 + clampi(int((t - 1.55) / 0.65 * 4.0), 0, 3)
	return -1


func _draw() -> void:
	var origin := global_position
	var view := 2400.0   # skip zones far off screen
	for z in zones:
		if z["pos"].distance_to(player.global_position) > view + z["r"] * 2.0:
			continue
		var page: Texture2D = PixelArt.hazard_tex(String(z["id"]))
		if page != null:   # the pixel picture of the zone under the live telegraph / effects
			PixelArt.draw_hazard_zone(self, page, z["pos"] - origin, z["r"], z["t"], 0.85 * zone_fade(z), z.get("ang", 0.0), -1, _art_frame(z), ART_R.get(String(z["id"]), 0.0))
			if z["id"] == "strike":
				draw_strike_beam(self, z["pos"] - origin, z["r"], z["t"], zone_fade(z))
			elif z["id"] == "thunder":
				draw_thunder_bolt(self, z["pos"] - origin, z["r"], z["t"], zone_fade(z))
		else:   # vector fallback only when the art file is missing; with art it is the whole picture
			draw_zone(self, String(z["id"]), z["pos"] - origin, z["r"], z["col"], z["t"], z.get("ang", 0.35), zone_fade(z))


## The orbital laser itself: a thin targeting line from the sky while the reticle locks on, then a tall pixel-edged beam slamming down at 1.3 s.
static func draw_strike_beam(ci: CanvasItem, c: Vector2, r: float, t: float, vis := 1.0, height := 1600.0) -> void:
	var top := c.y - height
	if t < 1.3:
		var u := clampf((t - 0.3) / 1.0, 0.0, 1.0)
		if u > 0.0:
			var w := 2.0 + 4.0 * u
			ci.draw_rect(Rect2(c.x - w * 0.5, top, w, c.y - top), Color(1.0, 0.4, 0.4, (0.1 + 0.3 * u) * vis))
		return
	var f := clampf((t - 1.6) / 0.7, 0.0, 1.0)   # full width for 0.3 s after the hit, then it narrows and fades
	var w := r * 1.7 * (1.0 - 0.7 * f)
	var a := (1.0 - f) * vis
	ci.draw_rect(Rect2(c.x - w * 0.95, top, w * 1.9, c.y - top), Color(1.0, 0.25, 0.25, 0.22 * a))
	ci.draw_rect(Rect2(c.x - w * 0.7, top, w * 1.4, c.y - top), Color(1.0, 0.35, 0.3, 0.4 * a))
	ci.draw_rect(Rect2(c.x - w * 0.5, top, w, c.y - top), Color(1.0, 0.6, 0.5, 0.85 * a))
	ci.draw_rect(Rect2(c.x - w * 0.2, top, w * 0.4, c.y - top), Color(1.0, 1.0, 0.95, a))
	FD.circle(ci, c, w * 0.9, Color(1.0, 0.85, 0.7, 0.55 * a))   # blast glow where it lands


## The bolt of a thunder strike: a faint crackling line from the clouds while the ring closes, then a jagged white-blue bolt at 1.3 s that fades.
static func draw_thunder_bolt(ci: CanvasItem, c: Vector2, r: float, t: float, vis := 1.0, height := 1500.0) -> void:
	var top := c.y - height
	var seed_i := int(t * 14.0)   # the bolt flickers: a new jag pattern a few times a second
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x * 7.0 + c.y * 13.0) + (seed_i if t >= 1.3 else 0)
	var steps := 14
	for i in steps + 1:
		var k := float(i) / steps
		var x := c.x + (rng.randf() - 0.5) * 120.0 * (1.0 - k) * (0.4 if t < 1.3 else 1.0)
		pts.append(Vector2(x if i < steps else c.x, top + (c.y - top) * k))
	if t < 1.3:
		var u := clampf((t - 0.4) / 0.9, 0.0, 1.0)
		if u > 0.0:
			ci.draw_polyline(pts, Color(1.0, 0.95, 0.5, (0.08 + 0.25 * u) * vis), 2.0)
		return
	var f := clampf((t - 1.5) / 0.7, 0.0, 1.0)
	var a := (1.0 - f) * vis
	ci.draw_polyline(pts, Color(0.5, 0.7, 1.0, 0.45 * a), 22.0 * (1.0 - 0.5 * f))
	ci.draw_polyline(pts, Color(0.85, 0.92, 1.0, 0.9 * a), 10.0 * (1.0 - 0.5 * f))
	ci.draw_polyline(pts, Color(1.0, 1.0, 1.0, a), 4.0)
	FD.circle(ci, c, r * 0.8, Color(0.85, 0.92, 1.0, 0.45 * a))


## Draws one zone of a hazard kind (also used by the CODEX page): c = centre, r = radius, t = the zone's clock, vis = 0..1 visibility.
static func draw_zone(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color, t: float, ang := 0.35, vis := 1.0) -> void:
	match id:
		"frost":
			FD.circle(ci, c, r, Color(col, 0.12))
			ci.draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.45), 2.0)
			for i in 6:
				var a := TAU * i / 6.0
				ci.draw_line(c, c + Vector2.from_angle(a) * r * 0.6, Color(col, 0.5), 2.0)
		"jam":
			FD.circle(ci, c, r, Color(col, 0.08))
			ci.draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.4), 2.0)
			for i in 8:
				var y := fmod(t * 60.0 + i * 31.0, r * 2.0) - r
				var half := sqrt(maxf(0.0, r * r - y * y))
				ci.draw_line(c + Vector2(-half, y), c + Vector2(half, y), Color(col, 0.22), 2.0)
		"vent":
			var ph := fmod(t, VENT_CYCLE)
			var warn := clampf((ph - 2.3) / 0.9, 0.0, 1.0)
			FD.circle(ci, c, r, Color(col, (0.08 + 0.3 * warn) * vis))
			ci.draw_arc(c, r, 0.0, TAU, 32, Color(col, (0.5 + 0.5 * warn) * vis), 2.0 + 3.0 * warn)
			if ph >= 3.2:
				FD.circle(ci, c, r * 1.15, Color(1.0, 0.8, 0.3, 0.6 * (1.0 - (ph - 3.2) / 0.8)))
		"arc":
			var on := fmod(t, ARC_CYCLE) < 1.2
			FD.circle(ci, c, r, Color(col, 0.25 if on else 0.05))
			ci.draw_arc(c, r, 0.0, TAU, 32, Color(col, 0.9 if on else 0.3), 3.0 if on else 1.5)
			if on:
				# Lightning strikes down into the zone: a new jagged bolt every ~0.13s, each at its own spot.
				var slot := int(t * 8.0)
				var fade := 1.0 - fmod(t * 8.0, 1.0) * 0.6
				for b in 2:
					var seed_v := float(slot * 2 + b) * 12.9898
					var sx := fmod(absf(sin(seed_v) * 43758.5453), 1.0)
					var sy := fmod(absf(sin(seed_v + 4.1) * 24634.6345), 1.0)
					var bang := sx * TAU
					var dist := sqrt(sy) * r * 0.8
					var ground := c + Vector2.from_angle(bang) * dist
					var top := ground + Vector2(sx * 40.0 - 20.0, -r * 1.3)
					var pts := PackedVector2Array([top])
					for k in range(1, 6):
						var f := k / 6.0
						var jx := (fmod(absf(sin(seed_v + k * 7.7) * 9301.7), 1.0) - 0.5) * 34.0
						pts.append(top.lerp(ground, f) + Vector2(jx, 0.0))
					pts.append(ground)
					ci.draw_polyline(pts, Color(col, 0.35 * fade), 7.0)
					ci.draw_polyline(pts, Color(1.0, 1.0, 0.8, 0.95 * fade), 2.5)
					FD.circle(ci, ground, 14.0 * fade, Color(1.0, 1.0, 0.7, 0.5 * fade))
		"fan":
			FD.circle(ci, c, r, Color(col, 0.07))
			ci.draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.35), 2.0)
			var dir := Vector2.from_angle(ang)
			for i in 5:
				var f := fmod(t * 0.7 + i * 0.2, 1.0)
				var p := c + dir * (f * 2.0 - 1.0) * r * 0.8 + dir.orthogonal() * (i - 2) * r * 0.3
				ci.draw_line(p, p + dir * 26.0, Color(col, 0.5 * (1.0 - f)), 3.0)
		"strike":
			var warn: float = clampf(t / 1.3, 0.0, 1.0)
			FD.circle(ci, c, r, Color(col, 0.08 + 0.22 * warn))
			ci.draw_arc(c, r, 0.0, TAU, 32, Color(col, 0.8), 3.0)
			ci.draw_arc(c, r * warn, 0.0, TAU, 32, Color(1.0, 0.8, 0.6, 0.9), 2.0)
			if t >= 1.3:   # the giant laser beam from the sky
				var f := clampf((t - 1.3) / 0.5, 0.0, 1.0)
				var w := r * 1.1 * (1.0 - f * 0.7)
				var top := c + Vector2(0, -1400.0)
				ci.draw_line(top, c, Color(col, 0.35 * (1.0 - f)), w * 1.6)
				ci.draw_line(top, c, Color(1.0, 0.55, 0.45, 0.8 * (1.0 - f)), w)
				ci.draw_line(top, c, Color(1.0, 1.0, 0.95, 1.0 - f), w * 0.4)
				FD.circle(ci, c, r * (0.6 + f * 0.6), Color(1.0, 0.9, 0.7, 0.7 * (1.0 - f)))
		"well":
			# dark core, glowing accretion disk, spiral arms dragging inward, and rings collapsing toward the centre
			FD.circle(ci, c, r, Color(col, 0.08))
			FD.circle(ci, c, r * 0.6, Color(col, 0.08))
			FD.circle(ci, c, r * 0.3, Color(0.05, 0.0, 0.12, 0.35))
			for i in 5:
				var f := fmod(t * 0.9 + i * 0.2, 1.0)
				ci.draw_arc(c, r * (1.0 - f * f), 0.0, TAU, 48, Color(col, 0.6 * f), 2.0 + 3.0 * f)
			for arm in 4:
				var prev := Vector2.ZERO
				for k in 30:
					var u := k / 29.0
					var arm_ang := arm * TAU / 4.0 - t * 1.6 + u * 3.2
					var rad := r * (1.0 - u) * 0.95
					var q := c + Vector2.from_angle(arm_ang) * rad
					if k > 0:
						ci.draw_line(prev, q, Color(col.lerp(Color.WHITE, u * 0.5), 0.15 + 0.5 * u), 2.0 + 3.0 * u)
					prev = q
			ci.draw_arc(c, 38.0, 0.0, TAU, 32, Color(1.0, 0.85, 1.0, 0.8), 4.0)
			ci.draw_arc(c, 38.0, 0.0, TAU, 32, Color(col, 0.35), 14.0)
			FD.circle(ci, c, 30.0, Color(0.02, 0.0, 0.05, 0.97))
		"flux":
			# fade between the fast (green) and slow (red) tint over ~1 s around each swap instead of snapping
			var cyc := fmod(t, FLUX_PHASE * 2.0)
			var slow_w := clampf((cyc - FLUX_PHASE + 0.5) / 1.0, 0.0, 1.0) if cyc >= FLUX_PHASE - 0.5 else clampf((cyc + 0.5) / 1.0, 0.0, 1.0) * 0.0
			if cyc < 0.5:
				slow_w = 1.0 - clampf((cyc + 0.5) / 1.0, 0.0, 1.0)
			var fc := Color(0.4, 1.0, 0.7).lerp(Color(1.0, 0.45, 0.45), slow_w)
			FD.circle(ci, c, r, Color(fc, 0.1 * vis))
			ci.draw_arc(c, r, 0.0, TAU, 40, Color(fc, 0.6 * vis), 2.5)
			ci.draw_arc(c, r * 0.5, t, t + PI, 20, Color(fc, 0.5 * vis), 2.0)
