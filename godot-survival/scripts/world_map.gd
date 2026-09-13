extends Node2D
class_name WorldMap

enum Tile {
	VOID, ROAD, SIDEWALK, CROSSWALK, PARK, PARKING, ALLEY,
	FLOOR, WALL, DOOR, WATER, RUBBLE, BASE, BARRICADE
}

const SIZE := 64
const BLOCK := 8
const ROAD_W := 2
const TILE_PX := 48.0

var tiles := PackedInt32Array()
var spawn := Vector2(SIZE * 0.5, SIZE * 0.5)
var furniture := {}
var loot := {}
var doors := {}
var lamps: Array[Vector2i] = []
var _col: Node2D

func generate(p_seed := 0) -> void:
	if p_seed != 0:
		seed(p_seed)
	tiles.resize(SIZE * SIZE)
	tiles.fill(Tile.PARK)
	furniture.clear(); loot.clear(); doors.clear(); lamps.clear()
	_carve(); _find_spawn(); queue_redraw()

func tile_at(x: float, y: float) -> int:
	var tx := int(floor(x)); var ty := int(floor(y))
	if tx < 0 or ty < 0 or tx >= SIZE or ty >= SIZE:
		return Tile.WALL
	return tiles[ty * SIZE + tx]

func set_tile(tx: int, ty: int, t: int) -> void:
	if tx < 0 or ty < 0 or tx >= SIZE or ty >= SIZE: return
	tiles[ty * SIZE + tx] = t
	queue_redraw(); _col_cell(tx, ty)

func can_walk(x: float, y: float, opts := {}) -> bool:
	var t := tile_at(x, y)
	match t:
		Tile.WALL, Tile.VOID, Tile.WATER: return false
		Tile.BARRICADE: return bool(opts.get("bullet", false))
		Tile.DOOR:
			var key := "%d,%d" % [int(floor(x)), int(floor(y))]
			if float(doors.get(key, 0)) > 0.0:
				return bool(opts.get("player", false)) or bool(opts.get("bullet", false))
			return true
		_: return true

func world_to_px(v: Vector2) -> Vector2: return v * TILE_PX
func px_to_world(v: Vector2) -> Vector2: return v / TILE_PX

func build_collisions(root: Node2D) -> void:
	_col = root
	for c in root.get_children(): c.queue_free()
	for y in SIZE:
		for x in SIZE:
			_col_cell(x, y)

func nearest_furniture(pos: Vector2, radius := 1.35) -> Dictionary:
	var best := {}; var best_d := radius
	for key in furniture.keys():
		var p := str(key).split(",")
		var fx := float(p[0]) + 0.5; var fy := float(p[1]) + 0.5
		var d := pos.distance_to(Vector2(fx, fy))
		if d < best_d:
			best_d = d
			best = furniture[key].duplicate()
			best.key = key; best.pos = Vector2(fx, fy)
	return best

func take_floor_loot(pos: Vector2) -> Dictionary:
	var tx := int(floor(pos.x)); var ty := int(floor(pos.y))
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var key := "%d,%d" % [tx + ox, ty + oy]
			if loot.has(key):
				var item: Dictionary = loot[key]
				loot.erase(key); queue_redraw(); return item
	return {}

func search_container(key: String) -> Dictionary:
	if not furniture.has(key): return {"empty": true}
	var f: Dictionary = furniture[key]
	if bool(f.get("searched", false)): return {"already": true, "label": f.label}
	f.searched = true; furniture[key] = f; queue_redraw()
	var pick := _weighted(_loot_table(str(f.type)))
	if bool(pick.get("empty", false)): return {"empty": true, "label": f.label}
	return {"id": pick.id, "amount": int(pick.get("amount", 1)), "label": f.label}

func _col_cell(x: int, y: int) -> void:
	if _col == null: return
	var n := "c_%d_%d" % [x, y]
	var old := _col.get_node_or_null(n)
	if old: old.queue_free()
	var t := tiles[y * SIZE + x]
	var solid := t == Tile.WALL or t == Tile.WATER or t == Tile.BARRICADE
	if t == Tile.DOOR: solid = float(doors.get("%d,%d" % [x, y], 0)) > 0.0
	if not solid: return
	var body := StaticBody2D.new(); body.name = n
	body.collision_layer = 1; body.collision_mask = 0
	body.position = Vector2(x + 0.5, y + 0.5) * TILE_PX
	var cs := CollisionShape2D.new(); var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_PX, TILE_PX); cs.shape = rect
	body.add_child(cs); _col.add_child(body)

func _carve() -> void:
	var canal_y := int(SIZE * 0.62)
	for x in SIZE:
		for dy in range(-1, 2): 			_put(x, canal_y + dy, Tile.WATER)
	var step := BLOCK + ROAD_W
	for by in range(2, SIZE - 2, step):
		for bx in range(2, SIZE - 2, step):
			_roads(bx, by)
			if by + BLOCK >= canal_y - 2 and by <= canal_y + 2:
				_fill(bx + ROAD_W, by + ROAD_W, Tile.PARK, 0.04, "wood")
			elif (bx + by) % 3 == 0:
				_fill(bx + ROAD_W, by + ROAD_W, Tile.PARKING, 0.05, "")
			elif (bx * 3 + by) % 5 == 0:
				_alley(bx + ROAD_W, by + ROAD_W)
			else:
				_building(bx + ROAD_W, by + ROAD_W)
	for y in range(3, SIZE - 3, step):
		for x in range(3, SIZE - 3, step):
			lamps.append(Vector2i(x, y))
			if randf() < 0.35:
				loot["%d,%d" % [x + 1, y]] = {"id": _rand_loot(), "amount": 1}

func _roads(bx: int, by: int) -> void:
	for i in range(BLOCK + ROAD_W):
		for w in ROAD_W:
			_put(bx + i, by + w, Tile.ROAD); _put(bx + w, by + i, Tile.ROAD)
			if i == int(BLOCK / 2.0):
				_put(bx + i, by + w, Tile.CROSSWALK); _put(bx + w, by + i, Tile.CROSSWALK)
	for i in range(1, BLOCK + 1):
		_put(bx + ROAD_W + i - 1, by + ROAD_W - 1, Tile.SIDEWALK)
		_put(bx + ROAD_W - 1, by + ROAD_W + i - 1, Tile.SIDEWALK)

func _fill(ox: int, oy: int, t: int, chance: float, fixed: String) -> void:
	for y in range(oy, mini(oy + BLOCK - 1, SIZE)):
		for x in range(ox, mini(ox + BLOCK - 1, SIZE)):
			_put(x, y, t)
			if chance > 0.0 and randf() < chance:
				loot["%d,%d" % [x, y]] = {"id": fixed if fixed != "" else _rand_loot(), "amount": 1}

func _alley(ox: int, oy: int) -> void:
	for y in range(oy, mini(oy + BLOCK - 1, SIZE)):
		for x in range(ox, mini(ox + BLOCK - 1, SIZE)):
			_put(x, y, Tile.ALLEY if (x + y) % 2 == 0 else Tile.RUBBLE)

func _building(ox: int, oy: int) -> void:
	var w := BLOCK - 2; var h := BLOCK - 2
	if w < 4 or h < 4: return
	var x0 := ox; var y0 := oy; var x1 := ox + w; var y1 := oy + h
	for y in range(y0, y1):
		for x in range(x0, x1):
			_put(x, y, Tile.WALL if (x == x0 or y == y0 or x == x1 - 1 or y == y1 - 1) else Tile.FLOOR)
	var door := Vector2i(x0 + int(w / 2.0), y1 - 1)
	_put(door.x, door.y, Tile.DOOR); doors["%d,%d" % [door.x, door.y]] = 55.0
	_put(door.x, door.y + 1, Tile.SIDEWALK)
	var types := ["shelf", "desk", "fridge", "locker", "cabinet", "nightstand"]
	for i in range(3 + randi() % 4):
		var fx := x0 + 1 + randi() % maxi(1, x1 - x0 - 2)
		var fy := y0 + 1 + randi() % maxi(1, y1 - y0 - 2)
		var key := "%d,%d" % [fx, fy]
		if furniture.has(key): continue
		var ft: String = types[randi() % types.size()]
		furniture[key] = {"type": ft, "label": _furn_label(ft), "searched": false}

func _furn_label(t: String) -> String:
	match t:
		"shelf": return "Estantería"
		"desk": return "Escritorio"
		"fridge": return "Nevera"
		"locker": return "Taquilla"
		"cabinet": return "Armario"
		"nightstand": return "Mesilla"
		_: return "Mueble"

func _find_spawn() -> void:
	for i in 200:
		var x := 4 + randi() % (SIZE - 8); var y := 4 + randi() % (SIZE - 8)
		var t := tile_at(x + 0.5, y + 0.5)
		if t == Tile.ROAD or t == Tile.SIDEWALK:
			spawn = Vector2(x + 0.5, y + 0.5); return
	spawn = Vector2(SIZE * 0.5, SIZE * 0.5)

func _put(x: int, y: int, t: int) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE: return
	tiles[y * SIZE + x] = t

func _rand_loot() -> String:
	var r := randf()
	if r < 0.2: return "food"
	if r < 0.35: return "water"
	if r < 0.5: return "scrap"
	if r < 0.65: return "wood"
	if r < 0.75: return "med"
	if r < 0.85: return "ammo_9mm"
	if r < 0.9: return "flashlight"
	if r < 0.95: return "shirt"
	return "knife"

func _loot_table(ft: String) -> Array:
	match ft:
		"fridge": return [{"id":"food","w":3},{"id":"water","w":3},{"id":"med","w":1},{"empty":true,"w":1}]
		"locker": return [{"id":"scrap","w":2},{"id":"bat","w":1},{"id":"pistol","w":1},{"id":"ammo_9mm","w":2},{"id":"rifle","w":1},{"id":"ammo_rifle","w":1},{"id":"vest","w":1},{"id":"flashlight","w":2},{"empty":true,"w":2}]
		"desk": return [{"id":"scrap","w":2},{"id":"knife","w":1},{"id":"ammo_9mm","w":2},{"id":"pistol","w":1},{"empty":true,"w":2}]
		"nightstand": return [{"id":"med","w":2},{"id":"knife","w":1},{"id":"ammo_9mm","w":1},{"empty":true,"w":1}]
		_: return [{"id":"food","w":2},{"id":"scrap","w":2},{"id":"wood","w":2},{"id":"hoodie","w":1},{"id":"bag","w":1},{"empty":true,"w":2}]

func _weighted(table: Array) -> Dictionary:
	var total := 0
	for e in table: total += int(e.w)
	var r := randi() % maxi(1, total); var acc := 0
	for e in table:
		acc += int(e.w)
		if r < acc: return e
	return table.back()

func _draw() -> void:
	var colors := {
		Tile.ROAD: Color(0.22, 0.23, 0.24), Tile.SIDEWALK: Color(0.35, 0.36, 0.34),
		Tile.CROSSWALK: Color(0.45, 0.45, 0.4), Tile.PARK: Color(0.18, 0.32, 0.2),
		Tile.PARKING: Color(0.28, 0.28, 0.3), Tile.ALLEY: Color(0.2, 0.2, 0.18),
		Tile.FLOOR: Color(0.32, 0.28, 0.24), Tile.WALL: Color(0.12, 0.12, 0.11),
		Tile.DOOR: Color(0.4, 0.28, 0.16), Tile.WATER: Color(0.12, 0.28, 0.38),
		Tile.RUBBLE: Color(0.3, 0.26, 0.22), Tile.BASE: Color(0.28, 0.4, 0.25),
		Tile.BARRICADE: Color(0.45, 0.32, 0.15), Tile.VOID: Color(0.05, 0.05, 0.05),
	}
	for y in SIZE:
		for x in SIZE:
			draw_rect(Rect2(Vector2(x, y) * TILE_PX, Vector2.ONE * TILE_PX), colors.get(tiles[y * SIZE + x], Color.MAGENTA))
	for key in furniture.keys():
		var p := str(key).split(",")
		var origin := Vector2(float(p[0]), float(p[1])) * TILE_PX
		var f: Dictionary = furniture[key]
		draw_rect(Rect2(origin + Vector2(8, 8), Vector2(32, 32)), Color(0.55, 0.4, 0.25) if not bool(f.searched) else Color(0.3, 0.25, 0.2))
	for key in loot.keys():
		var p := str(key).split(",")
		draw_circle(Vector2(float(p[0]) + 0.5, float(p[1]) + 0.5) * TILE_PX, 5.0, Color(0.95, 0.8, 0.35))
	for lamp in lamps:
		var lp := (Vector2(lamp) + Vector2(0.5, 0.5)) * TILE_PX
		draw_circle(lp, 4.0, Color(0.7, 0.7, 0.55))
		draw_rect(Rect2(lp - Vector2(2, 10), Vector2(4, 10)), Color(0.25, 0.25, 0.22))
