extends CanvasLayer
## Mapa / Lista / Briefing (Luchar|Hablar) / Mazo / Mercado / Combate.

signal request_open_missions
signal request_open_mission(mission_id: String)
signal request_back_to_map

@onready var map_hud: Control = $MapHud
@onready var missions_menu: Control = $MissionsMenu
@onready var mission_screen: Control = $MissionScreen
@onready var mission_result: Control = $MissionResult
@onready var deck_screen: Control = $DeckScreen
@onready var market_screen: Control = $MarketScreen
@onready var combat_screen: Control = $CombatScreen
@onready var level_up_screen: Control = $LevelUpScreen

var _opening_mission: bool = false
const HERO_PATROL := "alpha"


func _ready() -> void:
	add_to_group("ui_router")
	show_map()
	# Ya no abrimos combate al seleccionar en mapa: las misiones van por menú.


func _hide_all() -> void:
	map_hud.visible = false
	missions_menu.visible = false
	mission_screen.visible = false
	mission_result.visible = false
	deck_screen.visible = false
	market_screen.visible = false
	combat_screen.visible = false
	level_up_screen.visible = false


func show_map() -> void:
	# Si hay sobres de nivel pendientes, priorízalos.
	if GameState.has_pending_level_packs():
		show_level_up(HERO_PATROL)
		return
	_hide_all()
	map_hud.visible = true
	get_tree().paused = false
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color.WHITE
	request_back_to_map.emit()


func show_level_up(patrol_id: String = "") -> void:
	if not GameState.has_pending_level_packs():
		_hide_all()
		map_hud.visible = true
		return
	_hide_all()
	level_up_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.08, 0.1, 0.16, 1)
	if level_up_screen.has_method("open"):
		level_up_screen.open(patrol_id if patrol_id != "" else HERO_PATROL)


func show_missions() -> void:
	_hide_all()
	missions_menu.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.25, 0.3, 0.38, 1)
	request_open_missions.emit()


## Briefing de misión: Luchar o Salir hablando.
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
		world.modulate = Color(0.12, 0.14, 0.2, 1)
	request_open_mission.emit(GameState.selected_mission_id)
	_opening_mission = false


func begin_fight(mission_id: String = "") -> void:
	if mission_id != "":
		GameState.select_mission(mission_id)
	var m := GameState.get_selected_mission()
	if m.is_empty():
		show_missions()
		return
	var mid := str(m.get("id", ""))
	var pid := HERO_PATROL
	if not GameState.patrols.has(pid) and not GameState.patrols.is_empty():
		pid = str(GameState.patrols.keys()[0])

	if str(m.get("status", "")) == "open":
		var patrol: Dictionary = GameState.patrols.get(pid, {})
		patrol["status"] = "available"
		patrol.erase("_awaiting_combat")
		patrol.erase("_pending_result_id")
		GameState.set_patrol(patrol)
		m["tactic"] = "entry"
		GameState.update_mission(m)
		var dispatch = get_tree().get_first_node_in_group("dispatch")
		if dispatch and dispatch.has_method("dispatch"):
			dispatch.dispatch(mid, pid)
		patrol = GameState.patrols.get(pid, {})
		patrol["status"] = "on_scene"
		patrol["_awaiting_combat"] = true
		GameState.set_patrol(patrol)
		if dispatch and not CombatState.combat_ended.is_connected(dispatch._on_combat_ended):
			CombatState.combat_ended.connect(dispatch._on_combat_ended)
		RadioBus.push("Kick-Ass entra en combate.", "dispatch")
	show_combat(mid, pid)


func resolve_talk(mission_id: String = "") -> void:
	if mission_id != "":
		GameState.select_mission(mission_id)
	var m := GameState.get_selected_mission()
	if m.is_empty():
		show_map()
		return
	# El Capo solo se cierra en combate.
	if bool(m.get("is_boss", false)):
		RadioBus.push("El Capo no negocia. Hay que enfrentarlo.", "alert")
		show_mission(str(m.get("id", "")))
		return
	var mid := str(m.get("id", ""))
	m["tactic"] = "negotiate"
	m["status"] = "resolved"
	m["outcome"] = "success"
	m["outcome_report"] = "Intervención dialogada. Sospechosos se entregan sin violencia."
	GameState.update_mission(m)
	GameState.set_mission_phase(mid, "final")
	GameState.add_mission_beat(mid, "DIÁLOGO", m["outcome_report"], "final")
	var snapshot: Dictionary = m.duplicate(true)
	GameState.store_resolved_mission(snapshot)
	GameState.add_prestige(1)
	GameState.add_credits(4)
	m["coins_earned"] = 4
	m["outcome_report"] = str(m.get("outcome_report", "")) + "  |  +4 monedas → Mercado"
	GameState.update_mission(m)
	GameState.store_resolved_mission(m.duplicate(true))
	GameState.advance_after_mission(m)
	RadioBus.push("Salida hablando: +4 monedas para el Mercado.", "resolve")
	# Liberar patrulla si estaba ligada
	for p in GameState.patrols.values():
		if str(p.get("mission_id", "")) == mid:
			p["status"] = "available"
			p["mission_id"] = ""
			p.erase("_awaiting_combat")
			GameState.set_patrol(p)
	show_mission_result(mid)


func show_mission_result(mission_id: String = "") -> void:
	_hide_all()
	mission_result.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.12, 0.14, 0.2, 1)
	if mission_result.has_method("open_for"):
		mission_result.open_for(mission_id)


func show_deck(patrol_id: String = "", mode: String = "mazo") -> void:
	_hide_all()
	deck_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.14, 0.18, 0.28, 1)
	if deck_screen.has_method("open"):
		deck_screen.open(patrol_id if patrol_id != "" else HERO_PATROL, mode)


func show_market(patrol_id: String = "") -> void:
	_hide_all()
	market_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.1, 0.14, 0.2, 1)
	if market_screen.has_method("open"):
		market_screen.open(patrol_id if patrol_id != "" else HERO_PATROL)


func show_inventory(patrol_id: String = "") -> void:
	show_deck(patrol_id)


func show_combat(mission_id: String, patrol_id: String = "alpha") -> void:
	_hide_all()
	combat_screen.visible = true
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(0.04, 0.05, 0.07, 1)
	# Asegura resolución de misión al terminar (también en shots/playtest).
	var pid := patrol_id if patrol_id != "" else HERO_PATROL
	if GameState.patrols.has(pid):
		var p: Dictionary = GameState.patrols[pid]
		if str(p.get("mission_id", "")) == "" and mission_id != "":
			p["mission_id"] = mission_id
		p["_awaiting_combat"] = true
		GameState.set_patrol(p)
	var dispatch = get_tree().get_first_node_in_group("dispatch")
	if dispatch and not CombatState.combat_ended.is_connected(dispatch._on_combat_ended):
		CombatState.combat_ended.connect(dispatch._on_combat_ended)
	if combat_screen.has_method("open_for_mission"):
		combat_screen.open_for_mission(mission_id, pid)


## Compat antigua
func begin_intervention(mission_id: String = "") -> void:
	show_mission(mission_id)
