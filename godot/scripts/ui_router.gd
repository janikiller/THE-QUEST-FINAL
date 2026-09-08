extends CanvasLayer
## Mapa / Misiones / Mazo / Combate. Entrar a misión = empieza la partida de cartas.

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
const HERO_PATROL := "alpha"


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


## Compat: la ficha táctica ya no es el destino — inicia combate.
func show_mission(mission_id: String = "") -> void:
	begin_intervention(mission_id)


## Clic en misión / marcador → García interviene (combate de cartas).
func begin_intervention(mission_id: String = "") -> void:
	if _opening_mission:
		return
	_opening_mission = true
	if mission_id != "":
		GameState.select_mission(mission_id)
	var m := GameState.get_selected_mission()
	if m.is_empty():
		_opening_mission = false
		show_missions()
		return

	var mid := str(m.get("id", ""))
	var pid := HERO_PATROL
	if not GameState.patrols.has(pid) and not GameState.patrols.is_empty():
		pid = str(GameState.patrols.keys()[0])

	# Si la misión está abierta, despachar a García y abrir combate ya.
	if str(m.get("status", "")) == "open":
		var patrol: Dictionary = GameState.patrols.get(pid, {})
		# Liberar si quedó colgada de un intento anterior.
		if str(patrol.get("status", "")) != "available":
			patrol["status"] = "available"
			patrol.erase("_awaiting_combat")
			patrol.erase("_pending_result_id")
			GameState.set_patrol(patrol)
		m["tactic"] = str(m.get("tactic", "entry"))
		GameState.update_mission(m)
		var dispatch = get_tree().get_first_node_in_group("dispatch")
		if dispatch and dispatch.has_method("dispatch"):
			var ok: bool = dispatch.dispatch(mid, pid)
			if not ok:
				RadioBus.push("No se pudo iniciar la intervención.", "alert")
				_opening_mission = false
				show_map()
				return
		patrol = GameState.patrols.get(pid, {})
		patrol["status"] = "on_scene"
		patrol["_awaiting_combat"] = true
		GameState.set_patrol(patrol)
		if dispatch and not CombatState.combat_ended.is_connected(dispatch._on_combat_ended):
			CombatState.combat_ended.connect(dispatch._on_combat_ended)
		RadioBus.push("García interviene: %s" % str(m.get("title", "misión")), "dispatch")

	request_open_mission.emit(mid)
	_opening_mission = false
	show_combat(mid, pid)


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
		deck_screen.open(patrol_id if patrol_id != "" else HERO_PATROL)


func show_inventory(patrol_id: String = "") -> void:
	show_deck(patrol_id)


func show_combat(mission_id: String, patrol_id: String = "alpha") -> void:
	_hide_all()
	combat_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.05, 0.06, 0.08, 1)
	if combat_screen.has_method("open_for_mission"):
		combat_screen.open_for_mission(mission_id, patrol_id)


func _on_selection(mission_id: String) -> void:
	if _opening_mission:
		return
	if mission_id != "" and map_hud.visible and not combat_screen.visible:
		begin_intervention(mission_id)
