extends Node
## Catálogo de cartas del roguelike táctico (anime: básica / mágica / fuerza / legendaria).

var types: Array = []
var cards: Dictionary = {} ## id -> Dictionary
var starter_deck: Array = []
var boss_rewards: Array = []
var market_exclude: Dictionary = {} ## id -> true
var enemy_cards: Dictionary = {} ## id -> Dictionary
var enemy_role_pools: Dictionary = {}
var enemy_boss_pools: Dictionary = {}


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
		var card: Dictionary = c.duplicate(true)
		card["rarity"] = normalize_rarity(str(card.get("rarity", "basica")))
		cards[str(card.get("id", ""))] = card
	_load_enemy_cards()


func _load_enemy_cards() -> void:
	var data: Dictionary = _read("res://data/enemy_cards.json")
	enemy_cards.clear()
	for c in data.get("cards", []):
		var card: Dictionary = c.duplicate(true)
		enemy_cards[str(card.get("id", ""))] = card
	enemy_role_pools = data.get("role_pools", {})
	enemy_boss_pools = data.get("boss_pools", {})


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo leer %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func normalize_rarity(rarity: String) -> String:
	match rarity:
		"common", "basica", "básica":
			return "basica"
		"uncommon", "rare", "magica", "mágica", "magic":
			return "magica"
		"epic", "fuerza", "force":
			return "fuerza"
		"legendary", "legendaria":
			return "legendaria"
		_:
			return rarity if rarity != "" else "basica"


func rarity_label(rarity: String) -> String:
	match normalize_rarity(rarity):
		"basica":
			return "BÁSICA"
		"magica":
			return "MÁGICA"
		"fuerza":
			return "FUERZA"
		"legendaria":
			return "LEGENDARIA"
		_:
			return rarity.to_upper()


func get_card(card_id: String) -> Dictionary:
	return cards.get(card_id, {})


func get_enemy_card(card_id: String) -> Dictionary:
	return enemy_cards.get(card_id, {})


func get_any_card(card_id: String) -> Dictionary:
	var c := get_card(card_id)
	if not c.is_empty():
		return c
	return get_enemy_card(card_id)


func enemy_pool_for_role(role: String) -> Array:
	var pool: Array = enemy_role_pools.get(role, [])
	if pool.is_empty():
		pool = enemy_role_pools.get("default", [])
	return pool.duplicate()


func enemy_pool_for_boss(boss_id: String) -> Array:
	var pool: Array = enemy_boss_pools.get(boss_id, [])
	if pool.is_empty():
		pool = enemy_boss_pools.get("default", [])
	return pool.duplicate()


func enemy_card_intent_kind(def: Dictionary) -> String:
	var kind := str(def.get("kind", ""))
	if kind != "":
		return kind
	if int(def.get("damage", 0)) > 0:
		return "attack"
	if int(def.get("block", 0)) > 0:
		return "block"
	if int(def.get("heal", 0)) > 0:
		return "heal"
	return "attack"


func enemy_card_preview_value(def: Dictionary) -> int:
	match enemy_card_intent_kind(def):
		"attack":
			return int(def.get("damage", 0)) * maxi(1, int(def.get("hits", 1)))
		"block":
			return int(def.get("block", 0))
		"heal":
			return int(def.get("heal", 0))
		_:
			return int(def.get("damage", 0))


func enemy_effect_line(def: Dictionary) -> String:
	var fx := str(def.get("effect", ""))
	if fx != "":
		return fx
	return effect_line(def)


func all_cards() -> Array:
	return cards.values()


func is_legendary(rarity: String) -> bool:
	return normalize_rarity(rarity) == "legendaria"


func cards_for_market(include_legendary: bool = false) -> Array:
	var out: Array = []
	for c in cards.values():
		var cid := str(c.get("id", ""))
		var rar := normalize_rarity(str(c.get("rarity", "basica")))
		if market_exclude.has(cid):
			continue
		if rar == "legendaria" and not include_legendary:
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
	match normalize_rarity(rarity):
		"basica":
			return 0
		"magica":
			return 1
		"fuerza":
			return 2
		"legendaria":
			return 3
		_:
			return 4


func price_of(card_id: String) -> int:
	var c := get_card(card_id)
	if c.is_empty():
		return 99
	if c.has("price"):
		return int(c["price"])
	match normalize_rarity(str(c.get("rarity", "basica"))):
		"magica":
			return 8
		"fuerza":
			return 14
		"legendaria":
			return 22
		_:
			return 3


func rarity_color(rarity: String) -> Color:
	match normalize_rarity(rarity):
		"magica":
			return Color(0.45, 0.72, 1.0)
		"fuerza":
			return Color(0.95, 0.55, 0.28)
		"legendaria":
			return Color(1.0, 0.78, 0.28)
		_:
			return Color(0.55, 0.72, 0.82)


func frame_path(rarity: String) -> String:
	var key := normalize_rarity(rarity)
	var p := "res://assets/cards/frames/%s.png" % key
	if ResourceLoader.exists(p) or FileAccess.file_exists(p):
		return p
	# Aliases antiguos
	var aliases := {
		"basica": "common",
		"magica": "rare",
		"fuerza": "epic",
		"legendaria": "legendary",
	}
	var alt := "res://assets/cards/frames/%s.png" % aliases.get(key, "common")
	if ResourceLoader.exists(alt) or FileAccess.file_exists(alt):
		return alt
	return "res://assets/cards/frames/common.png"


func effect_line(def: Dictionary) -> String:
	## Texto corto mecánico que cabe en la cara de la carta.
	var bits: Array[String] = []
	var dmg := int(def.get("damage", 0))
	var hits := maxi(1, int(def.get("hits", 1)))
	if dmg > 0:
		if hits > 1:
			bits.append("%d×%d daño" % [dmg, hits])
		else:
			bits.append("%d daño" % dmg)
	var block := int(def.get("block", 0))
	if block > 0:
		bits.append("+%d bloqueo" % block)
	var heal := int(def.get("heal", 0))
	if heal > 0:
		bits.append("+%d cura" % heal)
	var draw_n := int(def.get("draw", 0))
	if draw_n > 0:
		bits.append("roba %d" % draw_n)
	var stun := int(def.get("stun", 0))
	if stun > 0 or bool(def.get("stun", false)):
		bits.append("stun" if stun <= 1 else "stun %d" % stun)
	if bool(def.get("detain", false)):
		bits.append("detiene (0 PV)")
	if bits.is_empty():
		var fallback := str(def.get("effect", def.get("desc", def.get("description", ""))))
		return _clip_text(fallback, 36)
	var out := ""
	for i in range(bits.size()):
		if i > 0:
			out += " · "
		out += bits[i]
	return out


func flavor_line(def: Dictionary) -> String:
	## Texto de sabor para paneles de detalle (mazo/mercado).
	var flavor := str(def.get("description", ""))
	if flavor == "":
		flavor = str(def.get("effect", def.get("desc", "")))
	return flavor


func _clip_text(text: String, max_len: int) -> String:
	var t := text.strip_edges()
	if t.length() <= max_len:
		return t
	return t.substr(0, maxi(1, max_len - 1)) + "…"
