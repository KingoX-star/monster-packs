extends Node3D
## Hauptskript des Prototyps: baut Halle, Pack-Berg, Laden und HUD per Code
## und enthält den Kern-Loop: Pack öffnen -> Monster -> Laden -> Gadgets.

const MonsterGen = preload("res://scripts/monster_gen.gd")
const MonsterCard = preload("res://scripts/monster_card.gd")
const PlayerScript = preload("res://scripts/player.gd")

const SAVE_PATH = "user://save.cfg"
const PackPileScript = preload("res://scripts/pack_pile.gd")
const PackMeshScript = preload("res://scripts/pack_mesh.gd")
const PILE_CENTER = Vector3(0, 0, -4)
const STORE_POS = Vector3(14.5, 0, -4)
const SHOP_POS = Vector3(11.6, 0, -4)
const REACH = 7.0
const ALBUM_BONUS_PER_ENTRY = 0.03

const GADGETS = [
	{"id": "finger", "name": "Schnelle Finger", "desc": "1 Klick weniger pro Pack", "base": 25, "mult": 1.9, "max": 5},
	{"id": "knife", "name": "Reißmesser", "desc": "Maustaste halten reißt automatisch", "base": 120, "mult": 2.1, "max": 5},
	{"id": "bag", "name": "Größerer Rucksack", "desc": "+20 Platz im Rucksack", "base": 300, "mult": 1.7, "max": 10},
	{"id": "shovel", "name": "Pack-Schaufel", "desc": "+1 Pack pro Öffnen", "base": 800, "mult": 2.2, "max": 5},
	{"id": "lens", "name": "Glückslupe", "desc": "+20 % Chance auf Selten und besser", "base": 2000, "mult": 2.0, "max": 5},
]


# --- Spielstand ---
var coins := 0
var bag: Array = []
var packs_opened := 0
var album := {}
var levels := {}

# --- Laufzeit ---
var rng := RandomNumberGenerator.new()
var player  # player.gd (CharacterBody3D)
var hand_pack: MeshInstance3D
var rip_progress := 0.0
var flow := 0.0
var flow_idle := 0.0
var looking_at := ""
var shop_open := false
var album_open := false
var pile  # pack_pile.gd
var saved_pile := PackedInt32Array()
var look_point := Vector3.ZERO

# --- HUD ---
var lbl_coins: Label
var lbl_stats: Label
var lbl_prompt: Label
var lbl_toast: Label
var lbl_big: Label
var bar_rip: ProgressBar
var bar_bag: ProgressBar
var lbl_bag: Label
var bar_flow: ProgressBar
var lbl_flow: Label
var reveal_box: HBoxContainer
var lbl_more: Label
var flash: ColorRect
var shop_panel: PanelContainer
var shop_rows: VBoxContainer
var shop_coins: Label
var album_panel: PanelContainer
var album_grid: GridContainer
var album_title: Label
var toast_tween: Tween
var reveal_tween: Tween


func _ready() -> void:
	rng.randomize()
	for g in GADGETS:
		levels[g["id"]] = 0
	_setup_input()
	load_game()
	_build_world()
	_build_player()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_hud()
	toast("Schau auf den Pack-Berg und klicke, um Packs aufzureißen!")


# ------------------------------------------------------------------ Eingabe

func _add_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	_add_key("move_forward", [KEY_W, KEY_UP])
	_add_key("move_back", [KEY_S, KEY_DOWN])
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("jump", [KEY_SPACE])
	_add_key("sprint", [KEY_SHIFT])
	_add_key("interact", [KEY_E])
	_add_key("album", [KEY_TAB])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if shop_open:
				_close_shop()
			elif album_open:
				_toggle_album()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return
		if event.is_action("interact"):
			if shop_open:
				_close_shop()
			elif looking_at == "shop":
				_sell_and_open_shop()
			return
		if event.is_action("album") and not shop_open:
			_toggle_album()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if shop_open or album_open:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if looking_at == "pile":
			_add_rip(1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ------------------------------------------------------------------ Werte

func clicks_needed() -> float:
	return float(maxi(1, 6 - levels["finger"]))

func bag_capacity() -> int:
	return 10 + 20 * levels["bag"]

func packs_per_open() -> int:
	return 1 + levels["shovel"]

func luck() -> float:
	return 0.2 * levels["lens"]

func knife_rate() -> float:
	return 2.0 * levels["knife"]

func album_multiplier() -> float:
	return 1.0 + ALBUM_BONUS_PER_ENTRY * album.size()

func gadget_price(g: Dictionary) -> int:
	return int(round(g["base"] * pow(g["mult"], levels[g["id"]])))

func fmt(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ------------------------------------------------------------------ Loop

func _process(delta: float) -> void:
	_update_look()

	# Reißmesser: Halten reißt automatisch
	if levels["knife"] > 0 and looking_at == "pile" and not shop_open and not album_open \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_add_rip(knife_rate() * delta)

	# Flow baut sich ab, wenn man pausiert
	flow_idle += delta
	if flow_idle > 2.0:
		flow = maxf(0.0, flow - delta * 0.25)

	# Pack in der Hand wackelt mit dem Fortschritt
	if hand_pack:
		var k := rip_progress / clicks_needed()
		hand_pack.rotation = Vector3(PI / 2.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08 * k, 0.35, sin(Time.get_ticks_msec() * 0.05) * 0.1 * k)
		hand_pack.visible = looking_at == "pile"

	_refresh_hud()


func _update_look() -> void:
	looking_at = ""
	if shop_open or album_open:
		return
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 2 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit["collider"]
	if col.has_meta("kind"):
		var kind: String = col.get_meta("kind")
		if kind == "shop" and from.distance_to(hit["position"]) > 3.5:
			return
		looking_at = kind
		look_point = hit["position"]


func _add_rip(amount: float) -> void:
	if pile.remaining <= 0:
		toast("Alle 100.000 Packs sind geöffnet!")
		return
	if bag.size() + MonsterGen.CARDS_PER_PACK > bag_capacity():
		toast("Rucksack voll! Bring die Monster zum Laden (E).")
		return
	rip_progress += amount * (1.0 + 0.5 * flow)
	if rip_progress >= clicks_needed():
		rip_progress -= clicks_needed()
		rip_progress = minf(rip_progress, clicks_needed() * 0.99)
		_open_packs()


func _open_packs() -> void:
	var free := bag_capacity() - bag.size()
	var count := mini(packs_per_open(), free / MonsterGen.CARDS_PER_PACK)
	if count <= 0:
		return
	count = pile.take(look_point, count)
	if count <= 0:
		toast("Hier liegen keine Packs mehr – geh näher an den Berg.")
		return
	var cards: Array = []
	var news := {}
	for p in count:
		for i in MonsterGen.CARDS_PER_PACK:
			var m := MonsterGen.generate(rng, luck())
			var key := MonsterGen.album_key(m)
			if not album.has(key):
				album[key] = m
				news[cards.size()] = true
			else:
				if m["rarity"] > album[key]["rarity"] or (m["shiny"] and not album[key]["shiny"]):
					album[key] = m
				bag.append(m)
			cards.append(m)
	packs_opened += count
	flow = minf(1.0, flow + 0.08)
	flow_idle = 0.0
	_show_reveal(cards, news)
	_burst_at_hand(cards)


func _sell_and_open_shop() -> void:
	if bag.size() > 0:
		var total := 0
		for m in bag:
			total += int(m["value"])
		total = int(round(total * album_multiplier()))
		coins += total
		_floating_text("+" + fmt(total) + " Münzen", SHOP_POS + Vector3(-0.6, 2.0, 0))
		toast("%d Monster abgegeben für %s Münzen" % [bag.size(), fmt(total)])
		bag.clear()
		save_game()
	_open_shop()


# ------------------------------------------------------------------ Welt

func _mat(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, collide := true, layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		col.shape = sh
		body.add_child(col)
		body.collision_layer = layer
	else:
		body.collision_layer = 0
	add_child(body)
	return body


func _invisible_wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)
	add_child(body)


func _build_world() -> void:
	# Himmel, Sonne, Nebel
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.88)
	sky_mat.sky_horizon_color = Color(0.72, 0.82, 0.9)
	sky_mat.ground_horizon_color = Color(0.5, 0.6, 0.5)
	sky_mat.ground_bottom_color = Color(0.2, 0.28, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.85)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	_build_ground()
	_build_forest()
	_build_store()

	pile = PackPileScript.new()
	pile.position = PILE_CENTER
	add_child(pile)
	pile.setup(saved_pile)


func _build_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.33, 0.12))
	grad.set_color(1, Color(0.3, 0.48, 0.18))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	var grass := StandardMaterial3D.new()
	grass.albedo_texture = tex
	grass.uv1_scale = Vector3(30, 30, 30)
	grass.roughness = 0.95
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	ground.mesh = plane
	ground.material_override = grass
	add_child(ground)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(300, 1, 300)
	col.shape = sh
	col.position.y = -0.5
	body.add_child(col)
	add_child(body)

	# Erdfläche unter dem Berg und Weg zum Store
	var dirt := _mat(Color(0.42, 0.32, 0.2), 1.0)
	var disk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = PackPileScript.RADIUS + 1.5
	cyl.bottom_radius = PackPileScript.RADIUS + 1.5
	cyl.height = 0.02
	disk.mesh = cyl
	disk.material_override = dirt
	disk.position = PILE_CENTER + Vector3(0, 0.01, 0)
	add_child(disk)
	_box(Vector3(STORE_POS.x - PILE_CENTER.x - PackPileScript.RADIUS, 0.02, 2.2), Vector3((PILE_CENTER.x + PackPileScript.RADIUS + STORE_POS.x) / 2.0, 0.01, STORE_POS.z), dirt, false)

	# Grasbüschel
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.035
	tuft.height = 0.28
	tuft.radial_segments = 4
	var tmat := StandardMaterial3D.new()
	tmat.vertex_color_use_as_albedo = true
	tmat.roughness = 1.0
	tuft.material = tmat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft
	mm.instance_count = 9000
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(PackPileScript.RADIUS + 2.0, 45.0)
		var p := PILE_CENTER + Vector3(cos(a) * r, 0.12, sin(a) * r)
		var s := rng.randf_range(0.6, 1.4)
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))).scaled(Vector3(s, s, s)), p))
		mm.set_instance_color(i, Color(0.18, 0.36, 0.12).lerp(Color(0.36, 0.52, 0.2), rng.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _tree_multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mm


func _build_forest() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.28
	trunk.height = 3.0
	trunk.radial_segments = 8
	var cone_low := CylinderMesh.new()
	cone_low.top_radius = 0.0
	cone_low.bottom_radius = 1.8
	cone_low.height = 3.6
	cone_low.radial_segments = 10
	var cone_high := CylinderMesh.new()
	cone_high.top_radius = 0.0
	cone_high.bottom_radius = 1.25
	cone_high.height = 2.8
	cone_high.radial_segments = 10
	var leaf := SphereMesh.new()
	leaf.radius = 1.7
	leaf.height = 3.0
	leaf.radial_segments = 12
	leaf.rings = 6

	# Bäume rund um die Lichtung, dichter je weiter draußen
	var spots: Array = []
	var tries := 0
	while spots.size() < 520 and tries < 5000:
		tries += 1
		var a := rng.randf() * TAU
		var r := 19.0 + pow(rng.randf(), 0.7) * 60.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r) + Vector3(PILE_CENTER.x, 0, PILE_CENTER.z)
		if p.distance_to(STORE_POS) < 9.0:
			continue
		spots.append(p)

	var trunks := _tree_multimesh(trunk, spots.size())
	var lows := _tree_multimesh(cone_low, spots.size())
	var highs := _tree_multimesh(cone_high, spots.size())
	var leaves := _tree_multimesh(leaf, spots.size())
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -50, 0))
	for i in spots.size():
		var p: Vector3 = spots[i]
		var s := rng.randf_range(0.8, 1.5)
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		var sb := yaw.scaled(Vector3(s, s, s))
		trunks.set_instance_transform(i, Transform3D(sb, p + Vector3(0, 1.5 * s, 0)))
		trunks.set_instance_color(i, Color(0.36, 0.24, 0.15).lerp(Color(0.45, 0.32, 0.2), rng.randf()))
		if rng.randf() < 0.7:
			# Tanne
			var g := Color(0.12, 0.3, 0.14).lerp(Color(0.2, 0.42, 0.18), rng.randf())
			lows.set_instance_transform(i, Transform3D(sb, p + Vector3(0, 3.6 * s, 0)))
			lows.set_instance_color(i, g)
			highs.set_instance_transform(i, Transform3D(sb, p + Vector3(0, 5.4 * s, 0)))
			highs.set_instance_color(i, g.lightened(0.08))
			leaves.set_instance_transform(i, hidden)
		else:
			# Laubbaum
			lows.set_instance_transform(i, hidden)
			highs.set_instance_transform(i, hidden)
			leaves.set_instance_transform(i, Transform3D(sb, p + Vector3(0, 3.9 * s, 0)))
			leaves.set_instance_color(i, Color(0.25, 0.48, 0.15).lerp(Color(0.45, 0.6, 0.2), rng.randf()))
		if p.distance_to(PILE_CENTER) < 40.0:
			var body := StaticBody3D.new()
			body.position = p + Vector3(0, 1.5, 0)
			var col := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.3 * s
			sh.height = 3.0
			col.shape = sh
			body.add_child(col)
			add_child(body)

	# Felsen
	var rock := SphereMesh.new()
	rock.radius = 0.6
	rock.height = 0.8
	rock.radial_segments = 7
	rock.rings = 4
	var rocks := _tree_multimesh(rock, 40)
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12.0, 30.0)
		var p := PILE_CENTER + Vector3(cos(a) * r, 0.1, sin(a) * r)
		if p.distance_to(STORE_POS) < 7.0:
			p += Vector3(0, -5, 0)
		var s := rng.randf_range(0.6, 1.8)
		rocks.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), p))
		rocks.set_instance_color(i, Color(0.45, 0.45, 0.43).lerp(Color(0.6, 0.58, 0.55), rng.randf()))

	# Unsichtbare Grenze, damit man nicht ewig in den Wald läuft
	for k in 24:
		var a := TAU * k / 24.0
		var wall := StaticBody3D.new()
		wall.position = PILE_CENTER + Vector3(cos(a) * 42.0, 2.0, sin(a) * 42.0)
		wall.rotation.y = -a
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1, 4, 12)
		col.shape = sh
		wall.add_child(col)
		add_child(wall)


func _build_store() -> void:
	# Holzhütte, Vorderseite zeigt zum Pack-Berg (Richtung -x)
	var s := STORE_POS
	var wood := _mat(Color(0.55, 0.36, 0.2), 0.85)
	var dark_wood := _mat(Color(0.36, 0.22, 0.12), 0.85)
	var roof_mat := _mat(Color(0.62, 0.18, 0.15), 0.7)
	var w := 7.0
	var d := 4.5
	var h := 3.2
	_box(Vector3(d + 1.0, 0.2, w + 1.0), s + Vector3(0, 0.1, 0), dark_wood)
	_box(Vector3(0.2, h, w), s + Vector3(d / 2.0, h / 2.0, 0), wood)
	_box(Vector3(d, h, 0.2), s + Vector3(0, h / 2.0, w / 2.0), wood)
	_box(Vector3(d, h, 0.2), s + Vector3(0, h / 2.0, -w / 2.0), wood)
	_box(Vector3(0.25, 0.7, w), s + Vector3(-d / 2.0, h - 0.35, 0), dark_wood)
	for z in [-w / 2.0, w / 2.0]:
		_box(Vector3(0.25, h, 0.25), s + Vector3(-d / 2.0, h / 2.0, z), dark_wood)
	var roof := _box(Vector3(d + 1.8, 0.18, w + 1.0), s + Vector3(-0.2, h + 0.35, 0), roof_mat, false)
	roof.rotation_degrees = Vector3(0, 0, 9)

	# Tresen = Laden-Interaktion
	var counter := _box(Vector3(0.9, 1.1, w - 1.0), SHOP_POS + Vector3(0, 0.55, 0), wood, true, 1 | 4)
	counter.set_meta("kind", "shop")
	_box(Vector3(1.1, 0.08, w - 0.8), SHOP_POS + Vector3(0, 1.14, 0), _mat(Color(0.85, 0.8, 0.7), 0.5), false)

	# Regal mit ausgestellten Packs an der Rückwand
	_box(Vector3(0.4, 0.06, w - 1.2), s + Vector3(d / 2.0 - 0.3, 1.4, 0), dark_wood, false)
	_box(Vector3(0.4, 0.06, w - 1.2), s + Vector3(d / 2.0 - 0.3, 2.1, 0), dark_wood, false)
	var pmesh := PackMeshScript.build()
	for row in 2:
		for k in 9:
			var pk := MeshInstance3D.new()
			pk.mesh = pmesh
			pk.material_override = PackMeshScript.material(PackPileScript.COLORS[(k + row * 3) % PackPileScript.COLORS.size()])
			pk.scale = Vector3(1.6, 1.6, 1.6)
			pk.position = s + Vector3(d / 2.0 - 0.3, 1.4 + 0.7 * row + 0.17, -2.6 + k * 0.65)
			pk.rotation_degrees = Vector3(-90, 0, 0)
			pk.rotate_y(-PI / 2.0)
			add_child(pk)

	var lamp := OmniLight3D.new()
	lamp.position = s + Vector3(0, h - 0.6, 0)
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.4
	lamp.omni_range = 7.0
	add_child(lamp)

	var store_sign := Label3D.new()
	store_sign.text = "PACK STORE"
	store_sign.font_size = 120
	store_sign.outline_size = 22
	store_sign.modulate = Color(1.0, 0.85, 0.3)
	store_sign.position = s + Vector3(-d / 2.0 - 0.15, h + 1.1, 0)
	store_sign.rotation_degrees = Vector3(0, -90, 0)
	add_child(store_sign)
	var sub := Label3D.new()
	sub.text = "Monster abgeben · Gadgets kaufen"
	sub.font_size = 40
	sub.outline_size = 10
	sub.position = s + Vector3(-d / 2.0 - 0.15, h - 0.35, 0)
	sub.rotation_degrees = Vector3(0, -90, 0)
	add_child(sub)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.position = Vector3(3, 0.1, 10)
	player.rotation.y = 0.22
	add_child(player)
	hand_pack = MeshInstance3D.new()
	hand_pack.mesh = PackMeshScript.build()
	hand_pack.scale = Vector3(1.3, 1.3, 1.3)
	hand_pack.material_override = PackMeshScript.material(PackPileScript.COLORS[0])
	player.hand.add_child(hand_pack)


func _burst_at_hand(cards: Array) -> void:
	var best := 0
	for m in cards:
		best = maxi(best, int(m["rarity"]))
	var color: Color = MonsterGen.RARITIES[best]["color"]
	var p := CPUParticles3D.new()
	var qm := BoxMesh.new()
	qm.size = Vector3(0.03, 0.03, 0.005)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = mat
	p.mesh = qm
	p.amount = 20 + 15 * best
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5 + best
	p.gravity = Vector3(0, -6, 0)
	p.color = color
	add_child(p)
	p.global_position = player.hand.global_position
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	hand_pack.material_override = PackMeshScript.material(PackPileScript.COLORS[rng.randi() % PackPileScript.COLORS.size()])
	if best >= 3:
		player.shake = 0.6 + 0.4 * (best - 3)
		_flash(color, best)


func _floating_text(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.outline_size = 14
	l.modulate = Color(1.0, 0.85, 0.3)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(0, 1.5, 0), 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------------ HUD

func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(int(h / 2))
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(int(h / 2))
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.14, 0.95)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(1.0, 0.8, 0.3)
	sb.set_border_width_all(3)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	return sb


func _place(c: Control, preset: int, ox: float, oy: float, w: float, h: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = ox
	c.offset_top = oy
	c.offset_right = ox + w
	c.offset_bottom = oy + h


func _center(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	lbl_coins = _label("", 40, Color(1.0, 0.85, 0.3))
	lbl_coins.position = Vector2(28, 18)
	root.add_child(lbl_coins)

	lbl_stats = _label("", 20)
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(lbl_stats, Control.PRESET_TOP_RIGHT, -428, 22, 400, 90)
	root.add_child(lbl_stats)

	var cross := _label("+", 30)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(cross, Control.PRESET_CENTER, -20, -22, 40, 40)
	root.add_child(cross)

	bar_rip = _bar(Color(1.0, 0.45, 0.5), 160, 10)
	_place(bar_rip, Control.PRESET_CENTER, -80, 26, 160, 10)
	root.add_child(bar_rip)

	lbl_prompt = _label("", 22)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(lbl_prompt, Control.PRESET_CENTER, -400, 44, 800, 30)
	root.add_child(lbl_prompt)

	lbl_big = _label("", 72)
	lbl_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(lbl_big, Control.PRESET_CENTER_TOP, -500, 120, 1000, 90)
	lbl_big.modulate.a = 0.0
	root.add_child(lbl_big)

	lbl_toast = _label("", 22, Color(1, 1, 0.85))
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(lbl_toast, Control.PRESET_CENTER_TOP, -500, 80, 1000, 30)
	root.add_child(lbl_toast)

	# Unten: Rucksack und Flow
	var bottom := VBoxContainer.new()
	_place(bottom, Control.PRESET_CENTER_BOTTOM, -180, -100, 360, 84)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	lbl_bag = _label("", 18)
	bottom.add_child(lbl_bag)
	bar_bag = _bar(Color(0.4, 0.75, 1.0), 360, 16)
	bottom.add_child(bar_bag)
	lbl_flow = _label("", 15, Color(1, 0.75, 0.4))
	bottom.add_child(lbl_flow)
	bar_flow = _bar(Color(1.0, 0.6, 0.2), 360, 8)
	bottom.add_child(bar_flow)

	var help := _label("WASD laufen · Maus umsehen · Linksklick Pack aufreißen\nE Laden · Tab Album · Esc Maus freigeben", 15, Color(1, 1, 1, 0.7))
	_place(help, Control.PRESET_TOP_LEFT, 30, 74, 600, 48)
	root.add_child(help)

	# Karten-Enthüllung
	reveal_box = HBoxContainer.new()
	reveal_box.add_theme_constant_override("separation", 16)
	reveal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(reveal_box, Control.PRESET_CENTER, -510, -335, 1020, 270)
	reveal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reveal_box)
	lbl_more = _label("", 20)
	lbl_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(lbl_more, Control.PRESET_CENTER, -300, -58, 600, 30)
	root.add_child(lbl_more)

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	_build_shop_ui(root)
	_build_album_ui(root)


func _build_shop_ui(root: Control) -> void:
	shop_panel = PanelContainer.new()
	shop_panel.add_theme_stylebox_override("panel", _panel_style())
	shop_panel.custom_minimum_size = Vector2(760, 0)
	shop_panel.visible = false
	root.add_child(shop_panel)
	_center(shop_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	shop_panel.add_child(v)
	v.add_child(_label("LADEN – Gadgets", 34, Color(0.5, 0.95, 1.0)))
	shop_coins = _label("", 22, Color(1.0, 0.85, 0.3))
	v.add_child(shop_coins)
	shop_rows = VBoxContainer.new()
	shop_rows.add_theme_constant_override("separation", 8)
	v.add_child(shop_rows)
	var close := Button.new()
	close.text = "Schließen (E)"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_shop)
	v.add_child(close)


func _rebuild_shop_rows() -> void:
	for c in shop_rows.get_children():
		c.queue_free()
	shop_coins.text = "Münzen: %s   ·   Album-Bonus: +%d %% Verkaufswert" % [fmt(coins), int(round((album_multiplier() - 1.0) * 100))]
	for g in GADGETS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lvl: int = levels[g["id"]]
		info.add_child(_label("%s   (Stufe %d/%d)" % [g["name"], lvl, g["max"]], 22))
		info.add_child(_label(g["desc"], 16, Color(1, 1, 1, 0.7)))
		row.add_child(info)
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 52)
		b.add_theme_font_size_override("font_size", 20)
		if lvl >= int(g["max"]):
			b.text = "Maximal"
			b.disabled = true
		else:
			var price := gadget_price(g)
			b.text = "Kaufen: %s" % fmt(price)
			b.disabled = coins < price
			b.pressed.connect(_buy.bind(g["id"]))
		row.add_child(b)
		shop_rows.add_child(row)


func _buy(id: String) -> void:
	for g in GADGETS:
		if g["id"] == id:
			var price := gadget_price(g)
			if coins >= price and levels[id] < int(g["max"]):
				coins -= price
				levels[id] += 1
				save_game()
				toast("%s gekauft!" % g["name"])
	_rebuild_shop_rows()


func _open_shop() -> void:
	shop_open = true
	shop_panel.visible = true
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild_shop_rows()


func _close_shop() -> void:
	shop_open = false
	shop_panel.visible = false
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_album_ui(root: Control) -> void:
	album_panel = PanelContainer.new()
	album_panel.add_theme_stylebox_override("panel", _panel_style())
	album_panel.visible = false
	root.add_child(album_panel)
	_center(album_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	album_panel.add_child(v)
	album_title = _label("", 30, Color(1.0, 0.85, 0.3))
	v.add_child(album_title)
	album_grid = GridContainer.new()
	album_grid.columns = MonsterGen.BODIES.size()
	album_grid.add_theme_constant_override("h_separation", 12)
	album_grid.add_theme_constant_override("v_separation", 12)
	v.add_child(album_grid)
	v.add_child(_label("Spalten: Körperform · Zeilen: Element · jedes Monster im Album gibt +3 % Verkaufswert", 15, Color(1, 1, 1, 0.7)))


func _toggle_album() -> void:
	album_open = not album_open
	album_panel.visible = album_open
	player.input_enabled = not album_open
	if not album_open:
		return
	for c in album_grid.get_children():
		c.queue_free()
	album_title.text = "Album  %d / %d" % [album.size(), MonsterGen.album_size()]
	var sc := 0.56
	for e in MonsterGen.ELEMENTS.size():
		for b in MonsterGen.BODIES.size():
			var slot := Control.new()
			slot.custom_minimum_size = MonsterCard.CARD_SIZE * sc
			var key := "%d_%d" % [b, e]
			if album.has(key):
				var card = Control.new()
				card.set_script(MonsterCard)
				slot.add_child(card)
				card.setup(album[key], false)
				card.pivot_offset = Vector2.ZERO
				card.scale = Vector2(sc, sc)
			else:
				var empty := Panel.new()
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(1, 1, 1, 0.06)
				sb.set_corner_radius_all(12)
				empty.add_theme_stylebox_override("panel", sb)
				empty.set_anchors_preset(Control.PRESET_FULL_RECT)
				slot.add_child(empty)
				var q := _label("?", 48, Color(1, 1, 1, 0.3))
				q.set_anchors_preset(Control.PRESET_FULL_RECT)
				q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slot.add_child(q)
			album_grid.add_child(slot)


func _show_reveal(cards: Array, news: Dictionary) -> void:
	for c in reveal_box.get_children():
		c.queue_free()
	# Die besten 5 zeigen, neue Album-Monster zuerst
	var idx: Array = range(cards.size())
	idx.sort_custom(func(a, b):
		var sa: int = cards[a]["rarity"] * 2 + (1 if cards[a]["shiny"] else 0) + (20 if news.has(a) else 0)
		var sb: int = cards[b]["rarity"] * 2 + (1 if cards[b]["shiny"] else 0) + (20 if news.has(b) else 0)
		return sa > sb)
	var shown := mini(5, idx.size())
	for i in shown:
		var card = Control.new()
		card.set_script(MonsterCard)
		reveal_box.add_child(card)
		card.setup(cards[idx[i]], news.has(idx[i]))
		card.scale = Vector2(0.01, 0.01)
		var tw: Tween = card.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var total := 0
	for m in cards:
		total += int(m["value"])
	var extra := cards.size() - shown
	lbl_more.text = ("+%d weitere · " % extra if extra > 0 else "") + "Wert: %s Münzen" % fmt(int(round(total * album_multiplier())))
	reveal_box.modulate.a = 1.0
	lbl_more.modulate.a = 1.0
	if reveal_tween:
		reveal_tween.kill()
	reveal_tween = create_tween()
	reveal_tween.tween_interval(1.8)
	reveal_tween.tween_property(reveal_box, "modulate:a", 0.0, 0.4)
	reveal_tween.parallel().tween_property(lbl_more, "modulate:a", 0.0, 0.4)


func _flash(color: Color, rarity: int) -> void:
	flash.color = Color(color, 0.45)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6)
	lbl_big.text = MonsterGen.RARITIES[rarity]["name"].to_upper() + "!"
	lbl_big.add_theme_color_override("font_color", color)
	lbl_big.modulate.a = 1.0
	lbl_big.scale = Vector2.ONE
	var tw2 := create_tween()
	tw2.tween_interval(1.0)
	tw2.tween_property(lbl_big, "modulate:a", 0.0, 0.5)


func toast(text: String) -> void:
	if lbl_toast == null:
		return
	lbl_toast.text = text
	lbl_toast.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.5)
	toast_tween.tween_property(lbl_toast, "modulate:a", 0.0, 0.6)


func _refresh_hud() -> void:
	if lbl_coins == null:
		return
	lbl_coins.text = "%s Münzen" % fmt(coins)
	lbl_stats.text = "Packs übrig: %s\nGeöffnet: %s\nAlbum: %d / %d" % [fmt(pile.remaining), fmt(packs_opened), album.size(), MonsterGen.album_size()]
	lbl_bag.text = "Rucksack  %d / %d" % [bag.size(), bag_capacity()]
	bar_bag.max_value = bag_capacity()
	bar_bag.value = bag.size()
	bar_flow.value = flow * 100.0
	lbl_flow.text = "Flow  +%d %% Tempo" % int(round(flow * 50.0))
	bar_rip.max_value = clicks_needed()
	bar_rip.value = rip_progress
	bar_rip.visible = looking_at == "pile"
	match looking_at:
		"pile":
			if bag.size() + MonsterGen.CARDS_PER_PACK > bag_capacity():
				lbl_prompt.text = "Rucksack voll – ab zum Laden!"
			elif levels["knife"] > 0:
				lbl_prompt.text = "Linksklick oder halten: Pack aufreißen"
			else:
				lbl_prompt.text = "Linksklick: Pack aufreißen (%d Klicks)" % int(clicks_needed())
		"shop":
			lbl_prompt.text = "E: Monster abgeben und Laden öffnen" if bag.size() > 0 else "E: Laden öffnen"
		_:
			lbl_prompt.text = ""


# ------------------------------------------------------------------ Speichern

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "coins", coins)
	cfg.set_value("game", "bag", bag)
	cfg.set_value("game", "packs_opened", packs_opened)
	cfg.set_value("game", "album", album)
	cfg.set_value("game", "levels", levels)
	cfg.set_value("game", "pile", pile.counts)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("game", "coins", 0)
	bag = cfg.get_value("game", "bag", [])
	packs_opened = cfg.get_value("game", "packs_opened", 0)
	album = cfg.get_value("game", "album", {})
	saved_pile = cfg.get_value("game", "pile", PackedInt32Array())
	var saved: Dictionary = cfg.get_value("game", "levels", {})
	for k in saved:
		if levels.has(k):
			levels[k] = saved[k]
