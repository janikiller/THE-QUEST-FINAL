extends Node
## Catálogo de personajes: policía (patrullas) y delincuentes.

var police: Array = []
var delinquents: Array = []


func _ready() -> void:
	var data: Dictionary = _read("res://data/characters.json")
	police = data.get("police", [])
	delinquents = data.get("delinquents", [])


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func police_by_name(name: String) -> Dictionary:
	for p in police:
		if str(p.get("name", "")) == name:
			return p
	return {}


func random_delinquents(count: int = 3) -> Array:
	var pool: Array = delinquents.duplicate()
	pool.shuffle()
	var out: Array = []
	for i in range(mini(count, pool.size())):
		out.append(pool[i])
	return out


func delinquent_icon_for_mission(mission_id: String) -> String:
	if delinquents.is_empty():
		return ""
	var idx := absi(hash(mission_id)) % delinquents.size()
	return str(delinquents[idx].get("icon", ""))


func delinquent_thumbs_for_mission(mission_id: String, count: int = 3) -> Array:
	if delinquents.is_empty():
		return []
	var start := absi(hash(mission_id)) % delinquents.size()
	var out: Array = []
	for i in range(count):
		var d: Dictionary = delinquents[(start + i) % delinquents.size()]
		out.append(d)
	return out
