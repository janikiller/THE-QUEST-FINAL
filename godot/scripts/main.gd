extends Node
## Mapa jugable a pantalla grande + pantallas de misión aparte.

@onready var city_map: Node2D = $World/CityMap
@onready var camera: Camera2D = $World/Camera2D
@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/PlayerAgent

const ZOOM_MIN := Vector2(0.85, 0.85)
const ZOOM_MAX := Vector2(1.8, 1.8)


func _ready() -> void:
	world.add_to_group("world_root")
	city_map.show_district_overlays = false
	city_map.mission_clicked.connect(_on_mission_clicked)
	camera.zoom = Vector2(1.25, 1.25)
	camera.position = player.global_position
	print("COMISARIA_READY missions=", GameState.active_missions.size(), " patrols=", GameState.patrols.size())
	if OS.get_environment("TQ_SMOKE") == "1":
		call_deferred("_smoke")
	if OS.get_environment("TQ_INV") == "1":
		call_deferred("_inv_check")


func _process(_delta: float) -> void:
	# Camera follows player on map (game feel)
	if is_instance_valid(player) and $UI/UIRouter/MapHud.visible:
		camera.global_position = camera.global_position.lerp(player.global_position, 0.15)


func _on_mission_clicked(mission_id: String) -> void:
	GameState.select_mission(mission_id)
	$UI/UIRouter.show_mission(mission_id)


func _unhandled_input(event: InputEvent) -> void:
	if not $UI/UIRouter/MapHud.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoom = (camera.zoom * 1.08).clamp(ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoom = (camera.zoom / 1.08).clamp(ZOOM_MIN, ZOOM_MAX)


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
	print("COMISARIA_SMOKE dispatch=", ok)
	await get_tree().create_timer(1.5).timeout
	print("COMISARIA_SMOKE_OK")
	get_tree().quit(0 if ok else 5)


func _inv_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var errors: Array = []
	print("INV items=", ItemDB.items.size())
	if ItemDB.items.is_empty():
		errors.append("empty ItemDB")
	GameState.ensure_patrol_inventory("alpha")
	var before := GameState.get_slot_item("alpha", "shared", 0)
	GameState.swap_inventory_slots("alpha", "shared", 0, "trunk", 0)
	var after := GameState.get_slot_item("alpha", "trunk", 0)
	print("INV swap=", before, "->", after)
	if after != before:
		errors.append("swap failed")
	$UI/UIRouter.show_inventory("alpha")
	await get_tree().process_frame
	await get_tree().process_frame
	var screen = $UI/UIRouter/InventoryScreen
	print("INV slots shared=", screen._shared_slots.size(), " trunk=", screen._trunk_slots.size(), " agents=", screen._agent_slots.size())
	if screen._shared_slots.size() != GameState.SHARED_SIZE:
		errors.append("shared size")
	if screen._trunk_slots.size() != GameState.TRUNK_SIZE:
		errors.append("trunk size")
	if errors.is_empty():
		print("OK_INVENTORY")
		get_tree().quit(0)
	else:
		print("INV_ERRORS ", errors)
		get_tree().quit(1)
