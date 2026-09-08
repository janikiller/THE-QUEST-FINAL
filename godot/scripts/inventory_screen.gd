extends Control
## Pantalla de inventario de patrulla: arrastrar objetos + tooltips.

signal closed

const SlotScene := preload("res://scenes/ui/inventory_slot.tscn")

@onready var patrol_list: VBoxContainer = %PatrolList
@onready var header_title: Label = %HeaderTitle
@onready var header_sub: Label = %HeaderSub
@onready var status_pill: Label = %StatusPill
@onready var agents_row: HBoxContainer = %AgentsRow
@onready var trunk_grid: GridContainer = %TrunkGrid
@onready var trunk_cap: Label = %TrunkCap
@onready var shared_grid: GridContainer = %SharedGrid
@onready var shared_cap: Label = %SharedCap
@onready var filter_row: HBoxContainer = %FilterRow
@onready var btn_close: Button = %BtnClose
@onready var btn_clear: Button = %BtnClear
@onready var btn_save: Button = %BtnSave
@onready var vehicle_tex: TextureRect = %VehicleTex
@onready var vehicle_name: Label = %VehicleName
@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_body: Label = %TooltipBody

var selected_patrol_id: String = ""
var filter_cat: String = "todos"
var _shared_slots: Array = [] ## InventorySlot
var _trunk_slots: Array = []
var _agent_slots: Array = [] ## Array of Dictionaries of slots
var _hover_slot: Control = null


func _ready() -> void:
	visible = false
	btn_close.pressed.connect(close)
	btn_clear.pressed.connect(_clear_shared)
	btn_save.pressed.connect(_flash_saved)
	_build_filters()
	tooltip_panel.visible = false


func open(patrol_id: String = "") -> void:
	visible = true
	if patrol_id == "" and not GameState.patrols.is_empty():
		patrol_id = str(GameState.patrols.keys()[0])
	_rebuild_patrol_list()
	select_patrol(patrol_id)
	get_tree().paused = false


func close() -> void:
	visible = false
	tooltip_panel.visible = false
	closed.emit()
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()


func _build_filters() -> void:
	for c in filter_row.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for cat in ItemDB.categories:
		var id := str(cat.get("id", "todos"))
		var b := Button.new()
		b.text = str(cat.get("label", id.to_upper()))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == filter_cat
		b.pressed.connect(_on_filter.bind(id))
		filter_row.add_child(b)


func _on_filter(cat: String) -> void:
	filter_cat = cat
	for b in filter_row.get_children():
		if b is Button:
			b.button_pressed = (b.text == _label_for(cat))
	_refresh_shared_visibility()


func _label_for(cat: String) -> String:
	for c in ItemDB.categories:
		if str(c.get("id", "")) == cat:
			return str(c.get("label", cat))
	return cat.to_upper()


func _rebuild_patrol_list() -> void:
	for c in patrol_list.get_children():
		c.queue_free()
	for p in GameState.patrols.values():
		var pid := str(p.get("id", ""))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 100)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var st := str(p.get("status", "available"))
		var st_label := "EN BASE"
		var st_color := Color(0.55, 0.62, 0.72)
		match st:
			"available":
				st_label = "EN BASE"
				st_color = Color(0.45, 0.85, 0.55)
			"en_route", "on_scene":
				st_label = "EN SERVICIO"
				st_color = Color(0.35, 0.85, 1.0)
			"returning":
				st_label = "REGRESO"
				st_color = Color(1.0, 0.82, 0.35)
		btn.text = "%s\n%s\n● %s" % [p.get("name", ""), p.get("callsign", ""), st_label]
		btn.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		var sb := StyleBoxFlat.new()
		var selected := pid == selected_patrol_id
		sb.bg_color = Color(0.06, 0.12, 0.2) if selected else Color(0.05, 0.08, 0.14)
		sb.border_color = Color(0.2, 0.85, 1.0) if selected else Color(0.2, 0.32, 0.45)
		sb.set_border_width_all(2 if selected else 1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		if selected:
			sb.shadow_color = Color(0.15, 0.7, 1.0, 0.35)
			sb.shadow_size = 6
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(select_patrol.bind(pid))
		patrol_list.add_child(btn)
		# tint status line via modulate of whole button slightly
		if not selected:
			btn.modulate = Color(0.92, 0.94, 0.98)
		else:
			btn.modulate = Color(1, 1, 1)
		btn.set_meta("status_color", st_color)


func select_patrol(patrol_id: String) -> void:
	if not GameState.patrols.has(patrol_id):
		return
	selected_patrol_id = patrol_id
	_rebuild_patrol_list()
	GameState.ensure_patrol_inventory(patrol_id)
	var p: Dictionary = GameState.patrols[patrol_id]
	header_title.text = "%s | %s" % [p.get("name", ""), p.get("callsign", "")]
	header_sub.text = "Unidad de patrulla · inventario compartido"
	var st := str(p.get("status", "available"))
	match st:
		"available":
			status_pill.text = "EN BASE"
		"en_route", "on_scene":
			status_pill.text = "EN SERVICIO"
		"returning":
			status_pill.text = "REGRESO"
		_:
			status_pill.text = st.to_upper()
	vehicle_name.text = str(p.get("callsign", "Vehículo"))
	if ResourceLoader.exists(str(p.get("portrait", ""))):
		vehicle_tex.texture = load(str(p.get("portrait", "")))
	_build_agent_panels()
	_build_trunk()
	_build_shared()
	_highlight_patrol_buttons()


func _highlight_patrol_buttons() -> void:
	var i := 0
	for btn in patrol_list.get_children():
		if btn is Button:
			var pid := str(GameState.patrols.values()[i].get("id", "")) if i < GameState.patrols.size() else ""
			btn.modulate = Color(0.55, 0.85, 1.0) if pid == selected_patrol_id else Color.WHITE
			i += 1


func _build_agent_panels() -> void:
	for c in agents_row.get_children():
		c.queue_free()
	_agent_slots.clear()
	var inv: Dictionary = GameState.patrol_inventories[selected_patrol_id]
	var agents_data: Array = inv.get("agents", [])
	var p: Dictionary = GameState.patrols[selected_patrol_id]
	var names: Array = p.get("agents", [])
	for ai in range(agents_data.size()):
		var panel := _make_agent_panel(ai, str(names[ai] if ai < names.size() else "Agente"), agents_data[ai])
		agents_row.add_child(panel)


func _make_agent_panel(agent_index: int, agent_name: String, data: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	box.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	var title := Label.new()
	title.text = "AGENTE %s" % agent_name.to_upper()
	title.add_theme_font_size_override("font_size", 16)
	v.add_child(title)

	var portraits: Array = GameState.patrols.get(selected_patrol_id, {}).get("agent_portraits", [])
	if agent_index < portraits.size() and ResourceLoader.exists(str(portraits[agent_index])):
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(0, 96)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.texture = load(str(portraits[agent_index]))
		v.add_child(face)

	var slots_map := {}
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)

	var casco := _spawn_slot("agents/%d/casco" % agent_index, 0, PackedStringArray(["casco"]), "CASCO")
	casco.set_item(str(data.get("casco", "")))
	slots_map["casco"] = casco
	top.add_child(casco)

	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 10)
	v.add_child(mid)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 6)
	var chaleco := _spawn_slot("agents/%d/chaleco" % agent_index, 0, PackedStringArray(["chaleco"]), "CHALECO")
	chaleco.set_item(str(data.get("chaleco", "")))
	slots_map["chaleco"] = chaleco
	left_col.add_child(chaleco)
	var principal := _spawn_slot("agents/%d/principal" % agent_index, 0, PackedStringArray(["principal"]), "PRINCIPAL")
	principal.set_item(str(data.get("principal", "")))
	slots_map["principal"] = principal
	left_col.add_child(principal)
	mid.add_child(left_col)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var patrol: Dictionary = GameState.patrols[selected_patrol_id]
	if ResourceLoader.exists(str(patrol.get("portrait", ""))):
		portrait.texture = load(str(patrol.get("portrait", "")))
	mid.add_child(portrait)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	var secundaria := _spawn_slot("agents/%d/secundaria" % agent_index, 0, PackedStringArray(["secundaria", "principal"]), "SECUNDARIA")
	secundaria.set_item(str(data.get("secundaria", "")))
	slots_map["secundaria"] = secundaria
	right_col.add_child(secundaria)
	mid.add_child(right_col)

	var belt_l := Label.new()
	belt_l.text = "CINTURÓN"
	belt_l.add_theme_font_size_override("font_size", 12)
	v.add_child(belt_l)
	var belt_row := HBoxContainer.new()
	belt_row.add_theme_constant_override("separation", 4)
	v.add_child(belt_row)
	var belt_slots: Array = []
	var belt_items: Array = data.get("cinturon", [])
	for i in range(5):
		var s := _spawn_slot("agents/%d/cinturon" % agent_index, i, PackedStringArray(["cinturon", "secundaria", "herramientas", "medico", "varios"]), "")
		var iid := str(belt_items[i]) if i < belt_items.size() else ""
		s.set_item(iid)
		belt_row.add_child(s)
		belt_slots.append(s)
	slots_map["cinturon"] = belt_slots

	var pocket_l := Label.new()
	pocket_l.text = "BOLSILLOS"
	pocket_l.add_theme_font_size_override("font_size", 12)
	v.add_child(pocket_l)
	var pocket_row := HBoxContainer.new()
	pocket_row.add_theme_constant_override("separation", 4)
	v.add_child(pocket_row)
	var pocket_slots: Array = []
	var pocket_items: Array = data.get("bolsillos", [])
	for i in range(5):
		var s := _spawn_slot("agents/%d/bolsillos" % agent_index, i, PackedStringArray(["bolsillos", "varios", "equipamiento", "herramientas", "medico"]), "")
		var iid := str(pocket_items[i]) if i < pocket_items.size() else ""
		s.set_item(iid)
		pocket_row.add_child(s)
		pocket_slots.append(s)
	slots_map["bolsillos"] = pocket_slots

	_agent_slots.append(slots_map)
	return box


func _build_trunk() -> void:
	for c in trunk_grid.get_children():
		c.queue_free()
	_trunk_slots.clear()
	var inv: Dictionary = GameState.patrol_inventories[selected_patrol_id]
	var items: Array = inv.get("trunk", [])
	for i in range(GameState.TRUNK_SIZE):
		var s := _spawn_slot("trunk", i, PackedStringArray())
		var iid := str(items[i]) if i < items.size() else ""
		s.set_item(iid)
		trunk_grid.add_child(s)
		_trunk_slots.append(s)
	_update_caps()


func _build_shared() -> void:
	for c in shared_grid.get_children():
		c.queue_free()
	_shared_slots.clear()
	var inv: Dictionary = GameState.patrol_inventories[selected_patrol_id]
	var items: Array = inv.get("shared", [])
	for i in range(GameState.SHARED_SIZE):
		var s := _spawn_slot("shared", i, PackedStringArray())
		var iid := str(items[i]) if i < items.size() else ""
		s.set_item(iid)
		shared_grid.add_child(s)
		_shared_slots.append(s)
	_refresh_shared_visibility()
	_update_caps()


func _spawn_slot(path: String, idx: int, accepts: PackedStringArray, hint: String = "") -> PanelContainer:
	var s: PanelContainer = SlotScene.instantiate()
	s.setup(path, idx, accepts, hint)
	s.mouse_entered.connect(_on_slot_hover.bind(s))
	s.mouse_exited.connect(_on_slot_unhover.bind(s))
	return s


func _refresh_shared_visibility() -> void:
	for s in _shared_slots:
		if filter_cat == "todos" or s.item_id == "":
			s.visible = true
			continue
		var def: Dictionary = ItemDB.get_item(s.item_id)
		s.visible = str(def.get("category", "")) == filter_cat


func _update_caps() -> void:
	var inv: Dictionary = GameState.patrol_inventories.get(selected_patrol_id, {})
	var shared_n := 0
	for id in inv.get("shared", []):
		if str(id) != "":
			shared_n += 1
	var trunk_n := 0
	for id in inv.get("trunk", []):
		if str(id) != "":
			trunk_n += 1
	shared_cap.text = "%d / %d" % [shared_n, GameState.SHARED_SIZE]
	trunk_cap.text = "%d / %d" % [trunk_n, GameState.TRUNK_SIZE]


func transfer_item(from_path: String, from_index: int, to_path: String, to_index: int) -> void:
	if selected_patrol_id == "":
		return
	GameState.swap_inventory_slots(selected_patrol_id, from_path, from_index, to_path, to_index)
	# Refresh affected visual slots from state
	_sync_slot_visual(from_path, from_index)
	_sync_slot_visual(to_path, to_index)
	_update_caps()
	_refresh_shared_visibility()


func _sync_slot_visual(path: String, index: int) -> void:
	var id := GameState.get_slot_item(selected_patrol_id, path, index)
	var slot := _find_slot(path, index)
	if slot:
		slot.set_item(id)


func _find_slot(path: String, index: int) -> PanelContainer:
	if path == "shared":
		if index >= 0 and index < _shared_slots.size():
			return _shared_slots[index]
	elif path == "trunk":
		if index >= 0 and index < _trunk_slots.size():
			return _trunk_slots[index]
	elif path.begins_with("agents/"):
		var parts := path.split("/")
		if parts.size() < 3:
			return null
		var ai := int(parts[1])
		var kind := parts[2]
		if ai < 0 or ai >= _agent_slots.size():
			return null
		var map: Dictionary = _agent_slots[ai]
		if kind in ["cinturon", "bolsillos"]:
			var arr: Array = map.get(kind, [])
			if index >= 0 and index < arr.size():
				return arr[index]
		else:
			return map.get(kind)
	return null


func _on_slot_hover(slot: Control) -> void:
	_hover_slot = slot
	if not ("item_id" in slot) or slot.item_id == "":
		tooltip_panel.visible = false
		return
	var def: Dictionary = ItemDB.get_item(slot.item_id)
	tooltip_title.text = str(def.get("name", slot.item_id))
	tooltip_body.text = str(def.get("description", "Objeto utilizable."))
	tooltip_panel.visible = true
	_place_tooltip()


func _on_slot_unhover(slot: Control) -> void:
	if _hover_slot == slot:
		_hover_slot = null
		tooltip_panel.visible = false


func _process(_dt: float) -> void:
	if tooltip_panel.visible:
		_place_tooltip()


func _place_tooltip() -> void:
	var mp := get_local_mouse_position()
	var sz := tooltip_panel.size
	if sz == Vector2.ZERO:
		sz = Vector2(280, 90)
	var pos := mp + Vector2(18, 18)
	if pos.x + sz.x > size.x - 8:
		pos.x = mp.x - sz.x - 12
	if pos.y + sz.y > size.y - 8:
		pos.y = mp.y - sz.y - 12
	tooltip_panel.position = pos


func _clear_shared() -> void:
	if selected_patrol_id == "":
		return
	GameState.clear_shared_inventory(selected_patrol_id)
	_build_shared()


func _flash_saved() -> void:
	btn_save.text = "✓ GUARDADO"
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(btn_save):
		btn_save.text = "GUARDAR CONFIGURACIÓN"
