extends Control
## HUD comisaría estilo mockup: pestañas Mapa / Misiones / Patrullas.

enum Tab { MAP, MISSIONS, PATROLS, DETAIL }

@onready var time_label: Label = %TimeLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var motto_label: Label = %MottoLabel
@onready var tab_map: Button = %TabMap
@onready var tab_missions: Button = %TabMissions
@onready var tab_patrols: Button = %TabPatrols
@onready var map_panel: Control = %MapPanel
@onready var missions_panel: Control = %MissionsPanel
@onready var patrols_panel: Control = %PatrolsPanel
@onready var detail_panel: Control = %DetailPanel
@onready var mission_list: ItemList = %MissionList
@onready var filter_list: ItemList = %FilterList
@onready var mission_title: Label = %MissionTitle
@onready var mission_meta: Label = %MissionMeta
@onready var mission_blurb: RichTextLabel = %MissionBlurb
@onready var mission_art: TextureRect = %MissionArt
@onready var urgency_badge: Label = %UrgencyBadge
@onready var objectives: RichTextLabel = %Objectives
@onready var outcomes: RichTextLabel = %Outcomes
@onready var patrol_list: ItemList = %PatrolList
@onready var dispatch_btn: Button = %DispatchButton
@onready var radio_log: RichTextLabel = %RadioLog
@onready var map_mission_list: ItemList = %MapMissionList
@onready var map_patrol_list: ItemList = %MapPatrolList
@onready var map_dispatch_btn: Button = %MapDispatchButton
@onready var map_art: TextureRect = %SelectedArt
@onready var map_title: Label = %SelectedTitle
@onready var map_blurb: RichTextLabel = %SelectedBlurb
@onready var patrol_cards: VBoxContainer = %PatrolCards
@onready var patrol_preview: TextureRect = %PatrolPreview
@onready var patrol_info: RichTextLabel = %PatrolInfo
@onready var back_btn: Button = %BackButton
@onready var confirm_actions: Button = %ConfirmActions
@onready var action_cautious: Button = %ActionCautious
@onready var action_entry: Button = %ActionEntry
@onready var action_negotiate: Button = %ActionNegotiate
@onready var action_block: Button = %ActionBlock

var _mission_ids: Array = []
var _map_mission_ids: Array = []
var _patrol_ids: Array = []
var _filter: String = "todas"
var _current_tab: int = Tab.MAP
var _selected_action: String = "cautious"


func _ready() -> void:
	motto_label.text = str(GameState.station.get("motto", "Servir · Proteger · Investigar"))
	GameState.time_changed.connect(_on_time)
	GameState.prestige_changed.connect(_on_prestige)
	GameState.mission_added.connect(func(_m): _refresh_all())
	GameState.mission_updated.connect(func(_m): _refresh_all())
	GameState.mission_removed.connect(func(_m): _refresh_all())
	GameState.patrol_updated.connect(func(_p): _refresh_patrols(); _build_patrol_cards())
	GameState.selection_changed.connect(func(_id): _on_selection())
	RadioBus.radio_message.connect(_on_radio)

	tab_map.pressed.connect(func(): _set_tab(Tab.MAP))
	tab_missions.pressed.connect(func(): _set_tab(Tab.MISSIONS))
	tab_patrols.pressed.connect(func(): _set_tab(Tab.PATROLS))
	back_btn.pressed.connect(func(): _set_tab(Tab.MISSIONS))
	mission_list.item_selected.connect(_on_mission_item)
	map_mission_list.item_selected.connect(_on_map_mission_item)
	filter_list.item_selected.connect(_on_filter)
	dispatch_btn.pressed.connect(_on_dispatch.bind(false))
	map_dispatch_btn.pressed.connect(_on_dispatch.bind(true))
	confirm_actions.pressed.connect(_on_confirm_actions)
	action_cautious.pressed.connect(func(): _select_action("cautious"))
	action_entry.pressed.connect(func(): _select_action("entry"))
	action_negotiate.pressed.connect(func(): _select_action("negotiate"))
	action_block.pressed.connect(func(): _select_action("block"))

	_setup_filters()
	_on_time("%02d:%02d" % [GameState.hour, GameState.minute])
	_on_prestige(GameState.prestige)
	_set_tab(Tab.MAP)
	_refresh_all()
	_build_patrol_cards()
	_select_action("cautious")
	RadioBus.push("Centralita en línea. Canal abierto. Cambio.", "info")


func _setup_filters() -> void:
	filter_list.clear()
	for item in [
		["todas", "TODAS"],
		["urgentes", "URGENTES"],
		["delitos", "DELITOS"],
		["trafico", "TRÁFICO"],
		["civiles", "ASISTENCIA"],
		["organizado", "INVESTIGACIÓN"],
		["especiales", "EVENTOS"],
	]:
		filter_list.add_item(item[1])
		filter_list.set_item_metadata(filter_list.item_count - 1, item[0])
	filter_list.select(0)


func _set_tab(tab: int) -> void:
	_current_tab = tab
	map_panel.visible = tab == Tab.MAP
	missions_panel.visible = tab == Tab.MISSIONS
	patrols_panel.visible = tab == Tab.PATROLS
	detail_panel.visible = tab == Tab.DETAIL
	_style_tab(tab_map, tab == Tab.MAP)
	_style_tab(tab_missions, tab == Tab.MISSIONS)
	_style_tab(tab_patrols, tab == Tab.PATROLS)
	# Dim world when not on map
	var world := get_tree().get_first_node_in_group("world_root")
	if world:
		world.modulate = Color(1, 1, 1, 1) if tab == Tab.MAP else Color(0.35, 0.4, 0.5, 1)


func _style_tab(btn: Button, on: bool) -> void:
	if on:
		btn.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))


func _on_time(label: String) -> void:
	time_label.text = label


func _on_prestige(value: int) -> void:
	prestige_label.text = "Prestigio %d" % value


func _refresh_all() -> void:
	_refresh_missions()
	_refresh_map_side()
	_refresh_patrols()
	_refresh_detail()


func _filtered_missions() -> Array:
	var out: Array = []
	for m in GameState.active_missions.values():
		var cat := str(m.get("category", ""))
		var sev := str(m.get("severity", ""))
		match _filter:
			"todas":
				out.append(m)
			"urgentes":
				if sev in ["high", "critical"]:
					out.append(m)
			_:
				if cat == _filter:
					out.append(m)
	out.sort_custom(func(a, b): return _sev_rank(a) > _sev_rank(b))
	return out


func _sev_rank(m: Dictionary) -> int:
	match str(m.get("severity", "")):
		"critical":
			return 4
		"high":
			return 3
		"medium":
			return 2
		_:
			return 1


func _refresh_missions() -> void:
	mission_list.clear()
	_mission_ids.clear()
	for m in _filtered_missions():
		_mission_ids.append(m["id"])
		var risk := "●".repeat(_sev_rank(m)) + "○".repeat(max(0, 5 - _sev_rank(m)))
		var line := "%s\n%s · %s  %s" % [m["title"], m["district_name"], str(m["category"]).to_upper(), risk]
		mission_list.add_item(line)
		var idx := mission_list.item_count - 1
		if str(m.get("severity", "")) in ["high", "critical"]:
			mission_list.set_item_custom_fg_color(idx, Color(1.0, 0.45, 0.45))
		elif m["status"] != "open":
			mission_list.set_item_custom_fg_color(idx, Color(0.55, 0.8, 1.0))
	_sync_mission_selection(mission_list, _mission_ids)


func _refresh_map_side() -> void:
	map_mission_list.clear()
	_map_mission_ids.clear()
	for m in GameState.active_missions.values():
		_map_mission_ids.append(m["id"])
		map_mission_list.add_item("%s · %s" % [m["title"], m["district_name"]])
	_sync_mission_selection(map_mission_list, _map_mission_ids)
	_refresh_selected_side()


func _sync_mission_selection(list: ItemList, ids: Array) -> void:
	var sel := GameState.selected_mission_id
	if sel == "":
		return
	var i := ids.find(sel)
	if i >= 0:
		list.select(i)


func _on_filter(index: int) -> void:
	_filter = str(filter_list.get_item_metadata(index))
	_refresh_missions()


func _on_mission_item(index: int) -> void:
	if index < 0 or index >= _mission_ids.size():
		return
	GameState.select_mission(_mission_ids[index])
	_set_tab(Tab.DETAIL)


func _on_map_mission_item(index: int) -> void:
	if index < 0 or index >= _map_mission_ids.size():
		return
	GameState.select_mission(_map_mission_ids[index])


func _on_selection() -> void:
	_refresh_detail()
	_refresh_selected_side()
	_sync_mission_selection(mission_list, _mission_ids)
	_sync_mission_selection(map_mission_list, _map_mission_ids)


func _refresh_selected_side() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty():
		map_title.text = "Selecciona una misión"
		map_blurb.text = "Pulsa un marcador en el mapa o una entrada de la lista."
		map_art.texture = null
		map_dispatch_btn.disabled = true
		return
	map_title.text = str(m["title"])
	map_blurb.text = str(m["blurb"])
	var path := GameState.texture_path_for_event_file(str(m.get("file", "")))
	if ResourceLoader.exists(path):
		map_art.texture = load(path)
	map_dispatch_btn.disabled = m["status"] != "open" or GameState.available_patrols().is_empty()


func _refresh_detail() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty():
		mission_title.text = "Sin misión"
		mission_meta.text = ""
		mission_blurb.text = ""
		objectives.text = ""
		outcomes.text = ""
		urgency_badge.visible = false
		mission_art.texture = null
		dispatch_btn.disabled = true
		confirm_actions.disabled = true
		return
	mission_title.text = str(m["title"]).to_upper()
	mission_meta.text = "%s · %s · avisado %s" % [
		str(m["district_name"]),
		str(m["category"]).to_upper(),
		str(m["created_at"]),
	]
	mission_blurb.text = str(m["blurb"])
	var urgent := str(m.get("severity", "")) in ["high", "critical"]
	urgency_badge.visible = urgent
	urgency_badge.text = "URGENTE" if urgent else ""
	var path := GameState.texture_path_for_event_file(str(m.get("file", "")))
	if ResourceLoader.exists(path):
		mission_art.texture = load(path)
	objectives.text = "• Asegurar la zona\n• Neutralizar la amenaza\n• Proteger a civiles\n• Preservar evidencia"
	outcomes.text = "[color=#6bcf8e]ÉXITO[/color]  detenidos\n[color=#e2b14a]PARCIAL[/color]  fuga parcial\n[color=#e35d5d]FALLO[/color]  víctima / fuga"
	dispatch_btn.disabled = m["status"] != "open" or GameState.available_patrols().is_empty()
	confirm_actions.disabled = dispatch_btn.disabled


func _refresh_patrols() -> void:
	var lists: Array = [patrol_list, map_patrol_list]
	_patrol_ids.clear()
	for p in GameState.patrols.values():
		_patrol_ids.append(p["id"])
	for list in lists:
		list.clear()
		for p in GameState.patrols.values():
			var st: String = _status_es(p["status"])
			var line: String = "%s — %s\n%s · %s" % [p["name"], p["callsign"], st, str(p["specialty"])]
			list.add_item(line)
			var idx: int = list.item_count - 1
			if p["status"] != "available":
				list.set_item_custom_fg_color(idx, Color(0.65, 0.7, 0.8))
				list.set_item_disabled(idx, true)
			else:
				list.set_item_disabled(idx, false)
		for i in range(_patrol_ids.size()):
			if not list.is_item_disabled(i):
				list.select(i)
				break


func _build_patrol_cards() -> void:
	for c in patrol_cards.get_children():
		c.queue_free()
	for p in GameState.patrols.values():
		var btn := Button.new()
		btn.text = "%s\n%s · %s" % [p["name"], p["callsign"], _status_es(p["status"])]
		btn.custom_minimum_size = Vector2(0, 64)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pid: String = String(p["id"])
		btn.pressed.connect(_show_patrol.bind(pid))
		patrol_cards.add_child(btn)
	if not GameState.patrols.is_empty():
		_show_patrol(String(GameState.patrols.keys()[0]))


func _show_patrol(pid: String) -> void:
	if not GameState.patrols.has(pid):
		return
	var p: Dictionary = GameState.patrols[pid]
	if ResourceLoader.exists(str(p["portrait"])):
		patrol_preview.texture = load(str(p["portrait"]))
	var agents: Array = p.get("agents", [])
	var agent_txt: String = ", ".join(PackedStringArray(agents))
	patrol_info.text = "[b]%s[/b]\nIndicativo: %s\nEstado: %s\nEspecialidad: %s\nAgentes: %s\n\nEquipa el cinturón en base y despacha desde Misiones o Mapa." % [
		p["name"],
		p["callsign"],
		_status_es(p["status"]),
		str(p["specialty"]),
		agent_txt,
	]


func _status_es(st: String) -> String:
	match st:
		"available":
			return "EN BASE"
		"en_route":
			return "EN RUTA"
		"on_scene":
			return "EN SERVICIO"
		"returning":
			return "REGRESANDO"
		_:
			return st


func _select_action(action: String) -> void:
	_selected_action = action
	_paint_action(action_cautious, action == "cautious", Color(0.3, 0.55, 1.0))
	_paint_action(action_entry, action == "entry", Color(0.9, 0.3, 0.3))
	_paint_action(action_negotiate, action == "negotiate", Color(0.9, 0.75, 0.25))
	_paint_action(action_block, action == "block", Color(0.25, 0.4, 0.7))


func _paint_action(btn: Button, on: bool, accent: Color) -> void:
	btn.modulate = accent if on else Color(0.75, 0.8, 0.88)


func _selected_patrol_id(from_map: bool) -> String:
	var list: ItemList = map_patrol_list if from_map else patrol_list
	if not list.is_anything_selected():
		var avail := GameState.available_patrols()
		return "" if avail.is_empty() else str(avail[0]["id"])
	var idx: int = list.get_selected_items()[0]
	if idx < 0 or idx >= _patrol_ids.size():
		return ""
	return str(_patrol_ids[idx])


func _on_dispatch(from_map: bool = false) -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty():
		RadioBus.push("Selecciona una misión antes de transmitir.", "alert")
		return
	var patrol_id := _selected_patrol_id(from_map)
	if patrol_id == "":
		RadioBus.push("No hay patrullas disponibles.", "alert")
		return
	var dispatch = get_tree().get_first_node_in_group("dispatch")
	var ok: bool = dispatch.dispatch(m["id"], patrol_id)
	if ok:
		RadioBus.push("Táctica: %s" % _action_label(_selected_action), "dispatch")
		if not from_map:
			_set_tab(Tab.MAP)
	else:
		RadioBus.push("No se pudo despachar.", "alert")


func _on_confirm_actions() -> void:
	_on_dispatch(false)


func _action_label(action: String) -> String:
	match action:
		"cautious":
			return "acercamiento cauteloso"
		"entry":
			return "entrada inmediata"
		"negotiate":
			return "negociación"
		"block":
			return "bloqueo de fuga"
		_:
			return action


func _on_radio(text: String, kind: String) -> void:
	var color := "#c9d2e0"
	match kind:
		"dispatch":
			color = "#5ec8ff"
		"scene":
			color = "#7eb0d6"
		"resolve":
			color = "#6bcf8e"
		"alert":
			color = "#e35d5d"
	radio_log.append_text("[color=%s][%s] %s[/color]\n" % [color, time_label.text, text])
