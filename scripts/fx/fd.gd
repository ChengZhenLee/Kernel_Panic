extends RefCounted
## Fast replacements for the CanvasItem draw calls that cost the most per call on weak CPUs (circles, arcs, small polygons).
## draw_circle / draw_arc / draw_colored_polygon rebuild and triangulate their geometry on every call (tens to hundreds of
## microseconds each on a phone-class CPU); these reuse one cached mesh per shape and draw it with a transform, which costs a
## fraction of a microsecond. The triangles are the ones the engine itself would generate (a 64-segment fan for circles, the
## engine's mitred strip for polylines), so the output is the same pixels.

static var _circle: ArrayMesh
static var _arcs := {}   # Vector4(radius, sweep, points, width) -> ArrayMesh, built around the origin starting at angle 0


## draw_circle(pos, r, col)
static func circle(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	if _circle == null:
		_build_circle()
	ci.draw_mesh(_circle, null, Transform2D(Vector2(r, 0.0), Vector2(0.0, r), pos), col)


## draw_arc(center, r, a0, a1, points, col, width)
static func arc(ci: CanvasItem, center: Vector2, r: float, a0: float, a1: float, points: int, col: Color, width: float) -> void:
	var key := Vector4(r, a1 - a0, points, width)
	var m: ArrayMesh = _arcs.get(key)
	if m == null:
		m = _build_arc(r, a1 - a0, points, width)
		_arcs[key] = m
	ci.draw_mesh(m, null, Transform2D(a0, center), col)


## draw_arc(center, r, 0, TAU, points, col, width)
static func ring(ci: CanvasItem, center: Vector2, r: float, points: int, col: Color, width: float) -> void:
	arc(ci, center, r, 0.0, TAU, points, col, width)


## draw_colored_polygon for a CONVEX polygon (triangle, quad, hexagon...): drawn as a triangle fan, which covers the same pixels.
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n == 3:
		ci.draw_primitive(pts, PackedColorArray([col, col, col]), PackedVector2Array())
	elif n == 4:
		ci.draw_primitive(pts, PackedColorArray([col, col, col, col]), PackedVector2Array())
	elif n > 4:
		var cols := PackedColorArray([col, col, col])
		var empty := PackedVector2Array()
		for i in range(1, n - 1):
			ci.draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), cols, empty)


## An ArrayMesh with the engine's polyline triangles for pts at width w (unit-colored: tint it with the draw_mesh modulate).
static func polyline_mesh(pts: PackedVector2Array, w: float) -> ArrayMesh:
	var pc := pts.size()
	var vs := PackedVector2Array()
	vs.resize(pc * 2)
	var prev_t := Vector2.ZERO
	var t := Vector2.ZERO
	for i in pc:
		if i == pc - 1:
			t = prev_t
		else:
			t = (pts[i + 1] - pts[i]).normalized().orthogonal()
			if i == 0:
				prev_t = t
		var tangent := (t + prev_t) * (w * 0.5 / (1.0 + t.dot(prev_t)))
		vs[i] = pts[i] + tangent
		vs[i + pc] = pts[i] - tangent
		prev_t = t
	var ix := PackedInt32Array()
	ix.resize((pc - 1) * 6)
	var k := 0
	for i in pc - 1:
		ix[k] = i
		ix[k + 1] = i + pc
		ix[k + 2] = i + 1
		ix[k + 3] = i + 1
		ix[k + 4] = i + pc
		ix[k + 5] = i + pc + 1
		k += 6
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_INDEX] = ix
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _build_circle() -> void:
	var segs := 64
	var vs := PackedVector2Array()
	var ix := PackedInt32Array()
	for i in segs:
		var a := i * (TAU / segs)
		vs.append(Vector2(cos(a), sin(a)))
	vs.append(Vector2.ZERO)
	for i in segs:
		ix.append_array(PackedInt32Array([segs, i, (i + 1) % segs]))
	_circle = ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_INDEX] = ix
	_circle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


static func _build_arc(r: float, sweep: float, points: int, width: float) -> ArrayMesh:
	var p := PackedVector2Array()
	for i in points:
		var th := (i / (points - 1.0)) * sweep
		p.append(Vector2(cos(th), sin(th)) * r)
	return polyline_mesh(p, width)
