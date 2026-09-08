extends Node
## Escena principal: mapa real + HUD con pestañas.

@onready var city_map: Node2D = $World/CityMap
@onready var camera: Camera2D = $World/Camera2D
@onready var world: Node2D = $World


func _ready() -> void:
	world.add_to_group("world_root")
	city_map.mission_clicked.connect(_on_mission_clicked)
	_frame_camera()
	print("COMISARIA_READY missions=", GameState.active_missions.size(), " patrols=", GameState.patrols.size())
	if OS.get_environment("TQ_SMOKE") == "1":
		call_deferred("_smoke")


func _frame_camera() -> void:
	var size: Vector2 = city_map.map_size()
	camera.position = size * 0.5
	# Leave room for the right dock (~420px) on 1600-wide window
	camera.zoom = Vector2(0.72, 0.72)


func _on_mission_clicked(_mission_id: String) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoom = (camera.zoom * 1.08).clamp(Vector2(0.45, 0.45), Vector2(1.6, 1.6))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoom = (camera.zoom / 1.08).clamp(Vector2(0.45, 0.45), Vector2(1.6, 1.6))
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera.position -= event.relative / camera.zoom
	elif event.is_action_pressed("focus_map"):
		GameState.select_mission("")


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
