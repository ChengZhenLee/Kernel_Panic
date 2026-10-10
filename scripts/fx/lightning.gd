extends Node2D
## Jagged electric arc through a list of world points.
const Pix = preload("res://scripts/fx/pix.gd")


var points := PackedVector2Array()
var color := Color(0.6, 0.9, 1.0)
var life := 0.22
var t := 0.0
var ends := []
var shape := 0
var style := ""   # "" = the plain cyan bolt (Ping.exe); "tesla" = the thick white-cyan bolt with violet halo, forks and glowing nodes (Tesla Grid)


func setup(world_points: Array) -> void:
	ends = world_points
	_build()


func _build() -> void:
	points = PackedVector2Array()
	for i in ends.size() - 1:
		var a: Vector2 = ends[i]
		var b: Vector2 = ends[i + 1]
		var normal := (b - a).orthogonal().normalized()
		for s in 6:
			var f := s / 6.0
			var jitter := 0.0 if s == 0 else randf_range(-14.0, 14.0)
			points.append(a.lerp(b, f) + normal * jitter)
	points.append(ends[-1])


func _process(delta: float) -> void:
	t += delta
	if int(t * 14.0) != shape:   # a fresh jagged shape every frame of the 14 fps flicker
		shape = int(t * 14.0)
		_build()
	if t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# 1-2 px jagged bolt: a dim wide halo, a cyan body and a white core, with a few sparks (pixel-snapped; a fresh shape every frame of the 14 fps flicker)
	var a := 1.0 - t / life
	var f := int(t * 14.0)
	if style == "tesla":
		_draw_tesla(a, f)
		return
	if style == "ping":
		_draw_ping(a, f)
		return
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(color, 0.22 * a), 4.0)
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(0.54, 0.96, 1.0, a), 2.0)
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(1, 1, 1, a), 1.0)
	for i in 8:
		var p: Vector2 = points[(i * 3 + f) % points.size()]
		Pix.dot(self, p + Vector2(Pix.rnd(i + f) - 0.5, Pix.rnd(i + f + 3) - 0.5) * 14.0, Color(0.91, 1.0, 1.0, a), 2.0)


## TESLA GRID chain: a wide violet halo, a 3 px cyan body, a 2 px white core, short forks that change every flicker frame and a bright node on every struck threat.
func _draw_tesla(a: float, f: int) -> void:
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(0.7, 0.45, 1.0, 0.28 * a), 8.0)
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(0.38, 0.88, 1.0, a), 4.0)
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(1, 1, 1, a), 2.0)
	for i in 5:
		var p: Vector2 = points[(i * 5 + f) % points.size()]
		var d := Vector2.from_angle(Pix.rnd(i + f * 3.0) * TAU) * (10.0 + Pix.rnd(i + 9.0 + f) * 16.0)
		Pix.line(self, p, p + d, Color(0.74, 0.5, 1.0, a), 2.0)
		Pix.dot(self, p + d, Color(1, 1, 1, a), 3.0)
	for e in ends:
		Pix.dot(self, e, Color(1, 1, 1, a), 6.0)
		Pix.ring(self, e, 9.0, Color(0.7, 0.45, 1.0, a * 0.8), 2.0, 60)


## PING.EXE chain: a slim white/cyan arc with little data packets (4 px squares) racing along it from you outward, and an echo node on each threat.
func _draw_ping(a: float, f: int) -> void:
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(color, 0.2 * a), 5.0)
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(0.7, 0.95, 1.0, a), 2.0)
	for i in points.size() - 1:
		Pix.line(self, points[i], points[i + 1], Color(1, 1, 1, a), 1.0)
	var run := t * 260.0
	for i in points.size() - 1:
		var seg: Vector2 = points[i + 1] - points[i]
		var seg_len := seg.length()
		if seg_len < 1.0:
			continue
		var k := fposmod(run, 26.0)
		while k < seg_len:
			Pix.dot(self, points[i] + seg * (k / seg_len), Color(1, 1, 1, a), 4.0)
			k += 26.0
	for e in ends:
		Pix.dot(self, e, Color(1, 1, 1, a), 4.0)
