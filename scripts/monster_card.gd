extends Control
## Zeichnet eine Monster-Karte komplett per Code aus den Bauteilen im Dictionary.

const MonsterGen = preload("res://scripts/monster_gen.gd")
const CARD_SIZE = Vector2(170, 240)

var data: Dictionary = {}
var is_new := false
var t := 0.0


func setup(d: Dictionary, new_in_album: bool) -> void:
	data = d
	is_new = new_in_album
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	if data.get("shiny", false) or data.get("rarity", 0) >= 3:
		queue_redraw()


func _ellipse(c: Vector2, rx: float, ry: float, n: int = 36) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), col)


func _draw() -> void:
	if data.is_empty():
		return
	var rar: Dictionary = MonsterGen.RARITIES[data["rarity"]]
	var el: Dictionary = MonsterGen.ELEMENTS[data["element"]]
	var w := size.x
	var h := size.y
	var font := ThemeDB.fallback_font

	# Rahmen und Hintergrund
	var frame := StyleBoxFlat.new()
	frame.bg_color = rar["color"]
	frame.set_corner_radius_all(14)
	if data["rarity"] >= 3:
		frame.shadow_color = Color(rar["color"], 0.45 + 0.25 * sin(t * 4.0))
		frame.shadow_size = 14
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var inner := StyleBoxFlat.new()
	inner.bg_color = el["bg"]
	inner.set_corner_radius_all(10)
	draw_style_box(inner, Rect2(Vector2(7, 7), Vector2(w - 14, h - 64)))

	# Farben
	var base: Color = el["main"]
	var hue := fposmod(base.h + data["hue"], 1.0)
	if data["shiny"]:
		hue = fposmod(hue + 0.5 + 0.08 * sin(t * 2.0), 1.0)
	var main := Color.from_hsv(hue, base.s, base.v)
	var dark := main.darkened(0.35)
	var light := main.lightened(0.35)
	var accent: Color = el["accent"]
	var c := Vector2(w / 2.0, 100)
	var s: float = data["size"]

	# Flügel (hinter dem Körper)
	if data["wings"]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -10) * s, c + Vector2(-72, -46) * s, c + Vector2(-60, 4) * s, c + Vector2(-70, 22) * s, c + Vector2(-22, 14) * s]), Color(accent, 0.85))
		draw_colored_polygon(PackedVector2Array([c + Vector2(20, -10) * s, c + Vector2(72, -46) * s, c + Vector2(60, 4) * s, c + Vector2(70, 22) * s, c + Vector2(22, 14) * s]), Color(accent, 0.85))

	# Schwanz
	if data["tail"]:
		var tail := PackedVector2Array()
		for i in 12:
			var k := i / 11.0
			tail.append(c + Vector2(20 + k * 42, 30 - sin(k * PI) * 26 - k * 10) * s)
		draw_polyline(tail, dark, 7.0 * s, true)
		draw_circle(tail[tail.size() - 1], 6 * s, accent)

	# Füße
	draw_colored_polygon(_ellipse(c + Vector2(-18, 44) * s, 12 * s, 7 * s), dark)
	draw_colored_polygon(_ellipse(c + Vector2(18, 44) * s, 12 * s, 7 * s), dark)

	# Körper
	var top_y := -40.0
	match int(data["body"]):
		0:  # Kugel
			draw_circle(c, 42 * s, main)
			draw_colored_polygon(_ellipse(c + Vector2(0, 14) * s, 24 * s, 20 * s), light)
			top_y = -42.0
		1:  # Turm
			draw_colored_polygon(_ellipse(c + Vector2(0, -4) * s, 30 * s, 50 * s), main)
			draw_colored_polygon(_ellipse(c + Vector2(0, 16) * s, 18 * s, 26 * s), light)
			top_y = -54.0
		2:  # Klotz
			var box := StyleBoxFlat.new()
			box.bg_color = main
			box.set_corner_radius_all(int(18 * s))
			draw_style_box(box, Rect2(c + Vector2(-46, -36) * s, Vector2(92, 80) * s))
			draw_colored_polygon(_ellipse(c + Vector2(0, 18) * s, 28 * s, 16 * s), light)
			top_y = -36.0
		_:  # Tropfen
			var drop := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				var r := 38.0 + 16.0 * maxf(0.0, -sin(a)) * (1.0 - absf(cos(a)))
				var p := Vector2(cos(a) * 38.0, sin(a) * r)
				if sin(a) < 0:
					p.x *= 1.0 + sin(a) * 0.55
				drop.append(c + p * s + Vector2(0, 4) * s)
			draw_colored_polygon(drop, main)
			draw_colored_polygon(_ellipse(c + Vector2(0, 18) * s, 22 * s, 16 * s), light)
			top_y = -50.0

	# Stacheln
	if data["spikes"]:
		for i in 3:
			var x := (-16.0 + 16.0 * i) * s
			var y := top_y * s + 6.0 * s + absf(x) * 0.15
			_tri(c + Vector2(x - 7 * s, y), c + Vector2(x + 7 * s, y), c + Vector2(x, y - 16 * s), dark)

	# Hörner / Fühler
	match int(data["horns"]):
		1:
			_tri(c + Vector2(-30, top_y + 14) * s, c + Vector2(-16, top_y + 6) * s, c + Vector2(-34, top_y - 16) * s, accent)
			_tri(c + Vector2(30, top_y + 14) * s, c + Vector2(16, top_y + 6) * s, c + Vector2(34, top_y - 16) * s, accent)
		2:
			draw_line(c + Vector2(-10, top_y + 4) * s, c + Vector2(-22, top_y - 22) * s, dark, 3.0)
			draw_line(c + Vector2(10, top_y + 4) * s, c + Vector2(22, top_y - 22) * s, dark, 3.0)
			draw_circle(c + Vector2(-22, top_y - 22) * s, 5 * s, accent)
			draw_circle(c + Vector2(22, top_y - 22) * s, 5 * s, accent)

	# Augen
	var eyes: int = data["eyes"]
	var ey := c + Vector2(0, -12) * s
	var offsets: Array = [[0.0], [-14.0, 14.0], [-20.0, 0.0, 20.0]][eyes - 1]
	var er := (14.0 if eyes == 1 else 10.0 if eyes == 2 else 8.0) * s
	for i in offsets.size():
		var p: Vector2 = ey + Vector2(offsets[i], -6.0 if (eyes == 3 and i == 1) else 0.0) * s
		draw_circle(p, er, Color.WHITE)
		draw_circle(p + Vector2(1.5, 1.5) * s, er * 0.5, Color(0.08, 0.06, 0.1))
		draw_circle(p + Vector2(-er * 0.25, -er * 0.3), er * 0.18, Color.WHITE)

	# Maul
	var mp := c + Vector2(0, 12) * s
	match int(data["mouth"]):
		0:
			draw_arc(mp, 11 * s, 0.25, PI - 0.25, 16, Color(0.1, 0.05, 0.08), 3.0, true)
		1:
			draw_colored_polygon(_ellipse(mp + Vector2(0, 3) * s, 10 * s, 7 * s), Color(0.25, 0.05, 0.1))
		_:
			draw_line(mp + Vector2(-14, 0) * s, mp + Vector2(14, 0) * s, Color(0.1, 0.05, 0.08), 3.0)
			_tri(mp + Vector2(-9, 0) * s, mp + Vector2(-3, 0) * s, mp + Vector2(-6, 8) * s, Color.WHITE)
			_tri(mp + Vector2(3, 0) * s, mp + Vector2(9, 0) * s, mp + Vector2(6, 8) * s, Color.WHITE)

	# Glanz-Funkeln
	if data["shiny"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = data["seed"]
		for i in 7:
			var sp := Vector2(rng.randf_range(16, w - 16), rng.randf_range(16, h - 70))
			var k := 0.5 + 0.5 * sin(t * 5.0 + i)
			var r := 3.0 + 4.0 * k
			draw_line(sp - Vector2(r, 0), sp + Vector2(r, 0), Color(1, 1, 1, k), 2.0)
			draw_line(sp - Vector2(0, r), sp + Vector2(0, r), Color(1, 1, 1, k), 2.0)

	# Textfeld
	var txt := Color(0.08, 0.07, 0.1)
	draw_string(font, Vector2(0, h - 36), data["name"], HORIZONTAL_ALIGNMENT_CENTER, w, 19, txt)
	var sub: String = rar["name"] + (" · GLANZ" if data["shiny"] else "")
	draw_string(font, Vector2(0, h - 16), sub, HORIZONTAL_ALIGNMENT_CENTER, w, 13, txt)
	draw_string(font, Vector2(14, 28), MonsterGen.ELEMENTS[data["element"]]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
	if is_new:
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color(1, 0.3, 0.35)
		badge.set_corner_radius_all(8)
		draw_style_box(badge, Rect2(Vector2(w - 70, 12), Vector2(58, 22)))
		draw_string(font, Vector2(w - 70, 28), "NEU", HORIZONTAL_ALIGNMENT_CENTER, 58, 13, Color.WHITE)
