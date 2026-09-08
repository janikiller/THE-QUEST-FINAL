extends Node2D
## Mapa 2D con ciclo día / atardecer / noche.

signal mission_clicked(mission_id: String)

@onready var map_sprite: Sprite2D = $MapSprite
@onready var map_sprite_b: Sprite2D = $MapSpriteB
@onready var districts_layer: Node2D = $Districts
@onready var markers_layer: Node2D = $Markers
@onready var patrols_layer: Node2D = $Patrols
@onready var hq_marker: Node2D = $HQ

const MissionMarkerScene := preload("res://scenes/mission_marker.tscn")
const PatrolUnitScene := preload("res://scenes/patrol_unit.tscn")

const TOD_TEXTURES := {
	"day": "res://assets/map/tod/day.jpg",
	"dusk": "res://assets/map/tod/dusk.jpg",
	"night": "res://assets/map/tod/night.jpg",
}

var _markers: Dictionary = {}
var _patrol_nodes: Dictionary = {}
var show_district_overlays: bool = false
var _tod: String = "day"
var _fade_tw: Tween


func _ready() -> void:
	_ensure_b_sprite()
	_setup_map_texture()
	_draw_district_overlays()
	_place_hq()
	_spawn_patrol_nodes()
	GameState.mission_added.connect(_on_mission_added)
	GameState.mission_updated.connect(_on_mission_updated)
	GameState.mission_removed.connect(_on_mission_removed)
	GameState.patrol_updated.connect(_on_patrol_updated)
	GameState.selection_changed.connect(_on_selection_changed)
	GameState.time_changed.connect(_on_time_changed)
	_apply_tod(GameState.time_of_day(), true)


func _ensure_b_sprite() -> void:
	if map_sprite_b == null:
		map_sprite_b = Sprite2D.new()
		map_sprite_b.name = "MapSpriteB"
		map_sprite_b.centered = false
		map_sprite_b.z_index = map_sprite.z_index
		map_sprite.add_sibling(map_sprite_b)
		map_sprite_b = $MapSpriteB


func refresh_district_overlays() -> void:
	_draw_district_overlays()


func _setup_map_texture() -> void:
	map_sprite.centered = false
	map_sprite.position = Vector2.ZERO
	map_sprite_b.centered = false
	map_sprite_b.position = Vector2.ZERO
	map_sprite_b.modulate.a = 0.0


func map_size() -> Vector2:
	var s: Array = GameState.station.get("map_size", [1536, 1024])
	return Vector2(float(s[0]), float(s[1]))


func _on_time_changed(_label: String) -> void:
	_apply_tod(GameState.time_of_day(), false)


func _apply_tod(tod: String, instant: bool = false) -> void:
	if tod == _tod and map_sprite.texture != null and not instant:
		return
	var path := str(TOD_TEXTURES.get(tod, TOD_TEXTURES["day"]))
	if not ResourceLoader.exists(path):
		path = str(GameState.station.get("map_texture", "res://assets/map/city_map.jpg"))
	var tex: Texture2D = load(path)
	if instant or map_sprite.texture == null:
		map_sprite.texture = tex
		map_sprite.modulate.a = 1.0
		map_sprite_b.modulate.a = 0.0
		_tod = tod
		return
	# Crossfade A -> B
	map_sprite_b.texture = tex
	map_sprite_b.modulate.a = 0.0
	if _fade_tw:
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(map_sprite_b, "modulate:a", 1.0, 1.4)
	_fade_tw.parallel().tween_property(map_sprite, "modulate:a", 0.0, 1.4)
	_fade_tw.tween_callback(func():
		map_sprite.texture = tex
		map_sprite.modulate.a = 1.0
		map_sprite_b.modulate.a = 0.0
		_tod = tod
	)


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
	mission_clicked.emit(mission_id)
	GameState.select_mission(mission_id)


func random_point_in_district(district: Dictionary) -> Vector2:
	var r: Array = district["rect"]
	var best := Vector2(
		float(r[0]) + float(r[2]) * 0.5,
		float(r[1]) + float(r[3]) * 0.5
	)
	for _i in 18:
		var x: float = float(r[0]) + 28.0 + GameState._rng.randf() * max(8.0, float(r[2]) - 56.0)
		var y: float = float(r[1]) + 28.0 + GameState._rng.randf() * max(8.0, float(r[3]) - 56.0)
		var p := Vector2(x, y)
		if RoadNav.is_road_world(p):
			return p
		best = p
	return RoadNav.nearest_road(best)
