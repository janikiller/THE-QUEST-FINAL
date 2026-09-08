extends Node
## Catálogo de cartas del roguelike táctico.

var types: Array = []
var cards: Dictionary = {} ## id -> Dictionary
var starter_deck: Array = []


func _ready() -> void:
	var data: Dictionary = _read("res://data/cards.json")
	types = data.get("types", [])
	starter_deck = data.get("starter_deck", [])
	cards.clear()
	for c in data.get("cards", []):
		cards[str(c.get("id", ""))] = c


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo leer %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func get_card(card_id: String) -> Dictionary:
	return cards.get(card_id, {})


func all_cards() -> Array:
	return cards.values()


func rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.35, 0.85, 0.5)
		"rare":
			return Color(0.35, 0.65, 1.0)
		"epic":
			return Color(0.95, 0.75, 0.25)
		_:
			return Color(0.55, 0.7, 0.85)


func frame_path(rarity: String) -> String:
	var p := "res://assets/cards/frames/%s.png" % rarity
	if ResourceLoader.exists(p):
		return p
	return "res://assets/cards/frames/common.png"
