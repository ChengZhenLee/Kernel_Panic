extends Control
## Jackpot backdrop for a LEGENDARY upgrade offer (a full-screen layer behind the cards): columns of golden pixel code (3x5 glyphs, 2 px cells) falling behind the card text, with
## a bright head on every column and a slow diagonal shimmer sweeping across. Whole-pixel rects only; Global.low_fx trims the columns.

const GLYPHS := [   # 3x5 bitmasks, rows top to bottom (bit 2 = left)
	[7, 5, 5, 5, 7], [2, 6, 2, 2, 7], [7, 1, 7, 4, 7], [7, 1, 7, 1, 7], [5, 5, 7, 1, 1], [7, 4, 7, 1, 7], [7, 4, 7, 5, 7], [7, 1, 2, 2, 2],
]
const GOLD := Color(1.0, 0.8, 0.2)

var cell := 2.0   # px per glyph cell: bigger for a full-screen backdrop
var cols := 0
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols = 8 if Global.low_fx else maxi(11, int(size.x / (cell * 14.0)))


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var gh := 6.0 * cell + 2.0 * cell
	var spacing := w / cols
	for c in cols:
		var speed := 38.0 + 55.0 * fposmod(sin(c * 12.9898) * 43758.5, 1.0)
		var off := fposmod(sin(c * 78.233) * 43758.5, 1.0) * h
		var x := roundf(c * spacing + (spacing - 3.0 * cell) * 0.5)
		var head := fposmod(t * speed + off, h + gh * 8.0)   # y of the bright head glyph
		for i in 8:   # the head plus a fading trail of 7 glyphs above it
			var y := roundf(head - i * gh) - gh
			if y < -gh or y > h:
				continue
			var a := (1.0 - i / 8.0) * 0.55
			var col := Color(1.0, 0.97, 0.75, 0.9) if i == 0 else Color(GOLD, a)
			var g: Array = GLYPHS[int(floor(t * 3.0 + c * 5.0 + i * 3.0)) % GLYPHS.size()]
			for row in 5:
				for bit in 3:
					if (g[row] >> (2 - bit)) & 1:
						draw_rect(Rect2(x + bit * cell, y + row * cell, cell, cell), col)
	var sx := fposmod(t * 0.35, 1.6) * (w + h) - h   # a diagonal shimmer band
	for s in 3:
		var x0 := sx + s * 14.0
		var pts := PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + 10.0, 0.0), Vector2(x0 + 10.0 - h * 0.6, h), Vector2(x0 - h * 0.6, h)])
		draw_colored_polygon(pts, Color(1.0, 0.95, 0.7, 0.14 if s == 1 else 0.08))
