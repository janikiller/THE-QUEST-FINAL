extends Node
## Catálogo de inmuebles / arquitectura para briefing de misión.

var houses: Array = []


func _ready() -> void:
	var data: Dictionary = _read("res://data/locations.json")
	houses = data.get("houses", [])


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func house_for_mission(mission_id: String) -> Dictionary:
	if houses.is_empty():
		return {}
	var idx := absi(hash(mission_id)) % houses.size()
	return houses[idx]


func house_path_for_mission(mission_id: String) -> String:
	var h: Dictionary = house_for_mission(mission_id)
	return str(h.get("path", ""))
