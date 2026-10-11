extends RefCounted
## Research tree definition. Each node:
## id, name, icon, branch, depth (ring), lane (sideways slot), parent, max rank,
## effects [[stat, value per rank]], desc ({0} {1} = effect totals), kind, prestige requirement.

const BRANCHES := {
	"core": {"name": "CORE", "angle": 0.0, "color": Color(0.25, 1.0, 0.9)},
	"offense": {"name": "OFFENSE", "angle": -90.0, "color": Color(1.0, 0.32, 0.38)},
	"defense": {"name": "DEFENSE", "angle": -18.0, "color": Color(0.35, 1.0, 0.45)},
	"utility": {"name": "UTILITY", "angle": 54.0, "color": Color(0.3, 0.75, 1.0)},
	"arsenal": {"name": "ARSENAL", "angle": 126.0, "color": Color(0.78, 0.42, 1.0)},
	"system": {"name": "SYSTEM", "angle": 198.0, "color": Color(1.0, 0.82, 0.25)},
	"classes": {"name": "CLASSES", "angle": -90.0, "color": Color(0.95, 0.55, 0.9)},
}

const KIND_COST := {"core": 0.0, "normal": 1.0, "major": 3.0, "unlock": 2.5, "ult": 6.0, "prestige": 2.0}


static func _n(id: String, name: String, icon: String, branch: String, depth: int, lane: int, parent: String,
		max_rank: int, effects: Array, desc: String, kind := "normal", prestige := 0) -> Dictionary:
	return {"id": id, "name": name, "icon": icon, "branch": branch, "depth": depth, "lane": lane,
		"parent": parent, "max": max_rank, "effects": effects, "desc": desc, "kind": kind, "prestige": prestige}


## Places a node on the map of the ARSENAL or CLASSES tree: every weapon and class is its own little tree, laid out on a grid
## (gx steps sideways, gy steps down, see Meta.node_pos).
static func _at(n: Dictionary, gx: float, gy: float) -> void:
	n["gx"] = gx
	n["gy"] = gy


## Fixed first-rank DATA prices of weapons with an unlock source (docs/PRESTIGE.md section 2); the others use the tree price.
const WEAPON_PRICE := {"firewall": 1000.0, "zap": 2000.0, "quarantine": 2000.0, "scanner": 1500.0, "backdoor": 3000.0}

static func build() -> Array:
	var N := []
	N.append(_n("core", "KERNEL ACCESS", "core", "core", 0, 0, "", 1, [], "Your foothold inside the infected system.", "core"))

	# ---------------- OFFENSE ----------------
	N.append(_n("o_dmg1", "ROOT ACCESS", "might", "offense", 1, 0, "core", 5, [["dmg", 4]], "+{0}% damage"))
	N.append(_n("o_crit1", "EXPLOIT DATABASE", "crit", "offense", 2, -1, "o_dmg1", 5, [["crit", 1.5]], "+{0}% critical hit chance"))
	N.append(_n("o_cd1", "MULTITHREADING", "haste", "offense", 2, 1, "o_dmg1", 5, [["cd", 2]], "-{0}% weapon cooldowns"))
	N.append(_n("o_critdmg1", "ZERO-DAY", "critdmg", "offense", 3, -2, "o_crit1", 5, [["critdmg", 10]], "+{0}% critical damage"))
	N.append(_n("o_dmg2", "PRIVILEGE ESCALATION", "might", "offense", 3, 0, "o_dmg1", 5, [["dmg", 5]], "+{0}% damage"))
	N.append(_n("o_area1", "BROADCAST STORM", "area", "offense", 3, 2, "o_cd1", 5, [["area", 4]], "+{0}% weapon area"))
	N.append(_n("o_proj", "PACKET FLOOD", "proj", "offense", 4, -2, "o_critdmg1", 2, [["proj", 1]], "+{0} projectile count", "major"))
	N.append(_n("o_pierce", "DEEP INSPECTION", "pierce", "offense", 4, -1, "o_dmg2", 3, [["pierce", 1]], "Bolts pierce {0} more threats", "major"))
	N.append(_n("o_boss", "THREAT HUNTER", "boss", "offense", 4, 1, "o_dmg2", 5, [["bossdmg", 8]], "+{0}% damage to elites and bosses"))
	N.append(_n("o_cd2", "HYPERTHREADING", "haste", "offense", 4, 2, "o_area1", 5, [["cd", 2]], "-{0}% weapon cooldowns"))
	N.append(_n("o_crit2", "KERNEL EXPLOIT", "crit", "offense", 5, -1, "o_pierce", 5, [["crit", 1.5]], "+{0}% critical hit chance"))
	N.append(_n("o_dmg3", "GOD MODE", "might", "offense", 5, 0, "o_boss", 10, [["dmg", 4]], "+{0}% damage"))
	N.append(_n("o_area2", "AMPLIFIER", "area", "offense", 5, 1, "o_cd2", 5, [["area", 5]], "+{0}% weapon area"))
	N.append(_n("o_ult", "OVERKILL", "critdmg", "offense", 6, 0, "o_dmg3", 1, [["dmg", 15], ["critdmg", 25]], "+{0}% damage and +{1}% critical damage", "ult"))

	# stats added after the first tree: knockback, projectile speed and status effects
	N.append(_n("o_kb", "KINETIC IMPACT", "knockback", "offense", 4, 0, "o_dmg2", 5, [["knockback", 4]], "+{0}% knockback"))
	N.append(_n("o_pspeed", "THROUGHPUT BOOST", "projspeed", "offense", 5, -2, "o_proj", 5, [["projspeed", 5]], "+{0}% projectile speed"))
	N.append(_n("o_shock", "STATIC CHARGE", "shock", "offense", 5, 2, "o_cd2", 5, [["shock", 2]], "+{0}% chance to shock threats"))
	N.append(_n("o_burn", "IGNITION SOURCE", "burn", "offense", 6, -2, "o_pspeed", 5, [["burn", 2]], "+{0}% chance to burn threats"))
	N.append(_n("o_poison", "TOXIC PAYLOAD", "poison", "offense", 6, -1, "o_crit2", 5, [["poison", 2]], "+{0}% chance to poison threats"))
	N.append(_n("o_freeze", "COOLANT LEAK", "freeze", "offense", 6, 1, "o_area2", 5, [["freeze", 2]], "+{0}% chance to freeze threats"))
	N.append(_n("o_potency", "VIRAL LOAD", "potency", "offense", 6, 2, "o_shock", 5, [["potency", 6]], "+{0}% status damage and duration"))

	# ---------------- CLASSES (every class is its own tree with its own root; a class must be bought again after every reformat) ----------------
	N.append(_n("ccore", "BASIC", "cursor", "classes", 0, 0, "", 1, [], "The base class: no bonuses, the PACKET GUN and the PURGE ability.", "core"))
	_at(N.back(), 0, 0)
	var cls_rows := [
		["sysadmin", "SYSADMIN", "vitality", 1, 0, "Class: starts with FIREWALL. +25 max HP, +0.3 HP/s. Ability RESTORE", 136.0],
		["hacker", "HACKER", "crit", 2, 0, "Class: starts with BACKDOOR. +10% crit, +20% crit damage. Ability OVERCLOCK", 340.0],
		["architect", "ARCHITECT", "area", 3, 0, "Class: starts with LOGIC MINE. +20% area and duration. Ability LOCKDOWN", 680.0],
		["ghost", "GHOST", "speed", 0, 2.4, "Class: starts with PING.EXE. +10% speed, +8% dodge. Ability PHASE", 1020.0],
		["analyst", "ANALYST", "xp", 1, 2.4, "Class: starts with SCANNER. +25% XP, +8% luck. Ability DEEP SCAN", 1360.0],
		["pacifist", "PACIFIST", "haste", 2, 2.4, "Secret class: starts with NO weapon. +30% XP, +10% luck. Ability PAUSE", 340.0],
		["railgunner", "RAILGUNNER", "evo_railgun", 0, 4.8, "Secret class: starts with the RAILGUN. +15% crit, +30% crit damage. Ability RAIL STRIKE", 1700.0],
		["arsonist", "ARSONIST", "evo_inferno", 1, 4.8, "Secret class: starts with SCORCHED EARTH. +25% area and duration. Ability WILDFIRE", 1700.0],
		["stormcaller", "STORMCALLER", "evo_tesla", 2, 4.8, "Secret class: starts with the TESLA GRID. +10% speed, +20% XP. Ability THUNDERSTORM", 1700.0],
		["cryomancer", "CRYOMANCER", "evo_blizzard", 3, 4.8, "Secret class: starts with ABSOLUTE ZERO. +30 max HP, +5% dodge. Ability DEEP FREEZE", 1700.0],
	]
	for row in cls_rows:
		N.append(_n("c_" + row[0], row[1], row[2], "classes", 1, 0, "", 1, [["class_" + row[0], 1]], row[5], "unlock"))
		N.back()["cost_mult"] = row[6]
		_at(N.back(), row[3], row[4])
		N.append(_n("c_" + row[0] + "_t", row[1] + " TRAINING", row[2], "classes", 3, 0, "c_" + row[0], 5, [["cpass_" + row[0], 10]], "+{0}% to the " + row[1] + " passive bonuses"))
		N.back()["cost_mult"] = 20.0
		_at(N.back(), row[3], row[4] + 1.0)
	# ability upgrades work for every class and the VIRUS: they hang from their own root
	N.append(_n("c_vc", "VERSION CONTROL", "key", "classes", 0, 0, "", 1, [], "Upgrades to the ability button, whichever class you play.", "core"))
	_at(N.back(), 3.6, 2.4)
	N.append(_n("c_recover", "HOT SWAP", "itemcd", "classes", 2, 0, "c_vc", 5, [["abilcd", 4]], "-{0}% ability cooldown"))
	_at(N.back(), 3.0, 3.4)
	N.append(_n("c_capacitor", "CAPACITOR", "proj", "classes", 2, 0, "c_vc", 2, [["maxcharge", 1]], "+{0} stored ability charges (max)"))
	_at(N.back(), 4.2, 3.4)
	N.append(_n("c_window", "PHASE LOCK", "area", "classes", 3, 0, "c_capacitor", 4, [["supwin", 0.05]], "SUPER cast window opens {0}s earlier"))
	_at(N.back(), 4.2, 4.4)

	# ---------------- DEFENSE ----------------
	N.append(_n("d_hp1", "REDUNDANCY", "vitality", "defense", 1, 0, "core", 5, [["hp", 10]], "+{0} max HP"))
	N.append(_n("d_regen1", "SELF-REPAIR", "regen", "defense", 2, -1, "d_hp1", 5, [["regen", 0.15]], "Regenerate {0} HP per second"))
	N.append(_n("d_armor1", "SANDBOX", "armor", "defense", 2, 1, "d_hp1", 3, [["armor", 1]], "Take {0} less damage per hit"))
	N.append(_n("d_heal", "HOTFIX", "heal", "defense", 3, -2, "d_regen1", 3, [["healdrop", 40]], "+{0}% repair patch drop chance"))
	N.append(_n("d_hp2", "RAID ARRAY", "vitality", "defense", 3, 0, "d_hp1", 5, [["hp", 15]], "+{0} max HP"))
	N.append(_n("d_iframe", "FAILSAFE", "iframe", "defense", 3, 2, "d_armor1", 3, [["iframe", 0.1]], "+{0}s invulnerability after a hit"))
	N.append(_n("d_regen2", "AUTO-PATCH", "regen", "defense", 4, -1, "d_hp2", 5, [["regen", 0.25]], "Regenerate {0} HP per second"))
	N.append(_n("d_armor2", "HARDENED KERNEL", "armor", "defense", 4, 1, "d_hp2", 3, [["armor", 1]], "Take {0} less damage per hit"))
	N.append(_n("d_thorns", "HONEYPOT", "thorns", "defense", 4, 2, "d_iframe", 5, [["thorns", 12]], "Attackers take {0} damage on contact"))
	N.append(_n("d_hp3", "CLOUD BACKUP", "vitality", "defense", 5, -1, "d_regen2", 5, [["hp", 25]], "+{0} max HP"))
	N.append(_n("d_revive", "SYSTEM RESTORE", "revive", "defense", 5, 0, "d_armor2", 1, [["revive", 1]], "Revive {0} time per run at 50% HP", "major"))
	N.append(_n("d_shield", "FIREWALL CORE", "shield", "defense", 5, 1, "d_thorns", 3, [["shield", 1]], "Shield blocks a hit. Rank {0}: recharges faster"))
	N.append(_n("d_ult", "IMMUTABLE", "armor", "defense", 6, 0, "d_revive", 1, [["hp", 50], ["armor", 2]], "+{0} max HP and take {1} less damage", "ult"))

	N.append(_n("d_bio", "BIO-REPAIR", "healing", "defense", 3, 1, "d_armor1", 5, [["healing", 6]], "+{0}% healing received"))
	N.append(_n("d_dodge", "EVASIVE ROUTINE", "dodge", "defense", 4, 0, "d_hp2", 5, [["dodge", 1]], "+{0}% chance to dodge a hit"))
	N.append(_n("d_guard", "BLAST DOORS", "armor", "defense", 4, -2, "d_heal", 5, [["guard", 4]], "-{0}% damage taken from elites and bosses"))
	N.append(_n("d_patch", "HOT PATCH", "heal", "defense", 5, -2, "d_guard", 5, [["patchheal", 20]], "Repair patches heal +{0}% more"))
	N.append(_n("d_leech", "SIPHON", "lifesteal", "defense", 6, -1, "d_hp3", 5, [["lifesteal", 0.1]], "Heal {0}% of damage you deal"))

	# ---------------- UTILITY ----------------
	N.append(_n("u_mag1", "BANDWIDTH", "magnet", "utility", 1, 0, "core", 5, [["magnet", 10]], "+{0}% pickup range"))
	N.append(_n("u_spd1", "OVERCLOCK", "speed", "utility", 2, -1, "u_mag1", 5, [["move", 3]], "+{0}% move speed"))
	N.append(_n("u_xp1", "MACHINE LEARNING", "xp", "utility", 2, 1, "u_mag1", 5, [["xp", 5]], "+{0}% XP gained"))
	N.append(_n("u_spd2", "LIQUID COOLING", "speed", "utility", 3, -2, "u_spd1", 5, [["move", 3]], "+{0}% move speed"))
	N.append(_n("u_data1", "DATA MINING", "data", "utility", 3, 0, "u_mag1", 5, [["data", 10]], "+{0}% DATA earned"))
	N.append(_n("u_xp2", "DEEP LEARNING", "xp", "utility", 3, 2, "u_xp1", 5, [["xp", 6]], "+{0}% XP gained"))
	N.append(_n("u_mag2", "5G UPLINK", "magnet", "utility", 4, -2, "u_spd2", 3, [["magnet", 15]], "+{0}% pickup range"))
	N.append(_n("u_data2", "DATA HOARDER", "data", "utility", 4, 0, "u_data1", 5, [["data", 15]], "+{0}% DATA earned"))
	N.append(_n("u_luck1", "RNG MANIPULATION", "luck", "utility", 4, 2, "u_xp2", 5, [["luck", 10]], "+{0}% upgrade rarity luck"))
	# id kept as "u_cache" so saves that bought the old cache-luck node keep their ranks (now item cooldown)
	N.append(_n("u_cache", "TASK SCHEDULER", "itemcd", "utility", 5, -1, "u_mag2", 3, [["itemcd", 6]], "-{0}% item cooldowns"))
	N.append(_n("u_data3", "BIG DATA", "data", "utility", 5, 0, "u_data2", 5, [["data", 20]], "+{0}% DATA earned"))
	N.append(_n("u_luck2", "LOADED DICE", "luck", "utility", 5, 1, "u_luck1", 5, [["luck", 12]], "+{0}% upgrade rarity luck"))
	N.append(_n("u_ult", "SINGULARITY", "infinity", "utility", 6, 0, "u_data3", 1, [["xp", 20], ["data", 30]], "+{0}% XP and +{1}% DATA", "ult"))

	# ---------------- ARSENAL (every weapon is its own tree: the weapon is the root, then its mastery; evolved weapons join once discovered) ----------------
	N.append(_n("a_laser", "PACKET GUN", "laser", "arsenal", 0, 0, "", 1, [], "Your starting weapon. Nothing to buy, only to master.", "core"))
	_at(N.back(), 0, 0)
	N.append(_n("a_laser_m", "GUN MASTERY", "laser", "arsenal", 3, 0, "a_laser", 5, [["wdmg_laser", 10]], "+{0}% PACKET GUN damage"))
	_at(N.back(), 0, 1)
	var weapon_rows := [
		["fw", "firewall", "FIREWALL", "FIREWALL MASTERY", 1, 1, 0, "wdmg_firewall", 3, 1, 0.0],
		["orbit", "orbit", "ENCRYPTION KEYS", "KEY MASTERY", 2, 2, 0, "wdmg_orbit", 3, 1, 0.0],
		["zap", "zap", "PING.EXE", "PING MASTERY", 2, 3, 0, "wdmg_zap", 3, 1, 0.0],
		["mines", "mines", "LOGIC MINE", "MINE MASTERY", 4, 4, 0, "wdmg_mines", 5, 1, 0.0],
		["scan", "scanner", "SCANNER", "SCANNER MASTERY", 4, 0, 3.2, "wdmg_scanner", 5, 1, 0.0],
		["back", "backdoor", "BACKDOOR", "BACKDOOR MASTERY", 5, 1, 3.2, "wdmg_backdoor", 6, 1, 0.0],
		["quar", "quarantine", "QUARANTINE", "QUARANTINE MASTERY", 5, 2, 3.2, "wdmg_quarantine", 6, 1, 0.0],
	]
	for row in weapon_rows:
		N.append(_n("a_" + row[0], row[2], row[1], "arsenal", row[4], 0, "", 1, [["unlock_" + row[1], 1]], "Adds " + row[2] + " to the upgrade pool", "unlock"))
		if WEAPON_PRICE.has(row[1]):
			N.back()["price"] = WEAPON_PRICE[row[1]]
		_at(N.back(), row[5], row[6])
		N.append(_n("a_" + row[0] + "_m", row[3], row[1], "arsenal", row[8], 0, "a_" + row[0], 5, [[row[7], 10]], "+{0}% " + row[2] + " damage"))
		_at(N.back(), row[5], row[6] + 1.0)
	# weapon slots: their own little tree under the weapon bay
	N.append(_n("acore", "WEAPON BAY", "slot", "arsenal", 0, 0, "", 1, [], "Weapon slots, status upgrades and starting levels.", "core"))
	_at(N.back(), 5, 0)
	N.append(_n("a_slot1", "EXPANSION SLOT", "slot", "arsenal", 3, 0, "acore", 1, [["slots", 1]], "+{0} weapon slot (5 slots max in total)", "major"))
	_at(N.back(), 5, 1)
	# ids "a_slot2" and "a_p1" (below) kept so old saves keep their ranks; base 4 + EXPANSION SLOT already reaches the 5-slot cap
	N.append(_n("a_slot2", "INFECTION TRANSMISSION", "potency", "arsenal", 6, 0, "a_slot1", 1, [["statchance", 25]], "Status effects apply {0}% more often (burn, poison, freeze, shock)", "major"))
	_at(N.back(), 5, 2)
	N.append(_n("a_start", "PRE-INSTALLED", "start", "arsenal", 7, 0, "a_slot2", 3, [["startlvl", 1]], "Starting weapon begins at LV +{0}", "major"))
	_at(N.back(), 5, 3)
	# evolved weapons: the same weapon + mastery pair as every other weapon, but never bought. The weapon node is granted for good
	# the first time the evolution is found in a run (Meta.node_granted), joins the upgrade pool and survives every reformat.
	# The masteries cost DATA like the others. (The old PP masteries and overdrives are refunded on load, see Meta._load.)
	var evo_rows := [["evo_railgun", "RAILGUN", 0], ["evo_inferno", "SCORCHED EARTH", 1], ["evo_tesla", "TESLA GRID", 2], ["evo_blizzard", "ABSOLUTE ZERO", 3]]
	for row in evo_rows:
		N.append(_n("a_" + row[0], row[1], row[0], "arsenal", 6, 0, "", 1, [["unlock_" + row[0], 1]], "Adds " + row[1] + " to the upgrade pool. Found by evolving it in a run, kept forever.", "unlock"))
		N.back()["grant"] = "evo:" + row[0]
		_at(N.back(), row[2], 6.4)
		N.append(_n("a_" + row[0] + "_m", row[1] + " MASTERY", row[0], "arsenal", 6, 0, "a_" + row[0], 5, [["wdmg_" + row[0], 10]], "+{0}% " + row[1] + " damage"))
		_at(N.back(), row[2], 7.4)

	# ---------------- SYSTEM ----------------
	N.append(_n("s_reroll1", "RECOMPILE", "reroll", "system", 1, 0, "core", 3, [["reroll", 1]], "+{0} upgrade rerolls per run"))
	N.append(_n("s_boot", "BOOTSTRAP", "start", "system", 2, -1, "s_reroll1", 3, [["startlevels", 1]], "Begin each run with {0} free upgrades"))
	N.append(_n("s_entropy", "ENTROPY", "luck", "system", 2, 1, "s_reroll1", 5, [["luck", 5]], "+{0}% upgrade rarity luck"))
	N.append(_n("s_choice", "PARALLEL PROCESSING", "choice", "system", 3, -1, "s_boot", 1, [["choices", 1]], "+{0} card in every upgrade offer", "major"))
	N.append(_n("s_elite", "THREAT INTEL", "elite", "system", 3, 0, "s_entropy", 5, [["elitedata", 25]], "+{0}% DATA from elites"))
	N.append(_n("s_reroll2", "RECOMPILE II", "reroll", "system", 3, 1, "s_entropy", 3, [["reroll", 1]], "+{0} upgrade rerolls per run"))
	N.append(_n("s_defrag", "DEFRAGMENTER", "magnet", "system", 4, -1, "s_choice", 3, [["magdrop", 60]], "+{0}% DEFRAG drop chance"))
	N.append(_n("s_ban", "BLOCKLIST", "ban", "system", 5, -1, "s_defrag", 3, [["ban", 1]], "+{0} bans per run (remove one rarity of a card, or an item, from this run's offers)"))
	N.append(_n("s_bounty", "BOUNTY PROGRAM", "boss", "system", 4, 0, "s_elite", 3, [["bossdata", 50]], "+{0}% DATA from bosses"))
	N.append(_n("s_premium", "PREMIUM LICENSE", "luck", "system", 4, 1, "s_reroll2", 3, [["luck", 15]], "+{0}% upgrade rarity luck"))
	N.append(_n("s_purge", "PURGE PAYLOAD", "bomb", "system", 5, 1, "s_premium", 5, [["purgedmg", 15]], "+{0}% System Purge damage"))
	N.append(_n("s_ult", "ADMIN RIGHTS", "key", "system", 5, 0, "s_bounty", 1, [["reroll", 2], ["dmg", 10]], "+{0} rerolls and +{1}% damage", "ult"))

	N.append(_n("pcore", "PRESTIGE CORE", "infinity", "core", 0, 0, "", 1, [], "Spend prestige points here. These upgrades survive every reformat.", "core"))

	# ---------------- PRESTIGE TREE (bought with prestige points, kept through reformats) ----------------
	N.append(_n("o_p1", "QUANTUM ALGORITHMS", "might", "offense", 1, 0, "pcore", 10, [["dmg", 8]], "+{0}% damage", "prestige", 0))
	N.append(_n("d_p1", "ERROR CORRECTION", "vitality", "defense", 1, 0, "pcore", 10, [["hp", 20], ["regen", 0.2]], "+{0} max HP, +{1} HP/s", "prestige", 0))
	N.append(_n("u_p1", "COMPRESSION", "data", "utility", 1, 0, "pcore", 10, [["data", 20]], "+{0}% DATA earned", "prestige", 0))
	N.append(_n("a_p1", "TOXIC PERSISTENCE", "poison", "arsenal", 1, 0, "pcore", 1, [["statusdur", 40]], "+{0}% duration on status effects you apply", "prestige", 0))
	N.append(_n("s_p1", "SUPERUSER", "reroll", "system", 1, 0, "pcore", 5, [["reroll", 1], ["luck", 8]], "+{0} rerolls, +{1}% luck", "prestige", 0))

	N.append(_n("o_p2", "ANNIHILATOR", "critdmg", "offense", 2, 0, "o_p1", 10, [["critdmg", 15]], "+{0}% critical damage", "prestige", 0))
	N.append(_n("d_p2", "IMMORTAL PROCESS", "revive", "defense", 2, 0, "d_p1", 1, [["revive", 1]], "+{0} revive per run", "prestige", 0))
	N.append(_n("u_p2", "HYPERDRIVE", "speed", "utility", 2, 0, "u_p1", 10, [["move", 3], ["xp", 5]], "+{0}% move speed, +{1}% XP", "prestige", 0))
	N.append(_n("a_p2", "EVOLUTION", "elite", "arsenal", 2, 0, "a_p1", 2, [["maxwlvl", 1]], "Weapons can level {0} beyond LV 10", "prestige", 0))
	N.append(_n("s_p2", "MULTIVERSE", "choice", "system", 2, 0, "s_p1", 1, [["choices", 1]], "+{0} card in every upgrade offer", "prestige", 0))

	N.append(_n("o_p3", "INFINITE RECURSION", "infinity", "offense", 3, 0, "o_p2", 25, [["dmg", 5]], "+{0}% damage", "prestige", 0))
	N.append(_n("d_p3", "ETERNAL UPTIME", "infinity", "defense", 3, 0, "d_p2", 25, [["hp", 15]], "+{0} max HP", "prestige", 0))
	N.append(_n("u_p3", "ENDLESS STREAM", "infinity", "utility", 3, 0, "u_p2", 25, [["data", 15]], "+{0}% DATA earned", "prestige", 0))
	N.append(_n("a_p3", "OMNI-ARSENAL", "infinity", "arsenal", 3, 0, "a_p2", 25, [["wdmg_all", 5]], "+{0}% damage for every weapon", "prestige", 0))
	N.append(_n("s_p3", "DEUS EX MACHINA", "infinity", "system", 3, 0, "s_p2", 25, [["luck", 5], ["cd", 1]], "+{0}% luck, -{1}% cooldowns", "prestige", 0))

	# class license bought with prestige points: it only grants the option to buy the class in the CLASSES tree
	N.append(_n("p_architect", "ARCHITECT LICENSE", "area", "arsenal", 1, 1, "pcore", 1, [["permit_class_architect", 1], ["permit_weapon_firewall", 1]], "Lets you buy the ARCHITECT class and the FIREWALL weapon forever", "prestige"))
	N.back()["pp_base"] = 10.0

	# features that stay hidden until bought with prestige points
	N.append(_n("p_speed", "TIME DILATION", "haste", "offense", 1, 1, "pcore", 1, [["feat_speed", 1]], "Unlocks SPEED RUN on cured devices", "prestige"))
	N.back()["pp_base"] = 4.0
	N.append(_n("p_threat", "THREAT ANALYSIS", "elite", "offense", 1, -1, "pcore", 1, [["feat_threat", 1]], "Unlocks THREAT LEVEL on cured devices and THE INTERNET", "prestige"))
	N.back()["pp_base"] = 6.0
	N.append(_n("p_trials", "TRIAL ACCESS", "key", "defense", 1, 1, "pcore", 1, [["feat_trials", 1]], "Unlocks CHALLENGES on the device map", "prestige"))
	N.back()["pp_base"] = 3.0
	N.append(_n("p_root", "ROOT KEY", "key", "utility", 1, -1, "pcore", 9999, [["data", 1], ["dmg", 1]], "+{0}% DATA and +{1}% damage (never ends, costs more each rank)", "prestige"))
	N.back()["pp_base"] = 2.0
	N.back()["pp_linear"] = 0.4

	# infinite: each rank adds 10% to the chance of an extra prestige point per cure; 100% or more adds guaranteed extras (250% = 2 plus a 50% chance of a third)
	N.append(_n("p_harvest", "PRESTIGE HARVEST", "infinity", "system", 1, -1, "pcore", 9999, [["pp_bonus", 10]], "{0}% chance to gain an extra prestige point per cure (every 100% is a guaranteed extra)", "prestige"))
	N.back()["pp_base"] = 3.0
	N.back()["pp_linear"] = 0.5

	# automated cache selection (a prestige node, per Cheng)
	N.append(_n("s_pauto", "AUTO-DECRYPT", "key", "system", 2, 1, "s_p1", 1, [["autocache", 1]], "Caches open themselves and pick a safe item for you", "prestige"))
	N.append(_n("s_pauto2", "AUTO-UPGRADE", "choice", "system", 2, -1, "s_p1", 1, [["autolevel", 1]], "Level-up cards pick themselves without pausing the run", "prestige"))
	return N
