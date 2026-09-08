extends CanvasLayer
## Cambia entre Mapa / Lista / Misión / Resultado / Mazo / Combate.

signal request_open_missions
signal request_open_mission(mission_id: String)
signal request_back_to_map

@onready var map_hud: Control = $MapHud
@onready var missions_menu: Control = $MissionsMenu
@onready var mission_screen: Control = $MissionScreen
@onready var mission_result: Control = $MissionResult
@onready var deck_screen: Control = $DeckScreen
@onready var combat_screen: Control = $CombatScreen

var _opening_mission: bool = false


func _ready() -> void:
	add_to_group("ui_router")
	show_map()
	GameState.selection_changed.connect(_on_selection)


func _hide_all() -> void:
	map_hud.visible = false
	missions_menu.visible = false
	mission_screen.visible = false
	mission_result.visible = false
	deck_screen.visible = false
	combat_screen.visible = false


func show_map() -> void:
	_hide_all()
	map_hud.visible = true
	get_tree().paused = false
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color.WHITE
	request_back_to_map.emit()


func show_missions() -> void:
	_hide_all()
	missions_menu.visible = true
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
	_hide_all()
	mission_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.15, 0.18, 0.25, 1)
	request_open_mission.emit(GameState.selected_mission_id)
	_opening_mission = false


func show_mission_result(mission_id: String = "") -> void:
	_hide_all()
	mission_result.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.12, 0.14, 0.2, 1)
	if mission_result.has_method("open_for"):
		mission_result.open_for(mission_id)


func show_deck(patrol_id: String = "") -> void:
	_hide_all()
	deck_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.14, 0.18, 0.28, 1)
	if deck_screen.has_method("open"):
		deck_screen.open(patrol_id)


## Compat: antigua API de inventario → mazo
func show_inventory(patrol_id: String = "") -> void:
	show_deck(patrol_id)


func show_combat(mission_id: String, patrol_id: String = "alpha") -> void:
	_hide_all()
	combat_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.08, 0.1, 0.14, 1)
	if combat_screen.has_method("open_for_mission"):
		combat_screen.open_for_mission(mission_id, patrol_id)


func _on_selection(mission_id: String) -> void:
	if _opening_mission:
		return
	if mission_id != "" and map_hud.visible and not mission_screen.visible and not combat_screen.visible:
		show_mission(mission_id)
