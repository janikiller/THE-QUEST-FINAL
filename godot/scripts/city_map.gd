extends Node2D
## Mapa 2D con la ciudad real + marcadores y patrullas.

signal mission_clicked(mission_id: String)

@onready var map_sprite: Sprite2D = $MapSprite
@onready var districts_layer: Node2D = $Districts
@onready var markers_layer: Node2D = $Markers
@onready var patrols_layer: Node2D = $Patrols
@onready var hq_marker: Node2D = $HQ

const MissionMarkerScene := preload("res://scenes/mission_marker.tscn")
const PatrolUnitScene := preload("res://scenes/patrol_unit.tscn")

var _markers: Dictionary = {}
var _patrol_nodes: Dictionary = {}
var show_district_overlays: bool = false


func _ready() -> void:
	_setup_map_texture()
	_draw_district_overlays()
	_place_hq()
	_spawn_patrol_nodes()
	GameState.mission_added.connect(_on_mission_added)
	GameState.mission_updated.connect(_on_mission_updated)
	GameState.mission_removed.connect(_on_mission_removed)
	GameState.patrol_updated.connect(_on_patrol_updated)
	GameState.selection_changed.connect(_on_selection_changed)


func refresh_district_overlays() -> void:
	_draw_district_overlays()


func _setup_map_texture() -> void:
	var path := str(GameState.station.get("map_texture", "res://assets/map/city_map.jpg"))
	if ResourceLoader.exists(path):
		map_sprite.texture = load(path)
	map_sprite.centered = false
	map_sprite.position = Vector2.ZERO


func map_size() -> Vector2:
	var s: Array = GameState.station.get("map_size", [1536, 1024])
	return Vector2(float(s[0]), float(s[1]))


func _draw_district_overlays() -> void:
	for child in districts_layer.get_children():
		child.queue_free()
	if not show_district_overlays:
		return
	for d in GameState.station.get("districts", []):
		var r: Array = d["rect"]
		var rect := ColorRect.new()
		rect.position = Vector2(float(r[0]), float(r[1]))
		rect.size = Vector2(float(r[2]), float(r[3]))
		rect.color = Color(d.get("color", "#2a6bff22"))
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		districts_layer.add_child(rect)

		var label := Label.new()
		label.text = str(d["name"]).to_upper()
		label.position = rect.position + Vector2(10, 8)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.85))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("outline_size", 4)
		districts_layer.add_child(label)


func _place_hq() -> void:
	var hq: Array = GameState.station.get("hq_pos", [748, 470])
	hq_marker.position = Vector2(float(hq[0]), float(hq[1]))
	var pulse: ColorRect = hq_marker.get_node("HQPulse")
	var tw := create_tween().set_loops()
	tw.tween_property(pulse, "modulate:a", 0.25, 1.1).from(0.85)
	tw.parallel().tween_property(pulse, "scale", Vector2(1.35, 1.35), 1.1).from(Vector2.ONE)


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
	# Solo emitimos; GameState + UIRouter abren la ficha sin doble select.
	mission_clicked.emit(mission_id)
	GameState.select_mission(mission_id)


func random_point_in_district(district: Dictionary) -> Vector2:
	var r: Array = district["rect"]
	var best := Vector2(
		float(r[0]) + float(r[2]) * 0.5,
		float(r[1]) + float(r[3]) * 0.5
	)
	# Prefer a road cell inside the district
	for _i in 18:
		var x: float = float(r[0]) + 28.0 + GameState._rng.randf() * max(8.0, float(r[2]) - 56.0)
		var y: float = float(r[1]) + 28.0 + GameState._rng.randf() * max(8.0, float(r[3]) - 56.0)
		var p := Vector2(x, y)
		if RoadNav.is_road_world(p):
			return p
		best = p
	return RoadNav.nearest_road(best)
