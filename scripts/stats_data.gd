extends RefCounted
## Stat registry for the pause-screen stats tab.
## To add a stat: add one _row(...) line to a group below. To add a new category (e.g. status
## effects), add a group to groups(); groups with no rows are hidden automatically.

const PlayerScript = preload("res://scripts/player.gd")
const ItemData = preload("res://scripts/items.gd")
const NEUTRAL := Color(0.9, 0.96, 1.0)


static func _row(label: String, value: String, detail := "", tint := NEUTRAL) -> Dictionary:
	return {"label": label, "value": value, "detail": detail, "tint": tint}


## Explains where a percent bonus comes from: permanent research / prestige vs. this run.
static func _split(total: float, research: float) -> String:
	return "research %+d%%, this run %+d%%" % [int(round(research)), int(round(total - research))]


static func groups(game) -> Array:
	var p = game.player
	var out := []

	var research_dmg: float = Meta.stat("dmg") + Meta.root_damage_bonus() * 100.0
	var crit_pct := int(round(p.crit_chance * 100.0))
	var offense := [
		_row("Damage", "x%.2f" % p.damage_mult, _split(p.pct["dmg"], research_dmg)),
		_row("Cooldown", "x%.2f" % p.cooldown_mult, "lower is faster, floor x0.20. " + _split(p.pct["haste"], Meta.stat("cd"))),
		_row("Crit chance", "%d%%" % crit_pct, ("%d guaranteed crit tier(s)" % int(p.crit_chance)) if p.crit_chance >= 1.0 else ""),
		_row("Crit damage", "x%.2f" % p.crit_mult, "each crit tier adds +%d%%" % int(round((p.crit_mult - 1.0) * 100.0))),
		_row("Weapon area", "x%.2f" % p.area(), "size and reach of your weapons. Cap x%.1f" % p.AREA_CAP),
		_row("Extra projectiles", "+%d" % p.extra_proj, "cap +%d" % game.PROJ_CAP),
		_row("Projectile speed", "x%.2f" % p.proj_speed, "how fast your shots travel. Cap x%.1f" % p.PROJ_SPEED_CAP),
		_row("Knockback", "x%.2f" % p.knockback_mult, "cap x%.1f" % p.KNOCKBACK_CAP),
		_row("Effect duration", "x%.2f" % p.duration_mult, "how long timed effects last"),
		_row("Item cooldown", "x%.2f" % p.item_cd(), "item stat x%.2f (research -%d%%), times weapon cooldown. Floor x0.20" % [p.item_cooldown_mult, int(Meta.stat("itemcd"))]),
		_row("Ability cooldown", "x%.2f" % (1.0 - minf(p.abilcd, 50.0) / 100.0), "HOT SWAP -%d%%, cap -50%%. Stored charges: max %d" % [int(p.abilcd), game.max_charges]),
		_row("Extra pierce", "+%d" % p.extra_pierce),
		_row("Elite / boss damage", "x%.2f" % p.boss_mult),
	]
	out.append({"name": "OFFENSE", "color": Global.C_RED, "rows": offense})

	var defense := [
		_row("Max HP", "%d / %d" % [int(p.hp), int(p.max_hp)]),
		_row("Regeneration", "%.2f HP/s" % p.regen),
		_row("Armor", "%.1f" % p.armor, "flat reduction per hit (a hit always deals at least 1)"),
		_row("Damage taken", "x%.2f" % p.damage_taken_mult),
		_row("Thorns", "%d" % int(p.thorns), "damage dealt to attackers"),
		_row("Dodge chance", "%d%%" % int(round(p.dodge * 100.0)), "chance to ignore a hit. Cap %d%%" % int(p.DODGE_CAP * 100.0)),
		_row("Lifesteal", "%.1f%%" % (p.lifesteal * 100.0), "of damage dealt; heals at most 1.5%% max HP per second. Cap %.0f%%" % (p.LIFESTEAL_CAP * 100.0)),
		_row("Healing received", "x%.2f" % p.heal_mult, "pickups, regen, lifesteal and repair effects. Cap x%.1f" % p.HEAL_CAP),
		_row("Invulnerability", "%.2fs" % p.iframe, "after being hit"),
		_row("Revives left", str(p.revives)),
	]
	if p.shield_level > 0:
		defense.append(_row("Shield", "READY" if p.shield_ready else "%ds" % int(ceil(p.shield_timer)), "blocks one hit, then recharges"))
	out.append({"name": "DEFENSE", "color": Global.C_GREEN, "rows": defense})

	var speed_mult: float = minf(p.speed, PlayerScript.BASE_SPEED * PlayerScript.MAX_SPEED_MULT) / PlayerScript.BASE_SPEED
	var utility := [
		_row("Move speed", "x%.2f" % speed_mult, "cap x%.1f. %s" % [PlayerScript.MAX_SPEED_MULT, _split(p.pct["speed"], Meta.stat("move"))]),
		_row("Pickup range", "%d px" % int(p.pickup_radius), _split(p.pct["magnet"], Meta.stat("magnet"))),
		_row("XP gain", "x%.2f" % p.xp_mult),
		_row("Luck", "+%d%%" % int(Meta.stat("luck") + p.luck_run), "research +%d%%, this run +%d%%. No cap; each point matters a little less. Elite chest chance %d%%" % [int(Meta.stat("luck")), int(p.luck_run), int(round(game.cache_chance() * 100.0))]),
		_row("DATA gain", "x%.2f" % Meta.data_mult(), "research, ROOT KEY ranks and device bonus"),
		_row("Rerolls left", str(game.rerolls)),
		_row("Bans left", str(game.bans_left), "ban one rarity of a card (or a whole item) to remove it from this run's offers"),
		_row("Upgrade choices", str(game.offer_size()), "CHERRY PICK: one fewer card, +300% luck" if p.items.has("cherrypick") else ""),
		_row("Weapon slots", "%d / %d" % [p.weapons.size(), game.max_weapons]),
		_row("Max weapon level", str(game.max_weapon_level)),
	]
	out.append({"name": "UTILITY", "color": Color(0.3, 0.75, 1.0), "rows": utility})

	var weapons := []
	for id in p.weapons:
		weapons.append(_row(game.WEAPONS[id]["title"], "LV %d" % p.weapons[id].level, "mastery damage x%.2f" % p.weapon_dmg.get(id, 1.0)))
	out.append({"name": "WEAPONS", "color": Global.C_PURPLE, "rows": weapons})

	var items := []
	for id in p.items:
		var it: Dictionary = ItemData.ITEMS[id]
		var value := "CORRUPTED" if it["kind"] == "risky" else ""
		var node = p.items[id]
		if id == "trophy" and node is Node:
			value = "+%d%% DMG" % int(node.stacks * node.PER_STACK)   # damage stacks earned so far
		items.append(_row(it["title"], value, it["desc"], Global.C_RED if it["kind"] == "risky" else Global.C_GREEN))
	out.append({"name": "ITEMS", "color": Global.C_CYAN, "rows": items})

	if not game.banned.is_empty():
		var ban_rows := []
		for k in game.banned:
			ban_rows.append(_row(game.banned[k], "BANNED", "only this rarity" if not k.begins_with("item:") else "", Global.C_RED))
		out.append({"name": "BANNED THIS RUN", "color": Global.C_RED, "rows": ban_rows})

	var run := [
		_row("Device", Meta.device_name()),
		_row("Run mode", Meta.mode_name(), "HARD, SPEED RUN and THE INTERNET are chosen on the device map"),
		_row("Map", Meta.MapsData.name_of(Meta.selected_device) if not game.internet else "THE INTERNET (endless)"),
		_row("Hazard", game.hazards.kind["name"], game.hazards.kind["text"]),
		_row("Class", game.cls["name"] if not game.cls.is_empty() else "-", "" if game.cls.is_empty() else game.cls["passive_text"]),
		_row("Challenge", game.challenge["name"] if not game.challenge.is_empty() else "-"),
		_row("Threat level", "%d / %d" % [Meta.run_threat(), Meta.THREAT_MAX], "each level: enemy HP +20%, damage +10%, spawns +12%, DATA +15% (chosen on the device map)"),
		_row("Enemy strength", "HP x%.1f   DMG x%.1f" % [Meta.enemy_hp_mult(), Meta.enemy_dmg_mult()], "device tier and mode, before the run clock scaling"),
		_row("Enemy damage now", "x%.2f" % (Meta.enemy_dmg_mult() * (1.0 + 0.1 * game.elapsed / 60.0) * Global.overtime_dmg_mult(game.elapsed / 60.0)), "grows +10%% every minute, and faster in overtime"),
		_row("Uptime", Global.format_time(game.elapsed)),
		_row("Level", str(p.level)),
		_row("Threats deleted", str(game.kills)),
		_row("Current combo", "x%d" % int(game.combo), game.combo_text(game.combo_bonus)),
		_row("Best combo", "x%d" % game.best_combo),
		_row("Bosses deleted" if game.internet else "Bosses defeated", str(game.bosses_defeated + game.overtime_bosses) if game.internet else "%d / 4" % game.bosses_defeated),
		_row("Overtime", Global.format_time(game.elapsed - game.overtime_start) if game.overtime else "-", "after the final boss. Best %s, overtime bosses %d" % [Global.format_time(Global.best_overtime), game.overtime_bosses]),
		_row("Swarm waves", str(game.swarm_wave)),
		_row("DATA this run", "%d" % int(game.data_earned()), "", Global.C_GOLD),
	]
	out.append({"name": "THIS RUN", "color": Global.C_GOLD, "rows": run})

	# Future categories go here. Example: status effects (hidden while empty).
	var status := []
	var names := {"burn": "Burn", "poison": "Poison", "freeze": "Freeze", "shock": "Shock"}
	var info := {
		"burn": "burns for about %d%% of the hit per second, %.1fs",
		"poison": "stacks to 5, each %d%% of the hit per second, %.1fs",
		"freeze": "slows to 55%% speed for %.1fs (bosses are immune)",
		"shock": "stuns for 0.8s (bosses are immune) and the target takes 25%% more damage for %.1fs"}
	var mult: float = p.status_mult()
	var tmult: float = p.status_time_mult()
	for k in names:
		if p.status_chance[k] > 0.0:
			var secs: float = game.EnemyScript.STATUS_TIME[k] * tmult
			var d := ""
			match k:
				"burn":
					d = info[k] % [int(game.EnemyScript.BURN_RATE * mult * 100.0), secs]
				"poison":
					d = info[k] % [int(game.EnemyScript.POISON_RATE * mult * 100.0), secs]
				_:
					d = info[k] % secs
			status.append(_row(names[k], "%d%% chance" % int(p.status_chance[k] * p.status_chance_mult), d, game.EnemyScript.STATUS_COLOR[k]))
	if p.status_potency > 0.0:
		status.append(_row("Virulence", "+%d%%" % int(p.status_potency), "status damage and duration"))
	if p.status_chance_mult > 1.0:
		status.append(_row("Infection Transmission", "+%d%%" % int(round((p.status_chance_mult - 1.0) * 100.0)), "status effects apply more often"))
	if p.status_duration_mult > 1.0:
		status.append(_row("Toxic Persistence", "+%d%%" % int(round((p.status_duration_mult - 1.0) * 100.0)), "status effect duration"))
	out.append({"name": "STATUS EFFECTS", "color": Global.C_MAGENTA, "rows": status})
	return out
