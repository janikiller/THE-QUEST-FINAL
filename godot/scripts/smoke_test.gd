extends SceneTree
## Validación headless del loop de comisaría.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("TEST: loading main scene...")
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("Failed to change scene: %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	await create_timer(1.5).timeout

	print("TEST: missions=%d patrols=%d" % [GameState.active_missions.size(), GameState.patrols.size()])
	if GameState.active_missions.is_empty():
		push_error("No missions spawned")
		quit(2)
		return
	if GameState.available_patrols().is_empty():
		push_error("No available patrols")
		quit(3)
		return

	var mission_id: String = GameState.active_missions.keys()[0]
	var patrol_id: String = GameState.available_patrols()[0]["id"]
	var dispatch = root.get_tree().get_first_node_in_group("dispatch")
	if dispatch == null:
		push_error("Dispatch controller missing")
		quit(4)
		return
	var ok: bool = dispatch.dispatch(mission_id, patrol_id)
	print("TEST: dispatch=%s" % ok)
	if not ok:
		quit(5)
		return

	await create_timer(2.0).timeout
	var patrol: Dictionary = GameState.patrols[patrol_id]
	print("TEST: patrol status=%s pos=%s" % [patrol["status"], patrol["pos"]])
	print("TEST_OK")
	quit(0)
