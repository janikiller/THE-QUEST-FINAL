extends Node
## Catálogo de objetos utilizables (sin munición).

var categories: Array = []
var items: Dictionary = {} ## id -> def


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open("res://data/items.json", FileAccess.READ)
	if f == null:
		push_error("No se pudo leer items.json")
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	categories = data.get("categories", [])
	items.clear()
	for it in data.get("items", []):
		var id := str(it.get("id", ""))
		if id == "":
			continue
		items[id] = it


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func all_ids() -> Array:
	return items.keys()


func ids_by_category(cat: String) -> Array:
	if cat == "" or cat == "todos":
		return all_ids()
	var out: Array = []
	for id in items.keys():
		if str(items[id].get("category", "")) == cat:
			out.append(id)
	return out
