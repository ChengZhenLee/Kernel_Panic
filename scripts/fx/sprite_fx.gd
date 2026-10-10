extends Node2D
## A one-shot sprite-sheet effect (assets/fx/weapons/<sheet>.png): plays once at 12 fps where it is put, then frees itself.
## SpriteFx.play("packet_hit", world_pos) is all a weapon needs; it does nothing when the sheet is missing or the fx layer is crowded.

const WFx = preload("res://scripts/fx/weapon_fx.gd")

var sheet := ""
var anchor := Vector2.ZERO
var s := 1.0
var rot := 0.0
var col := Color.WHITE
var t := 0.0


## Starts a one-shot at a world position. scale: whole numbers keep the pixels square. anchor defaults to the frame centre.
static func play(sheet_name: String, pos: Vector2, scale := 1.0, rotation := 0.0, z := 4, tint := Color.WHITE, anchor_px := Vector2(-1, -1)):
	var g = Global.game
	if g == null or not WFx.has(sheet_name):
		return null
	if g.fx_layer.get_child_count() > (70 if Global.low_fx else 140):
		return null
	var f := new()
	f.sheet = sheet_name
	f.anchor = anchor_px if anchor_px.x >= 0.0 else WFx.frame_size(sheet_name) * 0.5
	f.s = scale
	f.rot = rotation
	f.col = tint
	f.z_index = z
	f.position = pos
	g.fx_layer.add_child(f)
	return f


func _process(delta: float) -> void:
	t += delta
	if int(t * WFx.FPS) >= WFx.FRAMES[sheet]:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	WFx.draw(self, sheet, int(t * WFx.FPS), Vector2.ZERO, anchor, s, col)
