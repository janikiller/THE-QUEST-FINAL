extends CanvasLayer
## Cambia entre Mapa / Lista de misiones / Pantalla de misión / Inventario.

signal request_open_missions
signal request_open_mission(mission_id: String)
signal request_back_to_map

@onready var map_hud: Control = $MapHud
@onready var missions_menu: Control = $MissionsMenu
@onready var mission_screen: Control = $MissionScreen
@onready var inventory_screen: Control = $InventoryScreen

var _opening_mission: bool = false


func _ready() -> void:
	show_map()
	GameState.selection_changed.connect(_on_selection)


func show_map() -> void:
	map_hud.visible = true
	missions_menu.visible = false
	mission_screen.visible = false
	inventory_screen.visible = false
	get_tree().paused = false
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color.WHITE
	request_back_to_map.emit()


func show_missions() -> void:
	map_hud.visible = false
	missions_menu.visible = true
	mission_screen.visible = false
	inventory_screen.visible = false
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.25, 0.3, 0.38, 1)
	request_open_missions.emit()


func show_mission(mission_id: String = "") -> void:
	if _opening_mission:
		return
	_opening_mission = true
	if mission_id != "":
		GameState.select_mission(mission_id)
	if GameState.get_selected_mission().is_empty():
		_opening_mission = false
		show_missions()
		return
	map_hud.visible = false
	missions_menu.visible = false
	mission_screen.visible = true
	inventory_screen.visible = false
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.15, 0.18, 0.25, 1)
	request_open_mission.emit(GameState.selected_mission_id)
	_opening_mission = false


func show_inventory(patrol_id: String = "") -> void:
	map_hud.visible = false
	missions_menu.visible = false
	mission_screen.visible = false
	inventory_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.18, 0.22, 0.3, 1)
	if inventory_screen.has_method("open"):
		inventory_screen.open(patrol_id)


func _on_selection(mission_id: String) -> void:
	# Abrir ficha solo al seleccionar desde el mapa (evita reentrada con show_mission).
	if _opening_mission:
		return
	if mission_id != "" and map_hud.visible and not mission_screen.visible:
		show_mission(mission_id)
