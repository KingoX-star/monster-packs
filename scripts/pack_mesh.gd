extends RefCounted
## Baut die Form eines Booster-Packs: ein flacher, leicht gewölbter Folienbeutel
## mit gezackten, gepressten Rändern oben und unten. Liegt flach in der XZ-Ebene.

const W = 0.16      # Breite (x)
const L = 0.22      # Länge des Beutels (z)
const C = 0.02      # Länge der gepressten Ränder
const B = 0.011     # Wölbung
const NX = 4
const NZ = 6


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	# Godot nutzt im Uhrzeigersinn gewickelte Vorderseiten: bei Bedarf tauschen.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b; b = c; c = t
		var tc := cb; cb = cc; cc = tc
		var tn := nb; nb = nc; nc = tn
	for v in [[a, ca, na], [b, cb, nb], [c, cc, nc]]:
		st.set_color(v[1])
		st.set_normal(n if v[2] == Vector3.ZERO else v[2])
		st.add_vertex(v[0])


static func _surface_point(i: int, j: int, side: float) -> Vector3:
	var x := lerpf(-W / 2.0, W / 2.0, float(i) / NX)
	var z := lerpf(-L / 2.0, L / 2.0, float(j) / NZ)
	var ux := 2.0 * x / W
	var uz := 2.0 * z / L
	var y := B * sqrt(maxf(0.0, 1.0 - ux * ux)) * (1.0 - pow(absf(uz), 6.0))
	return Vector3(x, y * side, z)


static func _surface_normal(p: Vector3, side: float) -> Vector3:
	return Vector3(p.x / W * 0.9 * side * side, side, p.z / L * 0.25).normalized() * Vector3(1, 1, 1)


static func _shade(p: Vector3) -> Color:
	# Mitte etwas heller, Ränder dunkler: wirkt wie glänzende Folie
	var k := 1.0 - 0.18 * absf(2.0 * p.x / W) - 0.1 * absf(2.0 * p.z / L)
	# heller Streifen für das "Logo-Feld"
	if absf(p.z) < L * 0.12:
		k += 0.12
	return Color(k, k, k)


static func build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Ober- und Unterseite des Beutels
	for side: float in [1.0, -1.0]:
		var up := Vector3(0, side, 0)
		for i in NX:
			for j in NZ:
				var p00 := _surface_point(i, j, side)
				var p10 := _surface_point(i + 1, j, side)
				var p01 := _surface_point(i, j + 1, side)
				var p11 := _surface_point(i + 1, j + 1, side)
				_add_tri(st, p00, p10, p11, up, _shade(p00), _shade(p10), _shade(p11), _surface_normal(p00, side), _surface_normal(p10, side), _surface_normal(p11, side))
				_add_tri(st, p00, p11, p01, up, _shade(p00), _shade(p11), _shade(p01), _surface_normal(p00, side), _surface_normal(p11, side), _surface_normal(p01, side))
	# Gepresste, gezackte Ränder oben und unten
	var crimp := Color(0.72, 0.72, 0.72)
	for end: float in [1.0, -1.0]:
		var z0 := end * L / 2.0
		var teeth := NX * 2
		for i in teeth:
			var x0 := lerpf(-W / 2.0, W / 2.0, float(i) / teeth)
			var x1 := lerpf(-W / 2.0, W / 2.0, float(i + 1) / teeth)
			var zo0 := z0 + end * (C if i % 2 == 0 else C - 0.006)
			var zo1 := z0 + end * (C - 0.006 if i % 2 == 0 else C)
			for side: float in [1.0, -1.0]:
				var y := 0.0012 * side
				var a := Vector3(x0, y, z0)
				var b := Vector3(x1, y, z0)
				var c := Vector3(x1, y, zo1)
				var d := Vector3(x0, y, zo0)
				var n := Vector3(0, side, 0)
				_add_tri(st, a, b, c, n, crimp, crimp, crimp)
				_add_tri(st, a, c, d, n, crimp, crimp, crimp)
	st.index()
	return st.commit()


static func material(color: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.metallic = 0.25
	m.roughness = 0.32
	m.metallic_specular = 0.6
	return m
