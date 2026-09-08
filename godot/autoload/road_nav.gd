extends Node
## Navegación por carreteras del mapa (A* sobre rejilla).

var cell: int = 8
var width: int = 192
var height: int = 128
var map_width: int = 1536
var map_height: int = 1024
var walkable: PackedByteArray = PackedByteArray() ## row-major, 1 = road


func _ready() -> void:
	_load()


func _load() -> void:
	var meta_path := "res://assets/map/road_nav.json"
	var png_path := "res://assets/map/road_nav.png"
	if FileAccess.file_exists(meta_path):
		var f := FileAccess.open(meta_path, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			cell = int(data.get("cell", 8))
			width = int(data.get("width", 192))
			height = int(data.get("height", 128))
			map_width = int(data.get("map_width", 1536))
			map_height = int(data.get("map_height", 1024))
	walkable.resize(width * height)
	walkable.fill(0)
	var img := Image.new()
	var err := img.load(png_path)
	if err != OK:
		push_warning("RoadNav: no se pudo cargar %s" % png_path)
		return
	if img.get_width() != width or img.get_height() != height:
		img.resize(width, height, Image.INTERPOLATE_NEAREST)
	for y in range(height):
		for x in range(width):
			var c := img.get_pixel(x, y)
			walkable[y * width + x] = 1 if c.r > 0.45 else 0
	print("RoadNav ready ", width, "x", height, " roads=", _count_roads())


func _count_roads() -> int:
	var n := 0
	for i in range(walkable.size()):
		n += int(walkable[i])
	return n


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(pos.x / cell), 0, width - 1), clampi(int(pos.y / cell), 0, height - 1))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * cell, (c.y + 0.5) * cell)


func is_road_cell(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return false
	return walkable[c.y * width + c.x] == 1


func is_road_world(pos: Vector2) -> bool:
	return is_road_cell(world_to_cell(pos))


func nearest_road(pos: Vector2, max_radius_cells: int = 24) -> Vector2:
	var c0 := world_to_cell(pos)
	if is_road_cell(c0):
		return cell_to_world(c0)
	for r in range(1, max_radius_cells + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var c := Vector2i(c0.x + dx, c0.y + dy)
				if is_road_cell(c):
					return cell_to_world(c)
	return pos


## A*: coste 1 en carretera, coste alto fuera (evita edificios si hay alternativa).
func find_path(from: Vector2, to: Vector2) -> Array:
	var start := world_to_cell(nearest_road(from))
	var goal := world_to_cell(nearest_road(to))
	if start == goal:
		return [cell_to_world(goal)]

	var open: Array = [start] ## Vector2i
	var open_set: Dictionary = {start: true}
	var came: Dictionary = {} ## Vector2i -> Vector2i
	var gscore: Dictionary = {}
	var fscore: Dictionary = {}
	gscore[start] = 0.0
	fscore[start] = float(_heuristic(start, goal))

	var closed: Dictionary = {}
	var guard := 0
	while not open.is_empty() and guard < 25000:
		guard += 1
		var current: Vector2i = _pop_best(open, fscore)
		open_set.erase(current)
		if current == goal:
			return _reconstruct(came, current, to)
		closed[current] = true
		for n in _neighbors(current):
			if closed.has(n):
				continue
			var step := 1.0 if is_road_cell(n) else 18.0
			if not is_road_cell(n) and not is_road_cell(current):
				step = 40.0
			var tentative: float = float(gscore.get(current, 1e12)) + step
			if tentative < float(gscore.get(n, 1e12)):
				came[n] = current
				gscore[n] = tentative
				fscore[n] = tentative + float(_heuristic(n, goal))
				if not open_set.has(n):
					open.append(n)
					open_set[n] = true

	# Fallback: straight-ish snapped points
	return [nearest_road(from), nearest_road(to)]


func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _neighbors(c: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x >= 0 and n.y >= 0 and n.x < width and n.y < height:
			out.append(n)
	return out


func _pop_best(open: Array, fscore: Dictionary) -> Vector2i:
	var best_i := 0
	var best_f: float = float(fscore.get(open[0], 1e12))
	for i in range(1, open.size()):
		var f: float = float(fscore.get(open[i], 1e12))
		if f < best_f:
			best_f = f
			best_i = i
	var node: Vector2i = open[best_i]
	open.remove_at(best_i)
	return node


func _reconstruct(came: Dictionary, current: Vector2i, final_world: Vector2) -> Array:
	var cells: Array = [current]
	while came.has(current):
		current = came[current]
		cells.push_front(current)
	# Simplify: keep every Nth + corners
	var path: Array = []
	for i in range(cells.size()):
		if i == 0 or i == cells.size() - 1 or i % 2 == 0:
			path.append(cell_to_world(cells[i]))
	# End exactly at nearest road to destination
	path.append(nearest_road(final_world))
	return path
