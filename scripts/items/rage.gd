extends Node
## RAGE.EXE: getting hit while it is ready starts a rage: +50% damage and +20% move speed for 6s
## (scaled by effect duration). Then it recharges for 30s (scaled by item cooldown).
## Its cooldown shows in the HUD's top-left item cooldown row.

const DMG := 50.0
const SPEED := 20.0
const BASE_LENGTH := 6.0
const BASE_COOLDOWN := 30.0

var player
var cooldown := 0.0
var cooldown_total := 1.0
var active := 0.0


func _ready() -> void:
	player = get_parent()


func _process(delta: float) -> void:
	if active > 0.0:
		active -= delta
		if active <= 0.0:
			player.add_bonus("dmg", -DMG)
			player.add_bonus("speed", -SPEED)
	elif cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)


func on_hurt(_arg = null) -> void:
	if active > 0.0 or cooldown > 0.0:
		return
	active = BASE_LENGTH * player.duration_mult
	cooldown_total = BASE_COOLDOWN * player.item_cd()
	cooldown = cooldown_total
	player.add_bonus("dmg", DMG)
	player.add_bonus("speed", SPEED)
	Global.game.hud.announce("RAGE!", Global.C_RED)
	Global.game.ifx("rage", player.global_position, Global.C_RED, 170.0, 0.6)
	Sfx.play("it_rage", 1.0, -3.0, 0.0)


## HUD: 0 = ready, 1 = just used. Shows full while the rage is running.
func cd_frac() -> float:
	if active > 0.0:
		return 1.0
	return clampf(cooldown / cooldown_total, 0.0, 1.0)


func is_active() -> bool:
	return active > 0.0
