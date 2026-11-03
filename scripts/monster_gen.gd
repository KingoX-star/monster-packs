extends RefCounted
## Erzeugt Monster aus Baukasten-Teilen. Jedes Monster ist nur ein Dictionary
## mit Bauteil-Indizes; gezeichnet wird es von monster_card.gd.

const RARITIES = [
	{"name": "Gewöhnlich", "chance": 70.0, "value": 1, "color": Color(0.62, 0.63, 0.68)},
	{"name": "Ungewöhnlich", "chance": 20.0, "value": 5, "color": Color(0.32, 0.78, 0.38)},
	{"name": "Selten", "chance": 8.0, "value": 25, "color": Color(0.27, 0.56, 1.0)},
	{"name": "Episch", "chance": 1.8, "value": 150, "color": Color(0.72, 0.33, 0.96)},
	{"name": "Legendär", "chance": 0.2, "value": 2000, "color": Color(1.0, 0.78, 0.22)},
]

const ELEMENTS = [
	{"name": "Feuer", "main": Color(0.62, 0.2, 0.12), "accent": Color(1.0, 0.55, 0.15), "bg": Color(0.17, 0.05, 0.04)},
	{"name": "Wasser", "main": Color(0.15, 0.33, 0.5), "accent": Color(0.4, 0.85, 1.0), "bg": Color(0.03, 0.07, 0.14)},
	{"name": "Pflanze", "main": Color(0.22, 0.38, 0.18), "accent": Color(0.7, 0.95, 0.3), "bg": Color(0.04, 0.1, 0.05)},
	{"name": "Blitz", "main": Color(0.33, 0.29, 0.44), "accent": Color(1.0, 0.88, 0.3), "bg": Color(0.08, 0.07, 0.13)},
]

const BODIES = ["Bestie", "Schlange", "Koloss", "Phantom"]
const BODY_HP = [70, 60, 95, 55]
const BODY_ATK = [65, 70, 45, 80]

const CARDS_PER_PACK = 5
const SHINY_CHANCE = 0.01

const SYL_A = ["Vor", "Kraz", "Mor", "Thal", "Gor", "Nyx", "Skar", "Drak", "Vel", "Zor", "Ul", "Rath", "Kael", "Sar", "Grim", "Ash"]
const SYL_B = ["a", "e", "i", "o", "u", "", "", "ae"]
const SYL_C = ["gath", "rax", "mor", "thul", "vex", "zar", "nok", "dris", "kar", "oth", "ion", "rek"]


static func roll_rarity(rng: RandomNumberGenerator, luck: float) -> int:
	var weights: Array = []
	var total := 0.0
	for i in RARITIES.size():
		var w: float = RARITIES[i]["chance"]
		if i >= 2:
			w *= 1.0 + luck
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0


static func make_name(rng: RandomNumberGenerator) -> String:
	return SYL_A[rng.randi() % SYL_A.size()] + SYL_B[rng.randi() % SYL_B.size()] + SYL_C[rng.randi() % SYL_C.size()]


static func generate(rng: RandomNumberGenerator, luck: float) -> Dictionary:
	var rarity := roll_rarity(rng, luck)
	var shiny := rng.randf() < SHINY_CHANCE
	var m := {
		"seed": rng.randi(),
		"rarity": rarity,
		"shiny": shiny,
		"body": rng.randi() % BODIES.size(),
		"element": rng.randi() % ELEMENTS.size(),
		"eyes": 1 + rng.randi() % 3,
		"mouth": rng.randi() % 3,
		"horns": rng.randi() % 3,
		"wings": rng.randf() < 0.25 + 0.12 * rarity,
		"spikes": rng.randf() < 0.3,
		"tail": rng.randf() < 0.45,
		"hue": rng.randf_range(-0.05, 0.05),
		"size": rng.randf_range(0.85, 1.1) + 0.05 * rarity,
		"name": make_name(rng),
	}
	m["value"] = int(RARITIES[rarity]["value"]) * (10 if shiny else 1)
	var boost := 1.1 if shiny else 1.0
	m["hp"] = int(round((BODY_HP[m["body"]] + rarity * 25 + rng.randi_range(0, 20)) * boost / 10.0)) * 10
	m["atk"] = int(round((BODY_ATK[m["body"]] + rarity * 20 + rng.randi_range(0, 20)) * boost / 5.0)) * 5
	return m


static func album_key(m: Dictionary) -> String:
	return "%d_%d" % [m["body"], m["element"]]


static func album_size() -> int:
	return BODIES.size() * ELEMENTS.size()
