extends Node3D
## Der Pack-Berg: genau TOTAL Packs liegen von Anfang an bereit und werden beim
## Öffnen weniger. Der Berg ist in Zellen aufgeteilt; jede Zelle ist ein Stapel.
## Gezeichnet werden nur die obersten Packs jeder Zelle, die anderen liegen
## verdeckt darunter und rücken nach, wenn oben welche weggenommen werden.

const PackMesh = preload("res://scripts/pack_mesh.gd")

const TOTAL = 100000
const CELL = 0.5
const RADIUS = 6.8
const HEIGHT = 3.4
const VISIBLE_PER_CELL = 36
const COLORS = [
	Color(0.92, 0.22, 0.28), Color(0.2, 0.45, 0.95), Color(1.0, 0.76, 0.18),
	Color(0.32, 0.78, 0.36), Color(0.66, 0.3, 0.92), Color(0.15, 0.78, 0.84),
	Color(0.98, 0.5, 0.15),
]

var n := 0
var counts := PackedInt32Array()
var step := PackedFloat32Array()
var slot_base := PackedInt32Array()
var slot_count := PackedInt32Array()
var remaining := 0
var mm: MultiMesh
var hm: HeightMapShape3D
var fill: MeshInstance3D
var fill_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func setup(saved: PackedInt32Array) -> void:
	n = int(ceil(RADIUS * 2.0 / CELL)) + 3
	var cells := n * n
	counts.resize(cells)
	step.resize(cells)
	slot_base.resize(cells)
	slot_count.resize(cells)

	# Form des Bergs: weicher Hügel, Packs proportional zur Höhe verteilt
	var weights := PackedFloat32Array()
	weights.resize(cells)
	var total_w := 0.0
	for c in cells:
		var p := cell_center(c)
		var d := Vector2(p.x, p.z).length() / RADIUS
		var w := 0.0
		if d < 1.0:
			w = pow(1.0 - d * d, 1.3)
		weights[c] = w
		total_w += w
	var assigned := 0
	for c in cells:
		counts[c] = int(floor(TOTAL * weights[c] / total_w))
		assigned += counts[c]
	# Rest auf die höchsten Zellen verteilen, damit es genau TOTAL sind
	var order: Array = range(cells)
	order.sort_custom(func(a, b): return weights[a] > weights[b])
	var k := 0
	while assigned < TOTAL:
		counts[order[k % cells]] += 1
		assigned += 1
		k += 1
	for c in cells:
		step[c] = (HEIGHT * weights[c] / counts[c]) if counts[c] > 0 else 0.0

	# Sichtbare Plätze pro Zelle anlegen
	var total_slots := 0
	for c in cells:
		slot_base[c] = total_slots
		slot_count[c] = mini(VISIBLE_PER_CELL, counts[c])
		total_slots += slot_count[c]

	if saved.size() == cells:
		for c in cells:
			counts[c] = clampi(saved[c], 0, counts[c])

	remaining = 0
	for c in cells:
		remaining += counts[c]

	var mesh := PackMesh.build()
	mesh.surface_set_material(0, PackMesh.material())
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = total_slots
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	for c in cells:
		_update_cell(c)

	# Gefüllter Kern unter den sichtbaren Packs, damit keine Lücken zum Boden entstehen
	fill_mat = StandardMaterial3D.new()
	fill_mat.vertex_color_use_as_albedo = true
	fill_mat.roughness = 1.0
	fill_mat.metallic = 0.0
	fill_mat.metallic_specular = 0.1
	fill = MeshInstance3D.new()
	fill.material_override = fill_mat
	add_child(fill)
	_rebuild_fill()

	# Begehbare Kollision als Höhenfeld (Layer 1 = Boden, 2 = Blickziel)
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 2
	body.collision_mask = 0
	body.set_meta("kind", "pile")
	var col := CollisionShape3D.new()
	hm = HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	col.shape = hm
	col.scale = Vector3(CELL, CELL, CELL)
	body.add_child(col)
	add_child(body)
	_update_heightmap()


func cell_center(c: int) -> Vector3:
	var gx := c % n
	var gz := c / n
	return Vector3((gx - (n - 1) / 2.0) * CELL, 0.0, (gz - (n - 1) / 2.0) * CELL)


func top_height(c: int) -> float:
	return counts[c] * step[c]


func _pack_transform(c: int, i: int) -> Transform3D:
	_rng.seed = c * 1000003 + i * 7919 + 17
	var p := cell_center(c)
	p.x += _rng.randf_range(-CELL * 0.55, CELL * 0.55)
	p.z += _rng.randf_range(-CELL * 0.55, CELL * 0.55)
	p.y = (i + 0.5) * step[c] + 0.012
	var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf() * TAU, _rng.randf_range(-0.35, 0.35)))
	return Transform3D(basis, p)


func _pack_color(c: int, i: int) -> Color:
	_rng.seed = c * 1000003 + i * 7919 + 17
	for _k in 5:
		_rng.randf()
	return COLORS[_rng.randi() % COLORS.size()]


func _update_cell(c: int) -> void:
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -10, 0))
	for j in slot_count[c]:
		var idx := counts[c] - 1 - j
		var slot := slot_base[c] + j
		if idx >= 0:
			mm.set_instance_transform(slot, _pack_transform(c, idx))
			mm.set_instance_color(slot, _pack_color(c, idx))
		else:
			mm.set_instance_transform(slot, hidden)


func _fill_height(gx: int, gz: int) -> float:
	if gx < 0 or gz < 0 or gx >= n or gz >= n:
		return 0.0
	var c := gz * n + gx
	return maxf(0.0, top_height(c) - 0.1)


func _rebuild_fill() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := (n - 1) / 2.0
	for gz in n - 1:
		for gx in n - 1:
			var hs := [_fill_height(gx, gz), _fill_height(gx + 1, gz), _fill_height(gx, gz + 1), _fill_height(gx + 1, gz + 1)]
			if hs[0] + hs[1] + hs[2] + hs[3] <= 0.0:
				continue
			var pts: Array = []
			var nrm: Array = []
			var cols: Array = []
			for k in 4:
				var x := gx + (k % 2)
				var z := gz + (k / 2)
				pts.append(Vector3((x - half) * CELL, hs[k], (z - half) * CELL))
				nrm.append(Vector3(_fill_height(x - 1, z) - _fill_height(x + 1, z), 2.0 * CELL, _fill_height(x, z - 1) - _fill_height(x, z + 1)).normalized())
				_rng.seed = x * 92821 + z * 68917
				cols.append(Color(0.24, 0.22, 0.3).lerp(COLORS[_rng.randi() % COLORS.size()], 0.25))
			for tri in [[0, 1, 3], [0, 3, 2]]:
				var a: Vector3 = pts[tri[0]]
				var b: Vector3 = pts[tri[1]]
				var c: Vector3 = pts[tri[2]]
				var order: Array = tri
				if (b - a).cross(c - a).dot(Vector3.UP) > 0.0:
					order = [tri[0], tri[2], tri[1]]
				for k in order:
					st.set_color(cols[k])
					st.set_normal(nrm[k])
					st.add_vertex(pts[k])
	fill.mesh = st.commit()


func _update_heightmap() -> void:
	var data := PackedFloat32Array()
	data.resize(n * n)
	for c in n * n:
		data[c] = top_height(c) / CELL
	hm.map_data = data


func _cell_at(local: Vector3) -> Vector2i:
	return Vector2i(roundi(local.x / CELL + (n - 1) / 2.0), roundi(local.z / CELL + (n - 1) / 2.0))


func _best_cell(g: Vector2i) -> int:
	# In wachsenden Ringen den höchsten nicht leeren Stapel suchen
	for r in [0, 1, 2, 3, 5]:
		var best := -1
		var best_h := -1.0
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := g.x + dx
				var z := g.y + dz
				if x < 0 or z < 0 or x >= n or z >= n:
					continue
				var c := z * n + x
				if counts[c] > 0 and top_height(c) > best_h:
					best_h = top_height(c)
					best = c
		if best >= 0:
			return best
	return -1


## Nimmt bis zu `amount` Packs nahe `world_point` weg und gibt zurück, wie viele es waren.
func take(world_point: Vector3, amount: int) -> int:
	var g := _cell_at(to_local(world_point))
	var dirty := {}
	var taken := 0
	for _i in amount:
		var c := _best_cell(g)
		if c < 0:
			break
		counts[c] -= 1
		dirty[c] = true
		taken += 1
	for c in dirty:
		_update_cell(c)
	if taken > 0:
		remaining -= taken
		_update_heightmap()
		_rebuild_fill()
	return taken
