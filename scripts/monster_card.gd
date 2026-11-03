extends Control
## Zeichnet eine Monster-Karte im dunklen Sammelkarten-Stil komplett per Code.
## Seltenheit 0 hat keine Effekte, ab Seltenheit 1 leuchtet und glitzert die Karte
## zunehmend, Legendär strahlt mit Lichtstrahlen und Holo-Schimmer.

const MonsterGen = preload("res://scripts/monster_gen.gd")
const CARD_SIZE = Vector2(190, 270)

const GLOW_ALPHA = [0.0, 0.28, 0.42, 0.6, 0.85]
const GLOW_SIZE = [0, 6, 10, 16, 26]
const SPARKS = [0, 2, 4, 8, 16]
const BONE = Color(0.86, 0.82, 0.72)
const INK = Color(0.04, 0.03, 0.05)

var data: Dictionary = {}
var is_new := false
var t := 0.0
var bold: FontVariation


func setup(d: Dictionary, new_in_album: bool) -> void:
	data = d
	is_new = new_in_album
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bold = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7
	t = randf() * 10.0
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	if data.get("shiny", false) or data.get("rarity", 0) >= 1:
		queue_redraw()


# ------------------------------------------------------------------ Helfer

func _ellipse(c: Vector2, rx: float, ry: float, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _poly(c: Vector2, s: float, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + Vector2(p[0], p[1]) * s)
	draw_colored_polygon(out, col)


func _box(rect: Rect2, col: Color, radius: int, border := 0, border_col := Color.TRANSPARENT) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_col
	draw_style_box(sb, rect)


func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		var rr := r if i % 2 == 0 else r * 0.22
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


func _taper(points: Array, w0: float, w1: float, col: Color) -> void:
	# Ein sich verjüngender Strich (Horn, Schwanz)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in points.size():
		var k := float(i) / (points.size() - 1)
		var p: Vector2 = points[i]
		var dir: Vector2 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-dir.y, dir.x) * lerpf(w0, w1, k) * 0.5
		left.append(p + nrm)
		right.append(p - nrm)
	right.reverse()
	draw_colored_polygon(left + right, col)


# ------------------------------------------------------------------ Element-Symbole

func _element_icon(c: Vector2, r: float, element: int, col: Color) -> void:
	draw_circle(c, r + 2.0, Color(col, 0.9))
	draw_circle(c, r, Color(0.06, 0.06, 0.08))
	var s := r * 0.72
	match element:
		0:  # Feuer
			_poly(c, s, [[0, -1], [0.35, -0.4], [0.6, 0.1], [0.5, 0.6], [0, 0.88], [-0.5, 0.6], [-0.6, 0.1], [-0.25, -0.15], [-0.12, -0.55]], col)
			_poly(c, s, [[0, 0.1], [0.22, 0.45], [0, 0.72], [-0.22, 0.45]], Color(0.06, 0.06, 0.08))
		1:  # Wasser
			var pts := PackedVector2Array([c + Vector2(0, -0.95) * s])
			for i in 15:
				var a := deg_to_rad(-35.0 + 250.0 * i / 14.0)
				pts.append(c + (Vector2(0, 0.28) + Vector2(cos(a), sin(a)) * 0.58) * s)
			draw_colored_polygon(pts, col)
		2:  # Pflanze
			var leaf := PackedVector2Array()
			for i in 13:
				var k := i / 12.0
				leaf.append(c + Vector2(sin(k * PI) * 0.55, lerpf(-0.9, 0.8, k)) * s)
			for i in range(11, 0, -1):
				var k := i / 12.0
				leaf.append(c + Vector2(-sin(k * PI) * 0.55, lerpf(-0.9, 0.8, k)) * s)
			draw_colored_polygon(leaf, col)
			draw_line(c + Vector2(0, -0.7) * s, c + Vector2(0, 0.95) * s, Color(0.06, 0.06, 0.08), 1.5)
		_:  # Blitz
			_poly(c, s, [[0.2, -0.95], [-0.42, 0.12], [0.0, 0.12], [-0.22, 0.95], [0.46, -0.2], [0.05, -0.2], [0.32, -0.95]], col)


# ------------------------------------------------------------------ Monster

func _eye(p: Vector2, r: float, side: float, glow: Color) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var x := lerpf(-r, r, i / 10.0)
		pts.append(p + Vector2(x, -sin(i / 10.0 * PI) * r * 0.42 - x * side * 0.38))
	for i in range(9, 0, -1):
		var x := lerpf(-r, r, i / 10.0)
		pts.append(p + Vector2(x, sin(i / 10.0 * PI) * r * 0.3 - x * side * 0.38))
	draw_circle(p, r * 1.35, Color(glow, 0.18))
	draw_colored_polygon(pts, glow)
	draw_colored_polygon(_ellipse(p, r * 0.16, r * 0.36, 12), INK)
	# Braue
	draw_line(p + Vector2(-r * 1.15, -r * 0.55 + r * side * 0.5), p + Vector2(r * 1.15, -r * 0.55 - r * side * 0.5), INK, 3.0)


func _draw_monster(c: Vector2, s: float) -> void:
	var el: Dictionary = MonsterGen.ELEMENTS[data["element"]]
	var base: Color = el["main"]
	var hue := fposmod(base.h + data["hue"], 1.0)
	if data["shiny"]:
		hue = fposmod(hue + 0.45 + 0.06 * sin(t * 2.0), 1.0)
	var main := Color.from_hsv(hue, base.s, base.v)
	var shade := main.darkened(0.5)
	var rim := main.lightened(0.35)
	var glow: Color = el["accent"]
	var body: int = data["body"]
	var head_y: float = [-6.0, -26.0, -14.0, -16.0][body]
	var top_y: float = [-36.0, -50.0, -44.0, -44.0][body]

	# Flügel
	if data["wings"]:
		for sgn: float in [-1.0, 1.0]:
			var sh := c + Vector2(sgn * 18, -8) * s
			var tips := [Vector2(sgn * 60, -46), Vector2(sgn * 64, -8), Vector2(sgn * 56, 18)]
			var mem := PackedVector2Array([sh])
			mem.append(c + tips[0] * s)
			mem.append(c + Vector2(sgn * 50, -16) * s)
			mem.append(c + tips[1] * s)
			mem.append(c + Vector2(sgn * 44, 6) * s)
			mem.append(c + tips[2] * s)
			mem.append(c + Vector2(sgn * 24, 14) * s)
			draw_colored_polygon(mem, Color(main.darkened(0.62), 0.97))
			for tip in tips:
				draw_line(sh, c + tip * s, shade.darkened(0.3), 2.0)

	# Schwanz
	if data["tail"] and body != 3:
		var pts: Array = []
		for i in 10:
			var k := i / 9.0
			pts.append(c + Vector2(22 + k * 40, 30 - sin(k * PI) * 22 - k * 12) * s)
		_taper(pts, 9.0 * s, 2.0 * s, shade)
		var tip: Vector2 = pts[pts.size() - 1]
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, 3) * s, tip + Vector2(10, -8) * s, tip + Vector2(2, 6) * s]), BONE)

	# Körper
	match body:
		0:  # Bestie: geduckter, breiter Körper mit Schulterbuckeln
			draw_circle(c + Vector2(-30, -14) * s, 18 * s, main)
			draw_circle(c + Vector2(30, -14) * s, 18 * s, main)
			draw_colored_polygon(_ellipse(c + Vector2(0, 8) * s, 46 * s, 34 * s), main)
			draw_colored_polygon(_ellipse(c + Vector2(0, 28) * s, 40 * s, 13 * s), Color(shade, 0.55))
		1:  # Schlange: hoher Körper auf einer Windung
			draw_colored_polygon(_ellipse(c + Vector2(0, 40) * s, 46 * s, 13 * s), main.darkened(0.25))
			draw_colored_polygon(_ellipse(c + Vector2(0, -2) * s, 25 * s, 48 * s), main)
			for i in 4:
				draw_arc(c + Vector2(0, 2 + i * 9) * s, 13 * s, 0.3, PI - 0.3, 10, Color(rim, 0.45), 2.0)
		2:  # Koloss: gepanzerter, kantiger Block
			_poly(c, s, [[-44, -30], [-20, -44], [20, -44], [44, -30], [50, 18], [30, 44], [-30, 44], [-50, 18]], main)
			_poly(c, s, [[-38, 14], [38, 14], [26, 38], [-26, 38]], Color(shade, 0.6))
			draw_line(c + Vector2(-44, -6) * s, c + Vector2(44, -6) * s, Color(shade, 0.8), 2.0)
			draw_line(c + Vector2(0, -44) * s, c + Vector2(0, -26) * s, Color(shade, 0.8), 2.0)
		_:  # Phantom: schwebende Gestalt mit zerfranstem Saum
			_poly(c, s, [[-34, -8], [-30, -34], [-14, -46], [14, -46], [30, -34], [34, -8], [28, 26], [20, 42], [10, 28], [0, 50], [-10, 28], [-20, 42], [-28, 26]], Color(main, 0.92))
			draw_colored_polygon(_ellipse(c + Vector2(0, 22) * s, 22 * s, 14 * s), Color(shade, 0.5))

	# Rückenstacheln
	if data["spikes"]:
		for i in 4:
			var x := (-21.0 + 14.0 * i) * s
			var y := top_y * s + 8.0 * s
			draw_colored_polygon(PackedVector2Array([c + Vector2(x - 6 * s, y), c + Vector2(x + 6 * s, y), c + Vector2(x + 2 * s, y - 15 * s)]), shade)

	# Hörner
	match int(data["horns"]):
		1:
			for sgn: float in [-1.0, 1.0]:
				var pts: Array = []
				for i in 9:
					var k := i / 8.0
					pts.append(c + Vector2(sgn * (12 + 26 * k + 6 * k * k), top_y + 10 - 30 * k * k - 6 * k) * s)
				_taper(pts, 9.0 * s, 1.0 * s, BONE.darkened(0.15))
		2:
			for i in 5:
				var x := (-16.0 + 8.0 * i) * s
				var hgt := (14.0 - absf(i - 2.0) * 3.0) * s
				var y := top_y * s + 6.0 * s
				draw_colored_polygon(PackedVector2Array([c + Vector2(x - 4 * s, y), c + Vector2(x + 4 * s, y), c + Vector2(x, y - hgt)]), shade.darkened(0.2))

	# Krallen
	if body != 3:
		for sgn: float in [-1.0, 1.0]:
			var fp := c + Vector2(sgn * 24, 44) * s
			for k in 3:
				var o := (k - 1) * 5.0 * s
				draw_colored_polygon(PackedVector2Array([fp + Vector2(o - 2.5 * s, -3 * s), fp + Vector2(o + 2.5 * s, -3 * s), fp + Vector2(o, 5 * s)]), BONE)

	# Kantenlicht
	draw_arc(c + Vector2(0, head_y + 6) * s, 30 * s, PI * 1.1, PI * 1.55, 10, Color(rim, 0.55), 2.0 * s)

	# Augen
	var eyes: int = data["eyes"]
	var ey := c + Vector2(0, head_y) * s
	if eyes == 1:
		_eye(ey, 12 * s, 0.0, glow)
	else:
		_eye(ey + Vector2(-13, 0) * s, 9 * s, -1.0, glow)
		_eye(ey + Vector2(13, 0) * s, 9 * s, 1.0, glow)
		if eyes == 3:
			_eye(ey + Vector2(0, -15) * s, 5.5 * s, 0.0, glow)

	# Maul
	var mp := c + Vector2(0, head_y + 18) * s
	match int(data["mouth"]):
		0:  # verkniffener Kiefer mit Zähnen
			var line := PackedVector2Array()
			for i in 9:
				var k := i / 8.0
				line.append(mp + Vector2(lerpf(-15, 15, k), 3.0 * sin(k * PI) * -1.0 + 2.0) * s)
			draw_polyline(line, INK, 2.5)
			for i in 6:
				var x := lerpf(-11, 11, i / 5.0)
				draw_colored_polygon(PackedVector2Array([mp + Vector2(x - 2, 0) * s, mp + Vector2(x + 2, 0) * s, mp + Vector2(x, 5) * s]), BONE)
		1:  # offenes Maul mit Reißzähnen
			draw_colored_polygon(_ellipse(mp + Vector2(0, 3) * s, 14 * s, 7 * s, 20), Color(0.22, 0.03, 0.05))
			for sgn: float in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([mp + Vector2(sgn * 9 - 2.5, -3) * s, mp + Vector2(sgn * 9 + 2.5, -3) * s, mp + Vector2(sgn * 8, 7) * s]), BONE)
				draw_colored_polygon(PackedVector2Array([mp + Vector2(sgn * 4 - 2, 9) * s, mp + Vector2(sgn * 4 + 2, 9) * s, mp + Vector2(sgn * 4, 4) * s]), BONE)
		_:  # Mandibeln
			for sgn: float in [-1.0, 1.0]:
				var pts: Array = []
				for i in 7:
					var k := i / 6.0
					pts.append(mp + Vector2(sgn * (12 - 6 * k * k), -2 + 14 * k) * s)
				_taper(pts, 5.0 * s, 1.0 * s, BONE.darkened(0.1))
			draw_line(mp + Vector2(-5, 3) * s, mp + Vector2(5, 3) * s, INK, 2.0)


# ------------------------------------------------------------------ Karte

func _draw() -> void:
	if data.is_empty():
		return
	var rarity: int = data["rarity"]
	var rar: Dictionary = MonsterGen.RARITIES[rarity]
	var el: Dictionary = MonsterGen.ELEMENTS[data["element"]]
	var rcol: Color = rar["color"]
	var w := size.x
	var h := size.y
	var font := ThemeDB.fallback_font
	var pulse := 0.5 + 0.5 * sin(t * 3.0)

	# Legendär: Lichtstrahlen hinter der Karte
	if rarity >= 4:
		var center := Vector2(w / 2.0, h / 2.0)
		for i in 14:
			var a := TAU * i / 14.0 + t * 0.35
			var p1 := center + Vector2(cos(a - 0.07), sin(a - 0.07)) * 230.0
			var p2 := center + Vector2(cos(a + 0.07), sin(a + 0.07)) * 230.0
			draw_colored_polygon(PackedVector2Array([center, p1, p2]), Color(rcol, 0.1 + 0.05 * pulse))

	# Rahmen mit Leuchten ab Seltenheit 1
	var frame := StyleBoxFlat.new()
	frame.bg_color = rcol.darkened(0.45)
	frame.set_corner_radius_all(11)
	frame.set_border_width_all(3)
	frame.border_color = rcol.lightened(0.1)
	if rarity >= 1:
		frame.shadow_color = Color(rcol, GLOW_ALPHA[rarity] * (0.75 + 0.25 * pulse))
		frame.shadow_size = GLOW_SIZE[rarity]
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	_box(Rect2(6, 6, w - 12, h - 12), Color(0.075, 0.075, 0.09), 7)

	# Kopfzeile: Name und Element-Symbol
	_box(Rect2(10, 10, w - 20, 28), Color(0.13, 0.13, 0.16), 5)
	draw_string(bold, Vector2(17, 30), data["name"], HORIZONTAL_ALIGNMENT_LEFT, w - 60, 15, Color(0.93, 0.91, 0.86))
	_element_icon(Vector2(w - 25, 24), 10.0, data["element"], el["accent"])

	# Bildfenster
	var art := Rect2(12, 42, w - 24, 142)
	var bg: Color = el["bg"]
	draw_polygon(PackedVector2Array([art.position, art.position + Vector2(art.size.x, 0), art.end, art.position + Vector2(0, art.size.y)]),
		PackedColorArray([bg.darkened(0.4), bg.darkened(0.4), bg.lightened(0.12), bg.lightened(0.12)]))
	var mc := Vector2(w / 2.0, 118)
	for k in 3:
		draw_circle(mc, 64.0 - k * 16.0, Color(el["accent"], 0.035 + 0.02 * k))
	_draw_monster(mc, minf(float(data["size"]), 1.15) * 1.02)
	draw_rect(art, Color(rcol, 0.85), false, 1.5)
	if data["shiny"]:
		_box(Rect2(Vector2(art.end.x - 50, art.position.y + 4), Vector2(46, 17)), Color.from_hsv(fposmod(t * 0.3, 1.0), 0.55, 0.85), 3)
		draw_string(bold, Vector2(art.end.x - 50, art.position.y + 17), "GLANZ", HORIZONTAL_ALIGNMENT_CENTER, 46, 11, INK)
	if is_new:
		_box(Rect2(art.position + Vector2(4, 4), Vector2(42, 17)), Color(0.75, 0.1, 0.12), 3)
		draw_string(bold, art.position + Vector2(4, 17), "NEU", HORIZONTAL_ALIGNMENT_CENTER, 42, 11, Color.WHITE)

	# Typzeile mit Seltenheit
	var type_line: String = MonsterGen.BODIES[data["body"]] + " · " + rar["name"]
	draw_string(font, Vector2(14, 200), type_line, HORIZONTAL_ALIGNMENT_LEFT, w - 70, 11, Color(0.72, 0.7, 0.66))
	for i in rarity + 1:
		var dp := Vector2(w - 16 - i * 10, 196)
		_poly(dp, 1.0, [[0, -4.5], [3.5, 0], [0, 4.5], [-3.5, 0]], rcol)

	# Werte: LP und Angriff
	var hp: int = data.get("hp", 50 + rarity * 25)
	var atk: int = data.get("atk", 40 + rarity * 20)
	var stats := Rect2(12, 208, w - 24, 48)
	_box(stats, Color(0.11, 0.11, 0.14), 5, 1, Color(rcol, 0.5))
	var half := stats.size.x / 2.0
	draw_line(Vector2(stats.position.x + half, stats.position.y + 8), Vector2(stats.position.x + half, stats.end.y - 8), Color(1, 1, 1, 0.12), 1.0)
	draw_string(font, Vector2(stats.position.x, stats.position.y + 16), "LP", HORIZONTAL_ALIGNMENT_CENTER, half, 11, Color(0.9, 0.4, 0.38))
	draw_string(bold, Vector2(stats.position.x, stats.position.y + 40), str(hp), HORIZONTAL_ALIGNMENT_CENTER, half, 20, Color(0.95, 0.93, 0.9))
	draw_string(font, Vector2(stats.position.x + half, stats.position.y + 16), "ANGRIFF", HORIZONTAL_ALIGNMENT_CENTER, half, 11, Color(0.95, 0.65, 0.3))
	draw_string(bold, Vector2(stats.position.x + half, stats.position.y + 40), str(atk), HORIZONTAL_ALIGNMENT_CENTER, half, 20, Color(0.95, 0.93, 0.9))

	# Holo-Schimmer ab Episch
	if rarity >= 3 or data["shiny"]:
		var period := 2.8
		var x := lerpf(-w, w * 2.0, fposmod(t, period) / period)
		var band := PackedVector2Array([Vector2(x, -10), Vector2(x + 34, -10), Vector2(x - 66, h + 10), Vector2(x - 100, h + 10)])
		var card := PackedVector2Array([Vector2(3, 3), Vector2(w - 3, 3), Vector2(w - 3, h - 3), Vector2(3, h - 3)])
		var col := Color(1, 1, 1, 0.1)
		if rarity >= 4 or data["shiny"]:
			col = Color.from_hsv(fposmod(t * 0.25, 1.0), 0.5, 1.0, 0.22)
		for piece in Geometry2D.intersect_polygons(band, card):
			draw_colored_polygon(piece, col)

	# Glitzern ab Seltenheit 1
	var sparks: int = SPARKS[rarity] + (6 if data["shiny"] else 0)
	if sparks > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(data["seed"])
		for i in sparks:
			var p: Vector2
			if i % 2 == 0:
				# am Rand der Karte
				var e := rng.randf() * 2.0 * (w + h)
				if e < w:
					p = Vector2(e, -3)
				elif e < w + h:
					p = Vector2(w + 3, e - w)
				elif e < 2.0 * w + h:
					p = Vector2(e - w - h, h + 3)
				else:
					p = Vector2(-3, e - 2.0 * w - h)
			else:
				p = Vector2(rng.randf_range(art.position.x + 6, art.end.x - 6), rng.randf_range(art.position.y + 6, art.end.y - 6))
			var speed := rng.randf_range(2.0, 4.5)
			var k := maxf(0.0, sin(t * speed + rng.randf() * TAU))
			if k > 0.05:
				_star(p, (3.0 + 5.0 * k) * (1.0 + 0.15 * rarity), Color(rcol.lightened(0.6), k))
