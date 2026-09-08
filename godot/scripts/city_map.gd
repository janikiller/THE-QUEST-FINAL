extends Node2D
## Mapa 2D de la ciudad: distritos, calles y marcadores de misión.

signal mission_clicked(mission_id: String)

@onready var districts_layer: Node2D = $Districts
@onready var roads_layer: Node2D = $Roads
@onready var markers_layer: Node2D = $Markers
@onready var patrols_layer: Node2D = $Patrols
@onready var hq_marker: Node2D = $HQ

const MissionMarkerScene := preload("res://scenes/mission_marker.tscn")
const PatrolUnitScene := preload("res://scenes/patrol_unit.tscn")

var _markers: Dictionary = {} # mission_id -> marker
var _patrol_nodes: Dictionary = {} # patrol_id -> node


func _ready() -> void:
	_draw_city()
	_place_hq()
	_spawn_patrol_nodes()
	GameState.mission_added.connect(_on_mission_added)
	GameState.mission_updated.connect(_on_mission_updated)
	GameState.mission_removed.connect(_on_mission_removed)
	GameState.patrol_updated.connect(_on_patrol_updated)
	GameState.selection_changed.connect(_on_selection_changed)


func _draw_city() -> void:
	for child in districts_layer.get_children():
		child.queue_free()
	for child in roads_layer.get_children():
		child.queue_free()

	# Soft night backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.12, 1)
	bg.position = Vector2(40, 40)
	bg.size = Vector2(720, 560)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	districts_layer.add_child(bg)

	for d in GameState.station.get("districts", []):
		var r: Array = d["rect"]
		var rect := ColorRect.new()
		rect.position = Vector2(float(r[0]), float(r[1]))
		rect.size = Vector2(float(r[2]), float(r[3]))
		rect.color = Color(d.get("color", "#2a3a55"))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		districts_layer.add_child(rect)

		var border := Line2D.new()
		border.width = 2.0
		border.default_color = Color(0.88, 0.7, 0.35, 0.35)
		border.add_point(rect.position)
		border.add_point(rect.position + Vector2(rect.size.x, 0))
		border.add_point(rect.position + rect.size)
		border.add_point(rect.position + Vector2(0, rect.size.y))
		border.add_point(rect.position)
		roads_layer.add_child(border)

		var label := Label.new()
		label.text = str(d["name"]).to_upper()
		label.position = rect.position + Vector2(10, 8)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.7))
		districts_layer.add_child(label)

	# Main avenues
	_add_road(Vector2(60, 300), Vector2(740, 300), 14)
	_add_road(Vector2(360, 50), Vector2(360, 620), 12)
	_add_road(Vector2(100, 500), Vector2(700, 180), 8)


func _add_road(a: Vector2, b: Vector2, width: float) -> void:
	var road := Line2D.new()
	road.width = width
	road.default_color = Color(0.12, 0.14, 0.18, 1)
	road.add_point(a)
	road.add_point(b)
	roads_layer.add_child(road)
	var lane := Line2D.new()
	lane.width = 1.5
	lane.default_color = Color(0.9, 0.75, 0.35, 0.25)
	lane.add_point(a)
	lane.add_point(b)
	roads_layer.add_child(lane)


func _place_hq() -> void:
	var hq: Array = GameState.station.get("hq_pos", [180, 160])
	hq_marker.position = Vector2(float(hq[0]), float(hq[1]))


func _spawn_patrol_nodes() -> void:
	for child in patrols_layer.get_children():
		child.queue_free()
	_patrol_nodes.clear()
	for p in GameState.patrols.values():
		var node: Node2D = PatrolUnitScene.instantiate()
		patrols_layer.add_child(node)
		node.setup(p)
		_patrol_nodes[p["id"]] = node


func _on_mission_added(mission: Dictionary) -> void:
	var marker: Node2D = MissionMarkerScene.instantiate()
	markers_layer.add_child(marker)
	marker.setup(mission)
	marker.pressed.connect(_on_marker_pressed)
	_markers[mission["id"]] = marker


func _on_mission_updated(mission: Dictionary) -> void:
	if _markers.has(mission["id"]):
		_markers[mission["id"]].refresh(mission)


func _on_mission_removed(mission_id: String) -> void:
	if _markers.has(mission_id):
		_markers[mission_id].queue_free()
		_markers.erase(mission_id)


func _on_patrol_updated(patrol: Dictionary) -> void:
	if _patrol_nodes.has(patrol["id"]):
		_patrol_nodes[patrol["id"]].refresh(patrol)


func _on_selection_changed(mission_id: String) -> void:
	for id in _markers.keys():
		_markers[id].set_selected(id == mission_id)


func _on_marker_pressed(mission_id: String) -> void:
	GameState.select_mission(mission_id)
	mission_clicked.emit(mission_id)


func random_point_in_district(district: Dictionary) -> Vector2:
	var r: Array = district["rect"]
	var x: float = float(r[0]) + 24.0 + GameState._rng.randf() * max(8.0, float(r[2]) - 48.0)
	var y: float = float(r[1]) + 28.0 + GameState._rng.randf() * max(8.0, float(r[3]) - 56.0)
	return Vector2(x, y)
