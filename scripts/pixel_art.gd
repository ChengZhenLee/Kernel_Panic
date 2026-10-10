extends RefCounted
## Pixel art from res://art/ (classes, enemies, weapon / card / item icons and hazard pages). Every lookup returns null when a file is
## missing, so callers keep drawing the old vector shapes. Textures come through the importer, or straight from the PNG when the project
## has not been re-imported since the art was added.
## Sheets: classes 8 frames of 28x28 (300 ms each), enemies 2 frames of 12x12 (340 ms each), hazards 8 frames of 64x64 (150 ms each),
## weapon / card / item icons are single 16x16 images.

const ROOT := "res://art/"
const CLASS_FRAME := 28
const CLASS_FRAMES := 8
const CLASS_MS := 300.0
const ENEMY_FRAME := 12
const ENEMY_MS := 340.0
const HAZARD_FRAME := 64
const HAZARD_FRAMES := 8
const HAZARD_MS := 200.0   # 5 pages a second, the same pace in the codex and in runs (was 10: the fans spun far too fast)

static var _cache := {}

## weapon id (game.gd WEAPONS) -> file in art/weapons
const WEAPON_ART := {"laser": "packet_gun", "firewall": "firewall", "orbit": "encryption_keys", "zap": "ping_exe", "mines": "logic_mine",
	"scanner": "scanner", "quarantine": "quarantine", "backdoor": "backdoor", "evo_railgun": "railgun", "evo_inferno": "scorched_earth",
	"evo_tesla": "tesla_grid", "evo_blizzard": "absolute_zero"}

## stat card id (game.gd STATS) -> file in art/cards
const CARD_ART := {"speed": "overclock", "vitality": "redundancy", "magnet": "bandwidth", "might": "root_access", "haste": "multithread",
	"crit": "exploit", "regen": "self_repair", "area": "amplifier", "luck": "fortune", "critdmg": "lethality", "armor": "hardening",
	"pierce": "penetration", "knockback": "impact", "healing": "bio_enhance", "lifesteal": "leech", "dodge": "evasion",
	"projspeed": "projectile_speed", "xp": "machine_learning", "proj": "projectile_count", "duration": "persistence", "abilcd": "hot_swap",
	"itemcd": "scheduler", "burn": "ignition", "poison": "toxin", "freeze": "cryogen", "shock": "static_shock", "potency": "virulence"}

## item icon id (items.gd "icon") -> file in art/items
const ITEM_ART := {"drone": "drone", "totem": "totem", "backfire": "backfire", "killstreak": "killstreak", "idleloop": "idleloop",
	"kinetic": "kinetic", "glasscannon": "glasscannon", "adrenaline": "adrenaline", "collector": "collector", "decoy": "decoy",
	"beacon": "beacon", "chain": "chain", "recycler": "recycler", "swarmshield": "swarmshield", "guardian": "guardian",
	"striker": "striker", "heavyarmor": "heavyarmor", "slowburn": "slowburn", "berserker": "berserker", "momentum": "momentum",
	"hotstreak": "hotstreak", "holdbuffer": "holdbuffer", "revive": "backup", "rage": "rage", "trophy": "trophy",
	"flashpoint": "flashpoint", "plague": "plague", "shatter": "shatter", "overvolt": "overvolt", "reroll": "seedhack",
	"ban": "blocklist", "cherrypick": "cherrypick"}

## pickup kind (pickup.gd) -> file in art/items
const PICKUP_ART := {"xp": "xp", "heal": "patch", "magnet": "magnet", "purge": "purge", "cache": "cache"}

## enemy kind (enemy.gd) -> file in art/enemies, for kinds whose name differs
const ENEMY_FILE := {"ransom": "ransomware", "zipbomb": "zip_bomb"}
## the way a side-view sprite faces in its image (-1 left, 1 right); the others look the same both ways
const ENEMY_FACING := {"worm": -1, "sentry": 1}

## icon ids that only exist so the art lookup can tell them apart: when no sprite is found, draw the old vector icon of this id
const FALLBACK := {"flashpoint": "burn", "plague": "poison", "shatter": "freeze", "overvolt": "shock"}


static func load_tex(rel: String) -> Texture2D:
	var path := ROOT + rel
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex


## One 16x16 icon for a weapon, stat card or item id, or null.
static func icon_tex(id: String) -> Texture2D:
	if WEAPON_ART.has(id):
		return load_tex("weapons/%s.png" % WEAPON_ART[id])
	if CARD_ART.has(id):
		return load_tex("cards/%s.png" % CARD_ART[id])
	if ITEM_ART.has(id):
		return load_tex("items/%s.png" % ITEM_ART[id])
	return null


static func pickup_tex(kind: String) -> Texture2D:
	if PICKUP_ART.has(kind):
		return load_tex("items/%s.png" % PICKUP_ART[kind])
	return null


static func class_tex(class_id: String) -> Texture2D:
	return load_tex("classes/%s.png" % (class_id if class_id != "" else "basic"))


## The in-run avatar: a calmer build of the class sprite (no particles, flicker or chest emblem), falling back to the menu / codex one.
static func class_run_tex(class_id: String) -> Texture2D:
	var tex := load_tex("classes/run/%s.png" % (class_id if class_id != "" else "basic"))
	return tex if tex != null else class_tex(class_id)


static func enemy_tex(kind: String) -> Texture2D:
	return load_tex("enemies/%s.png" % ENEMY_FILE.get(kind, kind))


static func hazard_tex(id: String) -> Texture2D:
	return load_tex("hazards/%s.png" % id)


## A mirrored copy of a sprite strip (frame order reversed along with it, so callers use frames - 1 - f).
static func flipped(tex: Texture2D) -> Texture2D:
	var key := "flip:%d" % tex.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var out: Texture2D = tex
	var img := tex.get_image()
	if img != null:
		img.flip_x()
		out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## A class avatar centred on c, size px tall, animated from time t (seconds).
static func draw_class(ci: CanvasItem, tex: Texture2D, c: Vector2, size: float, t: float, flip := false, mod := Color.WHITE) -> void:
	var f := int(t * 1000.0 / CLASS_MS) % CLASS_FRAMES
	if flip:
		tex = flipped(tex)
		f = CLASS_FRAMES - 1 - f
	ci.draw_texture_rect_region(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), Rect2(f * CLASS_FRAME, 0, CLASS_FRAME, CLASS_FRAME), mod)


## A regular enemy centred on the origin, size px square, mirrored toward the side the player is on when the sprite has a facing.
static func draw_enemy(ci: CanvasItem, tex: Texture2D, kind: String, size: float, t: float, to_player_x: float, mod := Color.WHITE) -> void:
	var f := int(t * 1000.0 / ENEMY_MS) % 2
	var nat: int = ENEMY_FACING.get(kind, 0)
	if nat != 0 and absf(to_player_x) > 1.0 and (1 if to_player_x > 0.0 else -1) != nat:
		tex = flipped(tex)
		f = 1 - f
	ci.draw_texture_rect_region(tex, Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)), Rect2(f * ENEMY_FRAME, 0, ENEMY_FRAME, ENEMY_FRAME), mod)


## Enemies whose sprite is built from layers so a part can aim at the player: kind -> [fixed layer, aiming layer].
## sentry: tripod + gun (the gun turns about its housing); spyware: eyeball + iris (the iris slides toward the player).
const AIMED := {"sentry": ["sentry_base", "sentry_gun"], "spyware": ["spyware_body", "spyware_iris"]}
const SENTRY_PIVOT := Vector2(3.5, 4.5)   # gun housing, in sprite pixels
const IRIS_TRAVEL := 1.5                  # sprite pixels the iris can slide from centre


static func has_aimed(kind: String) -> bool:
	if not AIMED.has(kind):
		return false
	var key := "aimed:" + kind
	if not _cache.has(key):   # looked up once; this runs for every sentry / spyware every redraw
		_cache[key] = load_tex("enemies/%s.png" % AIMED[kind][0]) != null and load_tex("enemies/%s.png" % AIMED[kind][1]) != null
	return _cache[key]


## An enemy drawn in two layers with the second one aimed along aim (a direction toward the player). sq is the squash scale
## the caller's draw transform used, restored afterwards.
static func draw_enemy_aimed(ci: CanvasItem, kind: String, size: float, t: float, aim: Vector2, sq: float, mod := Color.WHITE) -> void:
	var f := int(t * 1000.0 / ENEMY_MS) % 2
	var src := Rect2(f * ENEMY_FRAME, 0, ENEMY_FRAME, ENEMY_FRAME)
	var s := size / ENEMY_FRAME
	var base: Texture2D = load_tex("enemies/%s.png" % AIMED[kind][0])
	var top: Texture2D = load_tex("enemies/%s.png" % AIMED[kind][1])
	var d := aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	ci.draw_texture_rect_region(base, Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)), src, mod)
	if kind == "sentry":
		var left := d.x < 0.0
		var ang := d.angle() - PI if left else d.angle()
		var xf := Transform2D(ang, (SENTRY_PIVOT - Vector2(6, 6)) * s).scaled_local(Vector2(-1.0 if left else 1.0, 1.0))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY.scaled(Vector2(sq, 2.0 - sq)) * xf)   # squash applies to the turned gun too
		ci.draw_texture_rect_region(top, Rect2(-SENTRY_PIVOT * s, Vector2(size, size)), src, mod)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(sq, 2.0 - sq))
	else:
		var off := (d * IRIS_TRAVEL).round() * s   # whole sprite pixels, so the iris stays on the art's pixel grid
		ci.draw_texture_rect_region(top, Rect2(Vector2(-size, -size) * 0.5 + off, Vector2(size, size)), src, mod)


## A hazard page (a 64x64 picture of the zone, floor included), centred on c.
static func draw_hazard(ci: CanvasItem, tex: Texture2D, c: Vector2, size: float, t: float, half := -1) -> void:   # half 0 / 1: loop only the first / second half of the sheet (flux: fast / slow)
	var n := hazard_frames(tex)
	var f := int(t * 1000.0 / HAZARD_MS) % n
	if half >= 0:
		f = f % (n / 2) + half * (n / 2)
	var src := Rect2(f * HAZARD_FRAME, 0, HAZARD_FRAME, HAZARD_FRAME)
	ci.draw_texture_rect_region(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), src)


## Frames in a hazard sheet (8 for most; the vent and strike sheets are longer so they play smoothly on their own clock).
static func hazard_frames(tex: Texture2D) -> int:
	return maxi(1, int(tex.get_width() / HAZARD_FRAME))


## An in-run hazard zone: the page's circle (clipped, so the page's square floor never shows) scaled to the zone radius r.
const HAZARD_CIRCLE := 29.0   # radius in page pixels of the circle the art draws, out of 32
static func draw_hazard_zone(ci: CanvasItem, tex: Texture2D, c: Vector2, r: float, t: float, alpha := 1.0, ang := 0.0, half := -1, frame := -1, art_r := 0.0) -> void:   # ang: turns the art (the fan blows right at 0); half 0 / 1: loop only the first / second half of the sheet; frame >= 0: show that exact sheet frame (timed zones play once on their own clock)
	var n := hazard_frames(tex)
	var f := int(t * 1000.0 / HAZARD_MS) % n
	if half >= 0:
		f = f % (n / 2) + half * (n / 2)
	if frame >= 0:
		f = clampi(frame, 0, n - 1)
	if art_r > 0.0:   # art whose ring is smaller than the page circle (vent, strike) and sits on a transparent page: scale so the ring is exactly the zone radius, nothing clipped
		var k := r / art_r
		ci.draw_texture_rect_region(tex, Rect2(c - Vector2(32.0, 32.0) * k, Vector2(64.0, 64.0) * k), Rect2(f * HAZARD_FRAME, 0, HAZARD_FRAME, HAZARD_FRAME), Color(1, 1, 1, alpha))
		return
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 40:
		var d := Vector2.from_angle(TAU * i / 40.0)
		pts.append(c + d * r * (HAZARD_CIRCLE + 1.0) / HAZARD_CIRCLE)
		var uv := Vector2(32.0, 32.0) + d.rotated(-ang) * (HAZARD_CIRCLE + 1.0)
		uvs.append(Vector2((f * HAZARD_FRAME + uv.x) / (HAZARD_FRAME * n), uv.y / HAZARD_FRAME))
	ci.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, alpha)]), uvs, tex)


## boss id (boss_data.gd) -> file stem in art/bosses; two idle frames per state, swapped every BOSS_MS
const BOSS_FILE := {"megaworm": "megaworm", "locker": "the_locker", "hive": "botnet_hive", "popupking": "pop_up_king", "keylogger": "keylogger",
	"phisher": "phisher", "kernel": "root_kernel", "baseband": "baseband", "bluescreen": "blue_screen"}
const BOSS_MS := 400.0
const BOSS_FINALS := ["kernel", "baseband", "bluescreen"]   # 56 px sheets (48 px art); the rest are 40 px (32 px art)


static func boss_tex(id: String, enraged: bool, t: float) -> Texture2D:
	if not BOSS_FILE.has(id):
		return null
	return load_tex("bosses/%s_%s_%d.png" % [BOSS_FILE[id], "enraged" if enraged else "normal", int(t * 1000.0 / BOSS_MS) % 2])


## A boss sprite centred on the origin: the art (32 or 48 px wide) is scaled by a whole number to about 2x the boss radius, and mirrored
## when flip is set (the art faces left). grow scales it during the intro.
const BOSS_MIN_ART := 96.0   # px of art: the visible body is about 3/4 of it, so every boss is at least twice the 36 px of the player avatar
const BOSS_VISUAL_MULT := 2.0   # bosses are drawn at 2x so they read apart from elites (the hitbox radius is unchanged); the codex cage follows


## The whole-number scale of a boss sprite: about 2x the radius, and never less than BOSS_MIN_ART px of art.
static func boss_scale(id: String, radius: float) -> float:
	var art := 48.0 if BOSS_FINALS.has(id) else 32.0
	return maxf(maxf(1.0, floorf(2.0 * radius / art + 0.35)), ceilf(BOSS_MIN_ART / art)) * BOSS_VISUAL_MULT


## Width of a boss's art in px at that scale (what the codex checks to keep every boss at least BOSS_MIN_ART).
static func boss_art_width(id: String, radius: float) -> float:
	return (48.0 if BOSS_FINALS.has(id) else 32.0) * boss_scale(id, radius)


static func draw_boss(ci: CanvasItem, tex: Texture2D, id: String, radius: float, flip: bool, grow := 1.0, mod := Color.WHITE) -> void:
	var k := boss_scale(id, radius) * grow
	var size := tex.get_size() * k
	var s := Vector2(-1.0 if flip else 1.0, 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, s)
	ci.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
