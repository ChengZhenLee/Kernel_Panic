extends RefCounted
## Sprite-sheet playback for the evolution weapon FX (assets/fx/weapons/*.png, see the README there). Each sheet is a horizontal strip of equal frames at 12 fps.
## Everything is drawn on the world pixel grid at whole-number scales, so the art stays crisp. If a sheet is missing (not imported yet) draw() returns false and the
## caller falls back to its code-drawn version.

const Pix = preload("res://scripts/fx/pix.gd")
const DIR := "res://assets/fx/weapons/"
const FPS := 12.0

## frames per sheet (the same numbers as assets/fx/weapons/manifest.json)
const FRAMES := {
	"evo_railgun_beam": 8, "evo_railgun_hit": 6,
	"evo_inferno_flame": 8, "evo_inferno_pillar": 10,
	"evo_tesla_strike": 10, "evo_tesla_coil": 8,
	"evo_blizzard_flake": 8, "evo_blizzard_crystal": 6, "evo_blizzard_glyph": 8,
	"packet_bolt": 4, "packet_hit": 5, "firewall_brick": 8, "key_head": 8,
	"quarantine_emblem": 8, "quarantine_pylon": 6, "quarantine_drop": 8, "mine_idle": 8, "mine_blast": 10,
	"scanner_hub": 8, "scanner_blip": 6, "backdoor_door": 8, "backdoor_boomerang": 8, "backdoor_slash": 5, "ping_hit": 6,
}

static var _tex := {}


static func tex(sheet: String) -> Texture2D:
	if not _tex.has(sheet):
		var p: String = DIR + sheet + ".png"
		_tex[sheet] = load(p) if ResourceLoader.exists(p) else null
	return _tex[sheet]


static func has(sheet: String) -> bool:
	return tex(sheet) != null


static var _frame_size := {}   # sheet -> frame size (the textures never change, and draw() asks for this per mark)


static func frame_size(sheet: String) -> Vector2:
	var hit = _frame_size.get(sheet)
	if hit != null:
		return hit
	var t := tex(sheet)
	if t == null:
		return Vector2.ZERO   # not cached: the sheet may be imported later
	var fs := Vector2(t.get_width() / FRAMES[sheet], t.get_height())
	_frame_size[sheet] = fs
	return fs


## Frame number at time t (seconds) for a loop that runs at fps (default 12), shifted by offset frames.
static func at(t: float, offset := 0, fps := FPS) -> int:
	return int(t * fps) + offset


## Draws frame f (wrapped, so loops just pass an ever-growing number) of a sheet with its anchor pixel on p (local to ci) at an integer scale.
## flip mirrors it left-right about the anchor. Returns false when the sheet is missing.
static func draw(ci: Node2D, sheet: String, f: int, p: Vector2, anchor: Vector2, s := 1.0, col := Color.WHITE, flip := false) -> bool:
	var t := tex(sheet)
	if t == null:
		return false
	var fs := frame_size(sheet)
	var src := Rect2(posmod(f, FRAMES[sheet]) * fs.x, 0.0, fs.x, fs.y)
	var ax := fs.x - anchor.x if flip else anchor.x
	var tl := Pix.snap(ci, p - Vector2(ax, anchor.y) * s)
	var dst := Rect2(tl + Vector2(fs.x * s, 0.0), Vector2(-fs.x * s, fs.y * s)) if flip else Rect2(tl, fs * s)
	ci.draw_texture_rect_region(t, dst, src, col)
	return true
