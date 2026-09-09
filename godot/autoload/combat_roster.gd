extends Node
## Catálogo anime de enemigos, bosses y escenarios de combate.

var enemies: Array = []
var bosses: Array = []
var arenas: Array = []
var hero: Dictionary = {}


func _ready() -> void:
	var data: Dictionary = _read("res://data/combat_roster.json")
	enemies = data.get("enemies", [])
	bosses = data.get("bosses", [])
	arenas = data.get("arenas", [])
	hero = data.get("hero", {})


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo leer %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func enemy_by_id(eid: String) -> Dictionary:
	for e in enemies:
		if str(e.get("id", "")) == eid:
			return e
	return {}


func boss_by_id(bid: String) -> Dictionary:
	for b in bosses:
		if str(b.get("id", "")) == bid:
			return b
	return {}


func arena_by_id(aid: String) -> Dictionary:
	for a in arenas:
		if str(a.get("id", "")) == aid:
			return a
	return {}


func pick_enemies_for_mission(mission_id: String, count: int) -> Array:
	if enemies.is_empty() or count <= 0:
		return []
	var start := absi(hash(mission_id + ":foes")) % enemies.size()
	var out: Array = []
	var used: Dictionary = {}
	for i in range(enemies.size()):
		var e: Dictionary = enemies[(start + i * 3) % enemies.size()]
		var eid := str(e.get("id", ""))
		if used.has(eid):
			continue
		used[eid] = true
		out.append(e.duplicate(true))
		if out.size() >= count:
			break
	# Si hace falta rellenar (catálogo pequeño), permite repetición controlada
	while out.size() < count and not enemies.is_empty():
		out.append(enemies[(start + out.size()) % enemies.size()].duplicate(true))
	return out


func available_bosses(day_index: int, defeated_ids: Array) -> Array:
	var out: Array = []
	var defeated := {}
	for d in defeated_ids:
		defeated[str(d)] = true
	for b in bosses:
		var bid := str(b.get("id", ""))
		if defeated.has(bid):
			continue
		if int(b.get("day_min", 2)) <= day_index:
			out.append(b)
	return out


func next_boss(day_index: int, defeated_ids: Array) -> Dictionary:
	var pool: Array = available_bosses(day_index, defeated_ids)
	if pool.is_empty():
		return {}
	# Prioriza el de menor day_min (progresión emocional)
	pool.sort_custom(func(a, b):
		return int(a.get("day_min", 99)) < int(b.get("day_min", 99))
	)
	return pool[0].duplicate(true)


func pick_arena_for_mission(mission: Dictionary, boss: Dictionary = {}) -> Dictionary:
	if not boss.is_empty():
		var pref := arena_by_id(str(boss.get("arena", "")))
		if not pref.is_empty():
			return pref
	if arenas.is_empty():
		return {}
	var period := str(mission.get("period", "night"))
	var pool: Array = []
	for a in arenas:
		if str(a.get("period", "")) == period or period == "":
			pool.append(a)
	if pool.is_empty():
		pool = arenas
	var mid := str(mission.get("id", "x"))
	return pool[absi(hash(mid + ":arena")) % pool.size()].duplicate(true)


func hero_pose(pose: String) -> String:
	var key := pose if pose in ["idle", "shoot", "hurt"] else "idle"
	var path := str(hero.get(key, ""))
	if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return path
	# Fallback al pack anterior
	return "res://assets/combat/custom/hero/%s.png" % key
