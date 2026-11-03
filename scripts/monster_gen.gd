extends RefCounted
## Zieht Karten aus dem festen Kartenset (card_data.gd). Jede Karte bekommt ein
## Aussehen aus Baukasten-Teilen, das fest an ihren Code gebunden ist: dieselbe
## Karte sieht also immer gleich aus. Gezeichnet wird sie von monster_card.gd.

const CardData = preload("res://scripts/card_data.gd")

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
	{"name": "Erde", "main": Color(0.42, 0.3, 0.2), "accent": Color(0.85, 0.65, 0.35), "bg": Color(0.11, 0.08, 0.05)},
	{"name": "Luft", "main": Color(0.5, 0.58, 0.62), "accent": Color(0.85, 0.98, 0.95), "bg": Color(0.08, 0.11, 0.13)},
	{"name": "Pflanze", "main": Color(0.22, 0.38, 0.18), "accent": Color(0.7, 0.95, 0.3), "bg": Color(0.04, 0.1, 0.05)},
	{"name": "Blitz", "main": Color(0.33, 0.29, 0.44), "accent": Color(1.0, 0.88, 0.3), "bg": Color(0.08, 0.07, 0.13)},
	{"name": "Eis", "main": Color(0.55, 0.7, 0.8), "accent": Color(0.75, 0.95, 1.0), "bg": Color(0.06, 0.1, 0.15)},
	{"name": "Schatten", "main": Color(0.22, 0.16, 0.3), "accent": Color(0.75, 0.35, 1.0), "bg": Color(0.04, 0.02, 0.07)},
	{"name": "Licht", "main": Color(0.78, 0.7, 0.5), "accent": Color(1.0, 0.97, 0.7), "bg": Color(0.16, 0.14, 0.09)},
	{"name": "Metall", "main": Color(0.45, 0.47, 0.5), "accent": Color(0.6, 0.85, 0.95), "bg": Color(0.08, 0.09, 0.1)},
]

## Körperformen, die die Karte zeichnet
const BODIES = ["Bestie", "Schlange", "Koloss", "Phantom"]

## Kreaturtyp aus der Liste -> [Körperform, Flügel, Hörner, Größe]
const TYPES = {
	"Bestie": [0, false, -1, 1.0],
	"Geflügelte Bestie": [0, true, -1, 1.0],
	"Himmelsbestie": [0, true, 2, 1.05],
	"Kleinwesen": [0, false, 0, 0.8],
	"Kobold": [0, false, 1, 0.85],
	"Insekt": [3, true, 0, 0.9],
	"Drache": [1, true, 1, 1.1],
	"Reptil": [1, false, -1, 1.0],
	"Seebestie": [1, false, 2, 1.05],
	"Tiefenwesen": [1, false, 0, 1.1],
	"Geist": [3, false, -1, 1.0],
	"Golem": [2, false, 0, 1.05],
	"Titan": [2, false, 1, 1.15],
	"Herrscher": [2, true, 1, 1.15],
	"Krieger": [2, false, 2, 1.0],
}

const CARDS_PER_PACK = 5
const SHINY_CHANCE = 0.01

static var _by_rarity: Array = []
static var _by_code: Dictionary = {}


static func _index() -> void:
	if not _by_rarity.is_empty():
		return
	for i in RARITIES.size():
		_by_rarity.append([])
	for card in CardData.CARDS:
		var r := rarity_index(card["rarity"])
		_by_rarity[r].append(card)
		_by_code[card["code"]] = card


static func rarity_index(name: String) -> int:
	for i in RARITIES.size():
		if RARITIES[i]["name"] == name:
			return i
	return 0


static func element_index(name: String) -> int:
	for i in ELEMENTS.size():
		if ELEMENTS[i]["name"] == name:
			return i
	return 0


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


## Baut aus einer Karte der Liste das Dictionary, das Spiel und Karte benutzen.
static func from_card(card: Dictionary, shiny: bool) -> Dictionary:
	var look := RandomNumberGenerator.new()
	look.seed = hash(card["code"])
	var rarity := rarity_index(card["rarity"])
	var t: Array = TYPES.get(card["type"], [0, false, -1, 1.0])
	var m := {
		"code": card["code"],
		"name": card["name"],
		"type": card["type"],
		"stufe": card["stufe"],
		"stufenname": card["stufenname"],
		"atk": card["atk"],
		"def": card["def"],
		"effect": card["effect"],
		"rarity": rarity,
		"element": element_index(card["element"]),
		"shiny": shiny,
		"seed": look.randi(),
		"body": t[0],
		"wings": t[1] or look.randf() < 0.1 * rarity,
		"horns": t[2] if t[2] >= 0 else look.randi() % 3,
		"eyes": 1 + look.randi() % 3,
		"mouth": 2 if card["type"] == "Insekt" else look.randi() % 3,
		"spikes": look.randf() < 0.35,
		"tail": look.randf() < 0.5,
		"hue": look.randf_range(-0.04, 0.04),
		"size": float(t[3]) * (0.92 + 0.04 * rarity),
	}
	m["value"] = int(RARITIES[rarity]["value"]) * (10 if shiny else 1)
	return m


static func generate(rng: RandomNumberGenerator, luck: float) -> Dictionary:
	_index()
	var rarity := roll_rarity(rng, luck)
	var pool: Array = _by_rarity[rarity]
	var card: Dictionary = pool[rng.randi() % pool.size()]
	return from_card(card, rng.randf() < SHINY_CHANCE)


static func album_key(m: Dictionary) -> String:
	return m.get("code", "")


static func album_size() -> int:
	return CardData.CARDS.size()


static func all_cards() -> Array:
	return CardData.CARDS
