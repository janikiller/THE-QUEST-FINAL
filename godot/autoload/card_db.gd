extends Node
## Catálogo de cartas del roguelike táctico.

var types: Array = []
var cards: Dictionary = {} ## id -> Dictionary
var starter_deck: Array = []
var boss_rewards: Array = []
var market_exclude: Dictionary = {} ## id -> true


func _ready() -> void:
	var data: Dictionary = _read("res://data/cards.json")
	types = data.get("types", [])
	starter_deck = data.get("starter_deck", [])
	boss_rewards = data.get("boss_rewards", [])
	market_exclude.clear()
	for cid in data.get("market_exclude", []):
		market_exclude[str(cid)] = true
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


func cards_for_market(include_legendary: bool = false) -> Array:
	var out: Array = []
	for c in cards.values():
		var cid := str(c.get("id", ""))
		var rar := str(c.get("rarity", "common"))
		if market_exclude.has(cid):
			continue
		if rar == "legendary" and not include_legendary:
			continue
		out.append(c)
	out.sort_custom(func(a, b):
		var ra := _rarity_rank(str(a.get("rarity", "")))
		var rb := _rarity_rank(str(b.get("rarity", "")))
		if ra == rb:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return ra < rb
	)
	return out


func _rarity_rank(rarity: String) -> int:
	match rarity:
		"common":
			return 0
		"uncommon":
			return 1
		"rare":
			return 2
		"epic":
			return 3
		"legendary":
			return 4
		_:
			return 5


func price_of(card_id: String) -> int:
	var c := get_card(card_id)
	if c.is_empty():
		return 99
	if c.has("price"):
		return int(c["price"])
	match str(c.get("rarity", "common")):
		"uncommon":
			return 5
		"rare":
			return 9
		"epic":
			return 14
		"legendary":
			return 22
		_:
			return 3


func rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.35, 0.85, 0.5)
		"rare":
			return Color(0.35, 0.65, 1.0)
		"epic":
			return Color(0.95, 0.75, 0.25)
		"legendary":
			return Color(1.0, 0.55, 0.15)
		_:
			return Color(0.55, 0.7, 0.85)


func frame_path(rarity: String) -> String:
	var p := "res://assets/cards/frames/%s.png" % rarity
	if ResourceLoader.exists(p):
		return p
	return "res://assets/cards/frames/common.png"
