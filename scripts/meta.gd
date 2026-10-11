extends Node
## Autoload: permanent progression. DATA currency, research tree ranks, bosses beaten
## on the current device, and the prestige (device migration) loop.

const TreeData = preload("res://scripts/tree_data.gd")
const Achievements = preload("res://scripts/achievements.gd")
const Challenges = preload("res://scripts/challenges.gd")
const MapsData = preload("res://scripts/maps_data.gd")
const Classes = preload("res://scripts/classes.gd")
const Evolutions = preload("res://scripts/evolutions.gd")
const CodexData = preload("res://scripts/codex_data.gd")
## Weapons not bought with DATA in the ARSENAL tree: where they come from ("challenge:<id>" or "prestige"). Such a weapon's ARSENAL
## node is granted for free (and kept through reformats) once its unlock is earned; only the base weapons are bought.
## Evolved weapons work the same way: their node is granted when the evolution is first found in a run (TreeData, "grant").
## Device tier that must have been cured (ever) before a weapon can be bought, earned or licensed. Weapons not listed (the base weapons FIREWALL, ENCRYPTION KEYS and PING.EXE) have no requirement.
## Weapons you already own stay yours. Classes will use the same rule.
const WEAPON_CURE_REQ := {}   # empty on purpose: every current weapon is a base weapon (Cheng). Add entries like "weapon_id": device_tier for later weapons and classes.
const HARD_HP := 2.0         # hard mode: enemy health, damage, DATA and prestige points
const HARD_DMG := 1.5
const HARD_DATA := 2.0
const SPEED_TIME := 1.6      # speed-run mode: the run clock (spawns, bosses, overtime) runs this much faster
const SPEED_XP := 1.5
## How weapons become available to buy (Cheng's table, docs/PRESTIGE.md section 2): "prestige" = ARCHITECT LICENSE, "secret" = a hidden
## feat (SECRET_WEAPONS), "challenge:<id>" = complete it. Weapons not listed are plain DATA buys. Unlocks only grant permission to buy.
const WEAPON_SOURCE := {"firewall": "prestige", "zap": "secret", "quarantine": "secret", "scanner": "secret", "backdoor": "challenge:incognito"}
## Secret weapons: never hinted in game. "shock_kills" / "freeze_kills" = threats killed under that status this run; "types" = different enemy kinds
## (bosses included) met in the codex, over all runs.
const SECRET_WEAPONS := {
	"zap": {"shock_kills_min": 2000},
	"quarantine": {"freeze_kills_min": 2000},
	"scanner": {"types_min": 10},
}
## How classes become available to buy: "" = always, "prestige" = ARCHITECT LICENSE, "challenge:<id>" = complete it.
const CLASS_SOURCE := {"architect": "prestige", "ghost": "challenge:glass", "analyst": "challenge:laser_only",
	"pacifist": "secret", "railgunner": "secret", "arsonist": "secret", "stormcaller": "secret", "cryomancer": "secret"}
## Secret classes (start with an evolved weapon): found by doing something nobody tells you about. Checked on this run's stats.
const SECRET_CLASSES := {
	"pacifist": {"time_min": 480.0, "bosses_max": 0},                            # reach minute 8 without killing a boss (no evolution needed)
	"railgunner": {"evo": "evo_railgun", "hits_max": 5, "time_min": 360.0},      # evolve it, survive 6 minutes while barely being touched
	"arsonist": {"evo": "evo_inferno", "kills_min": 1500},                     # evolve it and burn through 1500 threats
	"stormcaller": {"evo": "evo_tesla", "combo_min": 50},                      # evolve it and chain a 50 combo
	"cryomancer": {"evo": "evo_blizzard", "time_min": 600.0},                  # evolve it and outlast 10 minutes
}
const SAVE_PATH := "user://kernel_panic_meta.cfg"
const REAL_SAVE_PATH := "user://kernel_panic_meta.real.cfg"   # the real progress, parked while DEV MODE is on

const DEVICES := ["SMART FRIDGE", "SMARTPHONE", "GAMING LAPTOP", "OFFICE SERVER", "DATA CENTER",
	"SATELLITE UPLINK", "MAINFRAME", "QUANTUM CORE"]
const DEVICE_ICONS := ["dev_fridge", "dev_phone", "dev_laptop", "dev_server", "dev_datacenter",
	"dev_satellite", "dev_mainframe", "dev_quantum"]
const MAX_PICKUPS := 150      # most drops on the map at once (lag guard). Past this, new XP merges into the nearest existing gem so no XP is lost; heals, magnets, purges and caches always drop
const RING := 165.0
const BONUS_RANKS := 5          # extra ranks per device cured this cycle on stat nodes (5 to 10 base ranks)
const BONUS_DEVICES_MAX := 8    # devices that count towards the bonus ranks
const BONUS_BLOCK_MULT := 6.0   # every block of 5 bonus ranks costs this much more than the one before
const DEEP_RING_COST := 1.25  # extra price multiplier per research ring beyond ring 3, so late nodes cost much more
const COST_DEPTH_BASE := 2.1   # research price steepness per tree ring (higher = slower progression)
const PALETTES := [Color(0.15, 0.55, 0.65), Color(0.25, 0.45, 0.9), Color(0.6, 0.3, 0.85), Color(0.2, 0.7, 0.35),
	Color(0.85, 0.55, 0.15), Color(0.8, 0.25, 0.35), Color(0.3, 0.8, 0.8), Color(0.85, 0.85, 0.95)]   # floor color per device
const LANE := 108.0
const GRID_X := 310.0   # world distance between grid columns of the ARSENAL and CLASSES maps
const GRID_Y := 150.0   # and between grid rows

var nodes := []
var by_id := {}
var stats := {}

var data := 0.0
var ranks := {}
var prestige := 0
var device_boss := {}   # device index -> bosses defeated there this cycle (map pips; best_boss is the tree gate)
var best_boss := 0     # bosses defeated in a single run on this device (gates the tree)
var devices_cured := 0    # devices cured this cycle; devices 0..devices_cured are playable
var selected_device := 0  # the device the player has chosen to play
var root_keys := 0        # permanent keys earned by reformatting (prestige)
var pp_locked := 0        # part of pp earned since the last reformat: it can only be spent after the next one
var pp := 0               # prestige points: earned by curing devices, spent in the PRESTIGE tree (kept through reformats)
var auto_off := {}        # auto-pick prestige nodes ("autolevel", "autocache") switched off by the player (kept through reformats)
var unlocks := {}         # permanent permissions to buy things ("weapon:zap"); kept through reformats, cleared only by a full wipe
var mode_threat := 0         # THREAT LEVEL 0..THREAT_MAX picked on the map: stronger enemies for more DATA (see run_threat)
var mode_internet := false   # play THE INTERNET (endless, no final boss) on the selected device
var mode_hard := false     # run modes picked on the map (HARD needs the device cured this cycle, the rest once ever; see run_hard / run_speed)
var mode_speed := false
var mode_best := {}        # best uptime per mode key ("normal", "hard", "speed", "hard+speed")
var device_best := {}        # device index -> longest uptime survived there (shown on the map)
var mode_best_cure := {}   # fastest cure (real seconds) per mode key
var evolutions_found := {}   # evolution id -> true once reached in a run (recipe book); permanent
var selected_start := ""     # evolved weapon to start the next run with ("" = default); needs the "start:<id>" unlock
var codex := {}            # "enemy:bug" -> {"kills": n}; present once met in a run (permanent, shown in the CODEX)
var challenges_done := {}  # completed challenge ids (permanent)
var selected_class := ""   # class picked on the map for the next run ("" = none); ignored unless owned
var active_challenge := ""  # challenge picked on the map for the next run ("" = none)
var achieved := {}        # completed achievement ids (permanent, kept through reformats)
var unlock_node := {}     # unlock key -> research node id that grants it (built from the tree)
var cured_tiers := {}     # device tiers ever cured (first cure of a tier pays more prestige points)
var cured: bool:          # is the selected device cured?
	get:
		return selected_device < devices_cured
var lore := {}   # lore snippets found (id -> true), kept through reformats
var lifetime := {"runs": 0, "kills": 0, "data": 0.0, "cured": 0, "bosses": 0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	nodes = TreeData.build()
	for n in nodes:
		n["tree"] = tree_of(n)
		by_id[n["id"]] = n
		for e in n["effects"]:
			if e[0].begins_with("unlock_") and not unlock_node.has("weapon:" + e[0].substr(7)):
				unlock_node["weapon:" + e[0].substr(7)] = n["id"]
	_load()
	for n in nodes:
		if n["kind"] == "core":
			ranks[n["id"]] = 1   # roots are free and always owned
	recompute()
	for w in WEAPON_SOURCE:   # weapons and classes you already own stay yours when their source was added later
		if stat("unlock_" + w) > 0.0:
			unlocks["weapon:" + w] = true
	for c in CLASS_SOURCE:
		if class_owned(c):
			unlocks["class:" + c] = true


# ---------------- tree queries ----------------

## Three separate trees: "system" (research, DATA), "arsenal" (weapons and masteries, DATA), "prestige" (prestige points).
static func tree_of(n: Dictionary) -> String:
	if n["kind"] == "prestige" or n["id"] == "pcore":
		return "prestige"
	if n["branch"] == "arsenal":
		return "arsenal"
	if n["branch"] == "classes":
		return "classes"
	return "system"


## The tree bought with prestige points (do_prestige keeps it).
static func uses_pp(n: Dictionary) -> bool:
	return n["tree"] == "prestige"


## Granted nodes (evolved weapons, challenge weapons) are never bought: they hold one rank while their condition is met,
## which survives every reformat (recompute keeps their ranks in sync).
func is_granted_node(n: Dictionary) -> bool:
	return n.has("grant")


func node_granted(n: Dictionary) -> bool:
	var g: String = n.get("grant", "")
	if g.begins_with("evo:"):
		return evolutions_found.has(g.substr(4))
	if g.begins_with("unlock:"):
		return unlocks.has(g.substr(7))
	return false


## Records an evolution found in a run: its ARSENAL weapon node is granted at once and kept forever.
func discover_evolution(id: String) -> bool:
	if evolutions_found.has(id):
		return false
	evolutions_found[id] = true
	recompute()
	save()
	return true


func tree_nodes(tree: String) -> Array:
	return nodes.filter(func(n): return n["tree"] == tree)


## Prestige-tree price in prestige points: later rings and higher ranks cost more.
## Prestige points are banked when earned but can only be spent after reformatting (do_prestige releases them).
func add_pp(n: int) -> void:
	pp += n
	pp_locked += n


func pp_free() -> int:
	return maxi(0, pp - pp_locked)


func pp_cost(n: Dictionary) -> int:
	var base: float = n.get("pp_base", [2.0, 2.0, 5.0, 9.0][clampi(n["depth"], 0, 3)])
	if n.has("pp_linear"):
		return maxi(1, int(ceil(base + rank(n["id"]) * float(n["pp_linear"]))))
	var growth := 1.3 if n["max"] <= 5 else 1.1
	return maxi(1, int(ceil(base * pow(growth, rank(n["id"])))))


func rank(id: String) -> int:
	return ranks.get(id, 0)


func weapon_req_met(w: String) -> bool:
	return not WEAPON_CURE_REQ.has(w) or cured_tiers.has(WEAPON_CURE_REQ[w])


func weapon_req_text(w: String) -> String:
	return "" if weapon_req_met(w) else "Cure %s first" % device_name(WEAPON_CURE_REQ[w])


func challenge_available(c: Dictionary) -> bool:
	if not trials_available():
		return false   # CHALLENGES are a prestige feature
	if c.has("evo") and not evolutions_found.has(c["evo"]):
		return false   # discover the evolution in a run first
	var r: String = c["reward"]
	return not r.begins_with("weapon:") or weapon_req_met(r.substr(7))


## Owned = its ARSENAL node has a rank, so it can appear in a run. Base weapons are bought each cycle (a reformat resets them);
## evolved and challenge weapons are granted and stay owned.
func weapon_owned(id: String) -> bool:
	return id == "laser" or stat("unlock_" + id) > 0.0


## Available = obtainable: base weapons can always be bought; evolved weapons once found; challenge / license weapons once earned.
func weapon_available(id: String) -> bool:
	if id.begins_with("evo_"):
		return evolutions_found.has(id)
	return not WEAPON_SOURCE.has(id) or unlocks.has("weapon:" + id)


## Short text for the unlock screen: how a locked entry is obtained.
func unlock_hint(key: String) -> String:
	var req := weapon_req_text(key.substr(7))
	return _source_hint(key) + ("   -   " + req.to_upper() if req != "" else "")


func _source_hint(key: String) -> String:
	var src: String = WEAPON_SOURCE.get(key.substr(7), "")
	if src.begins_with("challenge:"):
		var c: Dictionary = Challenges.by_id(src.substr(10))
		return "Complete the %s challenge (%s)" % [c["name"], c["goal_text"].to_lower()]
	if src == "prestige":
		return "Buy the ARCHITECT LICENSE in the PRESTIGE tree"
	if src == "secret":
		return "Locked"
	if unlock_node.has(key):
		return "Research %s in the ARSENAL tree" % by_id[unlock_node[key]]["name"]
	return "Starting weapon" if key == "weapon:laser" else "Locked"


func is_visible(n: Dictionary) -> bool:
	return prestige >= n["prestige"]


func gate_boss(n: Dictionary) -> int:
	var d: int = n["depth"]
	if d >= 6:
		return 3
	if d == 5:
		return 2
	if d == 4:
		return 1
	return 0


func class_owned(id: String) -> bool:
	return id != "" and stat("class_" + id) > 0.0


func class_available(id: String) -> bool:
	return not CLASS_SOURCE.has(id) or unlocks.has("class:" + id)


## Unlocks any secret weapon whose hidden condition this run met. Returns the newly found weapon ids.
func check_secret_weapons(run: Dictionary) -> Array:
	var found := []
	var types := 0
	for k in codex:
		if k.begins_with("enemy:") or k.begins_with("boss:"):
			types += 1
	for id in SECRET_WEAPONS:
		if unlocks.has("weapon:" + id):
			continue
		var r: Dictionary = SECRET_WEAPONS[id]
		if run.get("shock_kills", 0) < r.get("shock_kills_min", 0) or run.get("freeze_kills", 0) < r.get("freeze_kills_min", 0) or types < r.get("types_min", 0):
			continue
		unlocks["weapon:" + id] = true
		found.append(id)
	if not found.is_empty():
		save()
	return found


## Unlocks any secret class whose hidden condition this run met. Returns the newly found classes.
func check_secret_classes(run: Dictionary) -> Array:
	var found := []
	for id in SECRET_CLASSES:
		if unlocks.has("class:" + id):
			continue
		var r: Dictionary = SECRET_CLASSES[id]
		if r.has("evo") and not run.get("evolved", []).has(r["evo"]):
			continue
		if run.get("bosses", 0) > r.get("bosses_max", 99999) or run.get("hits", 0) > r.get("hits_max", 99999) or run.get("time", 0.0) < r.get("time_min", 0.0) \
				or run.get("kills", 0) < r.get("kills_min", 0) or run.get("combo", 0) < r.get("combo_min", 0):
			continue
		unlocks["class:" + id] = true
		found.append(Classes.by_id(id))
	if not found.is_empty():
		save()
	return found


func class_hint(id: String) -> String:
	var src: String = CLASS_SOURCE.get(id, "")
	if src.begins_with("challenge:"):
		if not trials_available():
			return "Locked"   # challenges are not revealed before TRIAL ACCESS
		var c: Dictionary = Challenges.by_id(src.substr(10))
		return "Complete the %s challenge (%s)" % [c["name"], c["goal_text"].to_lower()]
	if src == "prestige":
		return "Buy the %s LICENSE in the PRESTIGE tree (%d PP)" % [id.to_upper(), int(by_id["p_" + id]["pp_base"])]
	return "Research it in the CLASSES tree"


func lock_reason(n: Dictionary) -> String:
	if is_granted_node(n):
		if node_granted(n):
			return ""
		var g: String = n["grant"]
		if g.begins_with("evo:"):
			return "Find this evolution in a run"
		return _source_hint("weapon:" + g.substr(14)) if g.begins_with("unlock:weapon:") else "Locked"
	for e in n["effects"]:   # classes that need a license or a challenge first
		if e[0].begins_with("class_") and not class_available(e[0].substr(6)):
			return "Unlock this class first: " + class_hint(e[0].substr(6))
	for e in n["effects"]:   # weapons can need a device cured first, whatever way they are obtained
		if e[0].begins_with("unlock_") and not unlocks.has("weapon:" + e[0].substr(7)) and not weapon_req_met(e[0].substr(7)):
			return weapon_req_text(e[0].substr(7))
	if n["kind"] == "unlock" and n["tree"] != "prestige":
		for e in n["effects"]:   # weapons that come from a challenge or from prestige points cannot be bought with DATA
			var w: String = e[0].substr(7)
			if WEAPON_SOURCE.has(w) and not unlocks.has("weapon:" + w):
				return _source_hint("weapon:" + w) if WEAPON_SOURCE[w] != "secret" else "Locked"
	if uses_pp(n):
		if n["parent"] != "" and rank(n["parent"]) < 1:
			return "Research %s first" % by_id[n["parent"]]["name"]
		return ""
	if not is_visible(n):
		return "Requires prestige %d" % n["prestige"]
	if n["parent"] != "" and rank(n["parent"]) < by_id[n["parent"]]["max"]:
		return "Max out %s first" % by_id[n["parent"]]["name"]
	var g := gate_boss(n)
	if best_boss < g:
		return "Defeat boss %d on this device" % g
	return ""


## Research tree nodes only appear once the node they hang from is maxed (or they already have ranks). Prestige nodes appear after one rank of their parent.
func node_shown(n: Dictionary) -> bool:
	for e in n["effects"]:   # a secret weapon stays out of the tree until it has been found
		if e[0].begins_with("unlock_") and WEAPON_SOURCE.get(e[0].substr(7), "") == "secret" and not unlocks.has("weapon:" + e[0].substr(7)):
			return false
	for e in n["effects"]:   # a secret class stays out of the tree until it has been found
		if e[0].begins_with("class_") and CLASS_SOURCE.get(e[0].substr(6), "") == "secret" and not class_available(e[0].substr(6)):
			return false
	if String(n.get("grant", "")).begins_with("evo:"):   # an evolved weapon stays secret until it is found in a run
		return node_granted(n)
	if n["parent"] == "" or rank(n["id"]) > 0 or n["kind"] == "core":
		return true
	if not is_visible(n):
		return false
	var p: Dictionary = by_id[n["parent"]]
	return rank(p["id"]) >= (1 if uses_pp(n) else p["max"])


func is_unlocked(n: Dictionary) -> bool:
	return lock_reason(n) == ""


## Extra ranks: stat nodes with 5 to 10 base ranks get +5 per device cured in this cycle (devices_cured resets on a reformat).
func extra_ranks(n: Dictionary) -> int:
	if uses_pp(n) or n["kind"] != "normal" or n["max"] < 5 or n["max"] > 10:
		return 0
	return BONUS_RANKS * mini(devices_cured, BONUS_DEVICES_MAX)


## Research totals that stop mattering past a cap (ability -50%, item -70%, weapon -80%); nodes never offer ranks beyond it.
const STAT_CAPS := {"abilcd": 50.0, "itemcd": 70.0, "cd": 80.0}


func max_rank(n: Dictionary) -> int:
	var m: int = n["max"] + extra_ranks(n)
	for e in n["effects"]:
		if STAT_CAPS.has(e[0]) and e[1] > 0.0:
			m = mini(m, maxi(n["max"], int(ceil(STAT_CAPS[e[0]] / e[1]))))
	return m


func cost(n: Dictionary) -> int:
	if uses_pp(n):
		return pp_cost(n)
	var r := rank(n["id"])
	var base: float = 14.0 * pow(COST_DEPTH_BASE, n["depth"]) * TreeData.KIND_COST[n["kind"]] * pow(DEEP_RING_COST, maxi(0, n["depth"] - 3))
	var growth := 1.5 if n["max"] <= 5 else (1.25 if n["max"] <= 10 else 1.12)
	var unit: float = (float(n["price"]) if n.has("price") else base * float(n.get("cost_mult", 1.0))) * pow(1.6, prestige)   # "price": a fixed first-rank price
	var price: float = unit * pow(growth, r)
	if r >= n["max"]:
		# bonus ranks (from cured devices) come in blocks of 5; each block costs BONUS_BLOCK_MULT times the one before it,
		# starting from the price of the last normal rank, and the ranks inside a block rise a little
		var e: int = r - int(n["max"])
		price = unit * pow(growth, float(n["max"]) - 1.0) * pow(BONUS_BLOCK_MULT, float(e / 5 + 1)) * (1.0 + 0.2 * float(e % 5))
	return int(round(price))


func can_buy(n: Dictionary) -> bool:
	if is_granted_node(n):
		return false   # given, never bought
	if uses_pp(n):
		return is_unlocked(n) and rank(n["id"]) < n["max"] and (Global.dev_money or pp_free() >= pp_cost(n))
	return is_unlocked(n) and rank(n["id"]) < max_rank(n) and (Global.dev_money or data >= cost(n))


func buy(id: String) -> bool:
	var n: Dictionary = by_id[id]
	if not can_buy(n):
		return false
	if Global.dev_money:
		pass   # DEV: INFINITE CURRENCY, nothing is spent
	elif uses_pp(n):
		pp -= pp_cost(n)
	else:
		data -= cost(n)
	ranks[id] = rank(id) + 1
	for e in n["effects"]:
		if e[0].begins_with("permit_"):
			var key: String = e[0].substr(7)   # "permit_class_architect" -> "class:architect"
			var cut := key.find("_")
			unlocks[key.substr(0, cut) + ":" + key.substr(cut + 1)] = true
	recompute()
	save()
	return true


func completion() -> float:
	var have := 0
	var total := 0
	for n in nodes:
		if n["kind"] == "core" or uses_pp(n) or is_granted_node(n) or not is_visible(n):
			continue
		have += rank(n["id"])
		total += max_rank(n)
	return float(have) / maxf(1.0, total)


func can_prestige() -> bool:
	return devices_cured >= 1   # prestige no longer needs a finished tree


func do_prestige() -> void:
	pp_locked = 0   # points earned this cycle become spendable
	prestige += 1
	var kept := {}   # the prestige tree, every free root and every granted weapon (evolutions, challenge weapons) survive a reformat
	for n in nodes:
		if n["kind"] == "core" or (is_granted_node(n) and node_granted(n)):
			kept[n["id"]] = 1
	for id in ranks:
		if by_id.has(id) and uses_pp(by_id[id]):
			kept[id] = ranks[id]
	ranks = kept
	data = 0.0
	best_boss = 0
	device_boss = {}
	devices_cured = 0
	selected_device = 0
	mode_hard = false   # the map modes start off again after a reformat
	mode_speed = false
	mode_threat = 0
	mode_internet = false
	recompute()
	save()


func describe(n: Dictionary, at_rank: int) -> String:
	var s: String = n["desc"]
	var effects: Array = n["effects"]
	for i in effects.size():
		var v: float = effects[i][1] * maxi(at_rank, 1)
		if STAT_CAPS.has(effects[i][0]):
			v = minf(v, STAT_CAPS[effects[i][0]])
		var txt := str(int(v)) if is_equal_approx(v, round(v)) else "%.2f" % v
		if txt.ends_with("0") and txt.contains("."):
			txt = txt.rstrip("0")
		s = s.replace("{%d}" % i, txt)
	return s


const X_ANGLES := {"offense": -135.0, "defense": -45.0, "utility": 45.0, "system": 135.0}   # the main research tree is an X


func branch_angle(branch: String, tree: String) -> float:
	if tree == "arsenal" or tree == "classes":
		return -90.0   # these trees fan out from their core, starting upward (see node_pos)
	if tree == "system" and X_ANGLES.has(branch):
		return X_ANGLES[branch]
	return TreeData.BRANCHES[branch]["angle"]


func node_pos(n: Dictionary) -> Vector2:
	if n["tree"] == "arsenal" or n["tree"] == "classes":
		# every weapon / class is its own little tree on a grid (see TreeData._at)
		return Vector2(float(n["gx"]) * GRID_X, float(n["gy"]) * GRID_Y)
	if n["kind"] == "core":
		return Vector2.ZERO
	var ang := deg_to_rad(branch_angle(n["branch"], n["tree"]))
	var dir := Vector2.from_angle(ang)
	var ring := RING * (2.0 if n["tree"] == "prestige" else 1.35 if n["tree"] == "system" else 1.0)   # the prestige tree has more nodes per ring; the system tree is spread out
	var lane := LANE * (1.7 if n["tree"] == "prestige" else 1.4 if n["tree"] == "system" else 1.0)
	return dir * (n["depth"] * ring + 40.0) + dir.orthogonal() * n["lane"] * lane


# ---------------- stats used by runs ----------------

func recompute() -> void:
	for n in nodes:   # granted nodes follow their condition (found evolution, earned unlock), never a purchase
		if is_granted_node(n):
			if node_granted(n):
				ranks[n["id"]] = 1
			else:
				ranks.erase(n["id"])
	stats = {}
	for n in nodes:
		var r := rank(n["id"])
		if r <= 0:
			continue
		for e in n["effects"]:
			stats[e[0]] = stats.get(e[0], 0.0) + e[1] * r
	for k in STAT_CAPS:
		if stats.has(k):
			stats[k] = minf(stats[k], STAT_CAPS[k])


func stat(key: String) -> float:
	return stats.get(key, 0.0)


func device_hp_mult(d: int) -> float:
	return pow(2.0, d) * ((1.0 + 0.1 * prestige) if d > 0 else 1.0)   # each device is ~2x tougher; the first device is always x1.0


func device_dmg_mult(d: int) -> float:
	return pow(1.8, d) + (0.1 * prestige if d > 0 else 0.0)   # each device hits ~1.8x harder; the first device is always x1.0


func device_data_mult(d: int) -> float:
	return pow(2.0, d)


func device_palette() -> Color:
	if run_internet():
		return Color(0.4, 0.95, 0.85)
	return PALETTES[selected_device % PALETTES.size()]


## Icon id (see icon_art.gd) for a device; later Quantum Core marks reuse the quantum icon.
func device_icon(tier := -1) -> String:
	if tier < 0:
		tier = selected_device
	return DEVICE_ICONS[mini(tier, DEVICE_ICONS.size() - 1)]


func device_name(tier := -1) -> String:
	if tier < 0:
		tier = selected_device
	if tier < DEVICES.size():
		return DEVICES[tier]
	return "QUANTUM CORE MK.%d" % (tier - DEVICES.size() + 2)


func mode_available() -> bool:
	return cured_tiers.has(selected_device)


## HARD needs the selected device cured in this cycle (a reformat locks it again until the device is re-cured).
func hard_available() -> bool:
	return cured


## Features bought with prestige points (hidden until then).
func speed_available() -> bool:
	return mode_available() and stat("feat_speed") > 0.0


## An auto-pick node counts only while it is bought and not switched off in the prestige tree.
func auto_on(key: String) -> bool:
	return stat(key) > 0.0 and not auto_off.get(key, false)


func toggle_auto(key: String) -> void:
	auto_off[key] = not auto_off.get(key, false)
	save()


func trials_available() -> bool:
	return stat("feat_trials") > 0.0


func classes_available() -> bool:
	return true   # the CLASSES tree is always open; each class has its own license or challenge (CLASS_SOURCE)


var _latched := false      # during a run the modes are fixed at its start, so curing mid-run cannot switch them on
var _latch_hard := false
var _latch_speed := false


const THREAT_MAX := 5
const THREAT_HP := 0.20     # per level
const THREAT_DMG := 0.10
const THREAT_SPAWN := 0.12   # per level: more enemies per wave, and waves come faster (the enemy cap still applies)
const THREAT_DATA := 0.15
var _latch_threat := 0

const INTERNET_DATA := 0.8   # DATA multiplier on THE INTERNET (no cure, no prestige points, so it cannot out-farm cured runs)


## THE INTERNET unlocks once the OFFICE SERVER has been cured (cured_tiers survives reformatting, so it stays unlocked).
const INTERNET_DEVICE := 3   # the OFFICE SERVER (device index 3) must have been cured


func internet_available() -> bool:
	return cured_tiers.has(INTERNET_DEVICE)


const INTERNET_TIER := 4   # THE INTERNET has its own fixed difficulty, whatever device is selected


## The difficulty tier of this run's map: the device's own, or the Internet's fixed one.
func run_tier() -> int:
	return INTERNET_TIER if run_internet() else selected_device


var _latch_internet := false


func run_internet() -> bool:
	return _latch_internet if _latched else (mode_internet and internet_available())


func threat_available() -> bool:
	return (mode_available() or internet_available()) and stat("feat_threat") > 0.0


func run_threat() -> int:
	if _latched:
		return _latch_threat
	return clampi(mode_threat, 0, THREAT_MAX) if threat_available() else 0


func latch_modes() -> void:
	_latch_threat = clampi(mode_threat, 0, THREAT_MAX) if threat_available() else 0
	_latch_internet = mode_internet and internet_available()
	_latch_hard = mode_hard and hard_available() and not _latch_internet
	_latch_speed = mode_speed and speed_available() and not _latch_internet
	_latched = true


func unlatch_modes() -> void:
	_latched = false


func run_hard() -> bool:
	return _latch_hard if _latched else (mode_hard and hard_available() and not run_internet())


func run_speed() -> bool:
	return _latch_speed if _latched else (mode_speed and speed_available() and not run_internet())


func mode_key() -> String:
	if run_internet():
		return "internet"
	if run_hard() and run_speed():
		return "hard+speed"
	return "hard" if run_hard() else ("speed" if run_speed() else "normal")


func mode_name() -> String:
	return {"normal": "NORMAL", "hard": "HARD", "speed": "SPEED RUN", "hard+speed": "HARD + SPEED RUN", "internet": "THE INTERNET"}[mode_key()]


## Prestige points double for each mode that is on (x4 with both).
func mode_pp_mult() -> int:
	return (2 if run_hard() else 1) * (2 if run_speed() else 1)


func enemy_hp_mult() -> float:
	return device_hp_mult(run_tier()) * (HARD_HP if run_hard() else 1.0) * (1.0 + THREAT_HP * run_threat())


func enemy_dmg_mult() -> float:
	return device_dmg_mult(run_tier()) * (HARD_DMG if run_hard() else 1.0) * (1.0 + THREAT_DMG * run_threat())


## Returns true if this is the fastest cure so far in the current mode.
func record_cure_time(seconds: float) -> bool:
	var key := mode_key()
	if mode_best_cure.has(key) and seconds >= mode_best_cure[key]:
		return false
	mode_best_cure[key] = seconds
	return true


func data_mult() -> float:
	# research bonus, root-key bonus, and device tier scaling (tree costs scale the same way)
	return (1.0 + stat("data") / 100.0) * pow(1.6, prestige) * device_data_mult(run_tier()) * (HARD_DATA if run_hard() else 1.0) * (INTERNET_DATA if run_internet() else 1.0) * (1.0 + THREAT_DATA * run_threat())


func root_damage_bonus() -> float:
	return 0.0   # root keys were replaced by the infinite ROOT KEY prestige node


## The cure is committed the moment the final boss dies, so dying in overtime cannot lose it.
## Returns the prestige points this cure paid: tier+1 the first time that device is ever cured, 1 after that.
func record_cure() -> int:
	lifetime["cured"] += 1
	var gained := (1 if cured_tiers.has(selected_device) else selected_device + 1) * mode_pp_mult()
	var bonus := stat("pp_bonus") / 100.0   # PRESTIGE HARVEST: whole 100%s are guaranteed extras, the remainder is a chance for one more
	gained += int(bonus) + (1 if randf() < bonus - floorf(bonus) else 0)
	cured_tiers[selected_device] = true
	add_pp(gained)
	if selected_device == devices_cured:
		devices_cured = mini(devices_cured + 1, DEVICES.size())   # curing the newest device unlocks the next one; QUANTUM CORE is the last
	best_boss = maxi(best_boss, 4)
	save()
	return gained


func record_run(earned: float, bosses: int, kills: int) -> void:
	data += earned
	best_boss = maxi(best_boss, bosses)
	device_boss[selected_device] = maxi(int(device_boss.get(selected_device, 0)), bosses)
	lifetime["runs"] += 1
	lifetime["kills"] += kills
	lifetime["data"] += earned
	lifetime["bosses"] += bosses
	save()


## Codex bookkeeping: seen on first spawn, kills counted as they happen (saved when the run ends).
func codex_see(key: String) -> void:
	if not codex.has(key):
		codex[key] = {"kills": 0}
		if key.begins_with("boss:"):
			save()   # a boss name is revealed on the map as soon as it is met, even if the run is abandoned


## Combo triggers: counted per codex key, kept through runs and reformats (saved when the run ends). Status effects count kills instead (codex_kill).
func codex_applied(key: String) -> void:
	codex_see(key)
	codex[key]["applied"] = int(codex[key].get("applied", 0)) + 1


func codex_kill(key: String) -> void:
	codex_see(key)
	codex[key]["kills"] = int(codex[key]["kills"]) + 1


## Marks a challenge complete and pays its reward (prestige points, or permission to buy a weapon). Returns false if it was already done.
func complete_challenge(id: String) -> bool:
	if challenges_done.has(id):
		return false
	var c: Dictionary = Challenges.by_id(id)
	challenges_done[id] = true
	if String(c["reward"]).begins_with("pp:"):
		add_pp(int(String(c["reward"]).substr(3)))
	else:
		unlocks[c["reward"]] = true
	save()
	return true


## Completes any achievement whose condition is now met and pays its prestige points. Returns the newly completed ones.
## Call after lifetime totals change (record_run, record_cure) and with this run's stats (see achievements.gd).
func check_achievements(run := {}) -> Array:
	var done := []
	for a in Achievements.LIST:
		if achieved.has(a["id"]):
			continue
		var met := false
		if a["type"] == "life":
			met = float(lifetime.get(a["stat"], 0)) >= float(a["target"])
		else:
			met = Achievements.run_met(a, run)
		if met:
			achieved[a["id"]] = true
			add_pp(a["pp"])
			done.append(a)
	if not done.is_empty():
		save()
	return done


func affordable_count() -> int:
	var c := 0
	for n in nodes:
		if can_buy(n):
			c += 1
	return c


# ---------------- persistence ----------------

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "data", data)
	cfg.set_value("meta", "ranks", ranks)
	cfg.set_value("meta", "prestige", prestige)
	cfg.set_value("meta", "best_boss", best_boss)
	cfg.set_value("meta", "device_boss", device_boss)
	cfg.set_value("meta", "devices_cured", devices_cured)
	cfg.set_value("meta", "selected_device", selected_device)
	cfg.set_value("meta", "root_keys", root_keys)
	cfg.set_value("meta", "pp", pp)
	cfg.set_value("meta", "pp_locked", pp_locked)
	cfg.set_value("meta", "cured_tiers", cured_tiers)
	cfg.set_value("meta", "unlocks", unlocks)
	cfg.set_value("meta", "achieved", achieved)
	cfg.set_value("meta", "auto_off", auto_off)
	cfg.set_value("meta", "challenges_done", challenges_done)
	cfg.set_value("meta", "codex", codex)
	cfg.set_value("meta", "evolutions_found", evolutions_found)
	cfg.set_value("meta", "evo_tree_merged", true)
	cfg.set_value("meta", "selected_start", selected_start)
	cfg.set_value("meta", "mode_hard", mode_hard)
	cfg.set_value("meta", "mode_internet", mode_internet)
	cfg.set_value("meta", "mode_threat", mode_threat)
	cfg.set_value("meta", "mode_speed", mode_speed)
	cfg.set_value("meta", "mode_best", mode_best)
	cfg.set_value("meta", "mode_best_cure", mode_best_cure)
	cfg.set_value("meta", "device_best", device_best)
	cfg.set_value("meta", "active_challenge", active_challenge)
	cfg.set_value("meta", "selected_class", selected_class)
	cfg.set_value("meta", "lifetime", lifetime)
	cfg.set_value("meta", "lore", lore)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	data = cfg.get_value("meta", "data", 0.0)
	ranks = cfg.get_value("meta", "ranks", {})
	prestige = cfg.get_value("meta", "prestige", 0)
	best_boss = cfg.get_value("meta", "best_boss", 0)
	device_boss = cfg.get_value("meta", "device_boss", {})
	var old_cured: bool = cfg.get_value("meta", "cured", false)   # saves from before multi-device progression
	devices_cured = cfg.get_value("meta", "devices_cured", 1 if old_cured else 0)
	selected_device = cfg.get_value("meta", "selected_device", 0)
	root_keys = cfg.get_value("meta", "root_keys", prestige)
	pp = cfg.get_value("meta", "pp", 0)
	pp_locked = cfg.get_value("meta", "pp_locked", 0)
	cured_tiers = cfg.get_value("meta", "cured_tiers", {})
	unlocks = cfg.get_value("meta", "unlocks", {})
	achieved = cfg.get_value("meta", "achieved", {})
	auto_off = cfg.get_value("meta", "auto_off", {})
	challenges_done = cfg.get_value("meta", "challenges_done", {})
	codex = cfg.get_value("meta", "codex", {})
	evolutions_found = cfg.get_value("meta", "evolutions_found", {})
	if not cfg.get_value("meta", "evo_tree_merged", false):
		_refund_old_evolution_tree()
	selected_start = cfg.get_value("meta", "selected_start", "")
	mode_hard = cfg.get_value("meta", "mode_hard", false)
	mode_internet = cfg.get_value("meta", "mode_internet", false)
	mode_threat = cfg.get_value("meta", "mode_threat", 0)
	mode_speed = cfg.get_value("meta", "mode_speed", false)
	mode_best = cfg.get_value("meta", "mode_best", {})
	mode_best_cure = cfg.get_value("meta", "mode_best_cure", {})
	device_best = cfg.get_value("meta", "device_best", {})
	active_challenge = cfg.get_value("meta", "active_challenge", "")
	selected_class = cfg.get_value("meta", "selected_class", "")
	if not cfg.has_section_key("meta", "cured_tiers"):   # older saves: every device below the frontier was cured once
		for d in devices_cured:
			cured_tiers[d] = true
	lore = cfg.get_value("meta", "lore", {})
	var lt: Dictionary = cfg.get_value("meta", "lifetime", {})
	for k in lt:
		lifetime[k] = lt[k]


## Saves from before the EVOLUTIONS tree was folded into the ARSENAL: the old prestige-point masteries ("a_evo_*", 4 PP base)
## and overdrives ("e_evo_*_od", 12 PP base) are refunded in full and cleared. "a_evo_*" is now the evolved weapon node itself.
func _refund_old_evolution_tree() -> void:
	var refund := 0
	for e in Evolutions.LIST:
		for old in [["a_" + e["id"], 4.0], ["e_" + e["id"] + "_od", 12.0]]:
			for r in int(ranks.get(old[0], 0)):
				refund += maxi(1, int(ceil(float(old[1]) * pow(1.3, r))))
			ranks.erase(old[0])
	pp += refund


## DEV MODE: parks the real save, then fills the working save with everything (all devices cured, every weapon, class and evolution
## unlocked, features bought, a huge DATA and prestige point pile, the whole codex seen). Turning it off puts the real save back,
## so nothing done in dev mode touches real progress.
func set_dev_mode(on: bool) -> void:
	if on == Global.dev_mode:
		return
	Global.dev_mode = on
	Global.save()
	if on:
		save()
		DirAccess.copy_absolute(SAVE_PATH, REAL_SAVE_PATH)
		_fill_everything()
		return
	if FileAccess.file_exists(REAL_SAVE_PATH):
		DirAccess.copy_absolute(REAL_SAVE_PATH, SAVE_PATH)
		DirAccess.remove_absolute(REAL_SAVE_PATH)
		ranks = {}
		_load()
		for n in nodes:
			if n["kind"] == "core":
				ranks[n["id"]] = 1
		recompute()


func _fill_everything() -> void:
	data = 1.0e12
	pp = 99999
	pp_locked = 0
	devices_cured = DEVICES.size()
	selected_device = 0
	for d in DEVICES.size() + 1:
		cured_tiers[d] = true
		device_boss[d] = 3
	best_boss = 4
	for w in ["laser", "firewall", "orbit", "zap", "mines", "scanner", "quarantine", "backdoor"]:
		unlocks["weapon:" + w] = true
	for c in Classes.LIST:
		unlocks["class:" + c["id"]] = true
	for e in Evolutions.LIST:
		evolutions_found[e["id"]] = true
	for n in nodes:   # every node unlocked and maxed (endless nodes stop at 25 ranks)
		prestige = maxi(prestige, int(n.get("prestige", 0)))
	for n in nodes:
		ranks[n["id"]] = mini(max_rank(n), 25)
	for sec in CodexData.SECTIONS + [["HAZARDS", CodexData.hazards()]]:
		for e in sec[1]:
			if not codex.has(e["key"]):
				codex[e["key"]] = {"kills": 99, "applied": 99}
	recompute()
	save()


func reset_all() -> void:
	if FileAccess.file_exists(REAL_SAVE_PATH):
		DirAccess.remove_absolute(REAL_SAVE_PATH)   # a wipe also drops the parked real save and leaves dev mode
	if Global.dev_mode:
		Global.dev_mode = false
		Global.save()
	data = 0.0
	ranks = {}
	for n in nodes:
		if n["kind"] == "core":
			ranks[n["id"]] = 1
	prestige = 0
	best_boss = 0
	device_boss = {}
	devices_cured = 0
	selected_device = 0
	root_keys = 0
	pp = 0
	pp_locked = 0
	cured_tiers = {}
	unlocks = {}
	achieved = {}
	auto_off = {}
	challenges_done = {}
	codex = {}
	evolutions_found = {}
	selected_start = ""
	active_challenge = ""
	selected_class = ""
	mode_hard = false
	mode_internet = false
	mode_threat = 0
	mode_speed = false
	mode_best = {}
	mode_best_cure = {}
	device_best = {}
	lifetime = {"runs": 0, "kills": 0, "data": 0.0, "cured": 0, "bosses": 0}
	recompute()
	save()


## Lore snippets (secret rooms, memos): returns true the first time one is found.
func lore_found(id: String) -> bool:
	if lore.has(id):
		return false
	lore[id] = true
	save()
	return true
