extends Node
## Catálogo anime de enemigos, bosses y escenarios de combate.

var enemies: Array = []
var bosses: Array = []
var arenas: Array = []
var hero: Dictionary = {}
## Evita repetir el mismo fondo en combates seguidos.
var _recent_arena_ids: Array = []
const RECENT_ARENA_LIMIT := 8


func _ready() -> void:
	var data: Dictionary = _read("res://data/combat_roster.json")
	enemies = data.get("enemies", [])
	bosses = data.get("bosses", [])
	arenas = []
	for a in data.get("arenas", []):
		# Los mockups de UI son referencia de estilo, no escenarios jugables.
		if _is_ui_mockup_arena(a):
			continue
		arenas.append(a)
	hero = data.get("hero", {})


func _is_ui_mockup_arena(arena: Dictionary) -> bool:
	var aid := str(arena.get("id", "")).to_lower()
	var path := str(arena.get("path", "")).to_lower()
	if "mockup" in aid or "mockup" in path:
		return true
	if "ui_mockup" in path or "ui_target" in path or "/reference/" in path:
		return true
	return false


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


func available_bosses(night_index: int, defeated_ids: Array) -> Array:
	## night_index = GameState.nights_count (boss cada 2 noches → night_min 2,4,6…).
	var out: Array = []
	var defeated := {}
	for d in defeated_ids:
		defeated[str(d)] = true
	for b in bosses:
		var bid := str(b.get("id", ""))
		if defeated.has(bid):
			continue
		var need := int(b.get("night_min", b.get("day_min", 2)))
		if need <= night_index:
			out.append(b)
	return out


func next_boss(night_index: int, defeated_ids: Array) -> Dictionary:
	var pool: Array = available_bosses(night_index, defeated_ids)
	if pool.is_empty():
		return {}
	# Prioriza el de menor night_min (progresión)
	pool.sort_custom(func(a, b):
		return int(a.get("night_min", a.get("day_min", 99))) < int(b.get("night_min", b.get("day_min", 99)))
	)
	return pool[0].duplicate(true)


func _arena_matches_period(arena: Dictionary, period: String) -> bool:
	if period == "":
		return true
	var periods: Array = arena.get("periods", [])
	if not periods.is_empty():
		return period in periods
	return str(arena.get("period", "")) == period or str(arena.get("period", "")) == ""


func _remember_arena(arena_id: String) -> void:
	if arena_id == "":
		return
	_recent_arena_ids.erase(arena_id)
	_recent_arena_ids.push_front(arena_id)
	while _recent_arena_ids.size() > RECENT_ARENA_LIMIT:
		_recent_arena_ids.pop_back()


func pick_arena_for_mission(mission: Dictionary, boss: Dictionary = {}) -> Dictionary:
	if not boss.is_empty():
		var pref := arena_by_id(str(boss.get("arena", "")))
		if not pref.is_empty():
			_remember_arena(str(pref.get("id", "")))
			return pref
	if arenas.is_empty():
		return {}
	var period := str(mission.get("period", "night"))
	var preferred: Array = []
	var fresh_preferred: Array = []
	var fresh_all: Array = []
	for a in arenas:
		var aid := str(a.get("id", ""))
		var recent := aid in _recent_arena_ids
		if _arena_matches_period(a, period):
			preferred.append(a)
			if not recent:
				fresh_preferred.append(a)
		if not recent:
			fresh_all.append(a)
	var pool: Array = fresh_preferred
	if pool.is_empty():
		pool = preferred
	if pool.is_empty():
		pool = fresh_all
	if pool.is_empty():
		pool = arenas
	var mid := str(mission.get("id", "x"))
	# Mezcla id de misión + cuántas arenas recientes para variar entre avisos.
	var salt := mid + ":arena:" + str(_recent_arena_ids.size()) + ":" + str(_recent_arena_ids)
	var pick: Dictionary = pool[absi(hash(salt)) % pool.size()]
	_remember_arena(str(pick.get("id", "")))
	return pick.duplicate(true)


func hero_pose(pose: String) -> String:
	var key := pose if pose in ["idle", "shoot", "hurt", "punch", "death", "walk", "run"] else "idle"
	var path := str(hero.get(key, ""))
	if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return path
	# Pack táctico García (mockup policial).
	var garcia := "res://assets/combat/anime/hero/garcia_%s.png" % key
	if ResourceLoader.exists(garcia) or FileAccess.file_exists(garcia):
		return garcia
	if key == "punch":
		var punch_fb := "res://assets/combat/anime/hero/garcia_shoot.png"
		if ResourceLoader.exists(punch_fb) or FileAccess.file_exists(punch_fb):
			return punch_fb
	# Legacy Kick-Ass solo si falta García.
	var fallback := "res://assets/combat/custom/hero/kickass_%s.png" % key
	if ResourceLoader.exists(fallback) or FileAccess.file_exists(fallback):
		return fallback
	if key == "punch":
		return "res://assets/combat/custom/hero/kickass_shoot.png"
	return "res://assets/combat/custom/hero/kickass_idle.png"
