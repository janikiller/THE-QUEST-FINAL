extends Node
## Escena principal: conecta mapa, spawner, despacho y HUD.

@onready var city_map: Node2D = $World/CityMap
@onready var hud: Control = $UI/HQHud
@onready var camera: Camera2D = $World/Camera2D


func _ready() -> void:
	city_map.mission_clicked.connect(_on_mission_clicked)
	camera.position = Vector2(420, 340)
	print("COMISARIA_READY missions=", GameState.active_missions.size(), " patrols=", GameState.patrols.size())
	if OS.get_environment("TQ_SMOKE") == "1":
		call_deferred("_smoke")


func _smoke() -> void:
	await get_tree().create_timer(1.2).timeout
	print("COMISARIA_SMOKE missions=", GameState.active_missions.size())
	if GameState.active_missions.is_empty() or GameState.available_patrols().is_empty():
		push_error("SMOKE_FAIL empty state")
		get_tree().quit(2)
		return
	var mid: String = String(GameState.active_missions.keys()[0])
	var pid: String = String(GameState.available_patrols()[0]["id"])
	var dispatch = get_tree().get_first_node_in_group("dispatch")
	var ok: bool = dispatch.dispatch(mid, pid)
	print("COMISARIA_SMOKE dispatch=", ok, " mission=", mid, " patrol=", pid)
	await get_tree().create_timer(2.5).timeout
	var st: String = String(GameState.patrols[pid]["status"])
	print("COMISARIA_SMOKE patrol_status=", st)
	print("COMISARIA_SMOKE_OK")
	get_tree().quit(0 if ok else 5)


func _on_mission_clicked(_mission_id: String) -> void:
	# HUD listens via GameState.selection_changed
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("focus_map"):
		GameState.select_mission("")
