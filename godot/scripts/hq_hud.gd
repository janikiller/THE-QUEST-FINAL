extends Control
## HUD de comisaría: reloj, prestigio, lista de misiones, patrullas y radio.

@onready var time_label: Label = %TimeLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var station_label: Label = %StationLabel
@onready var mission_list: ItemList = %MissionList
@onready var mission_title: Label = %MissionTitle
@onready var mission_meta: Label = %MissionMeta
@onready var mission_blurb: RichTextLabel = %MissionBlurb
@onready var mission_art: TextureRect = %MissionArt
@onready var patrol_list: ItemList = %PatrolList
@onready var dispatch_btn: Button = %DispatchButton
@onready var radio_log: RichTextLabel = %RadioLog
@onready var empty_hint: Label = %EmptyHint

var _mission_ids: Array = []
var _patrol_ids: Array = []


func _ready() -> void:
	station_label.text = str(GameState.station.get("station_name", "Comisaría"))
	GameState.time_changed.connect(_on_time)
	GameState.prestige_changed.connect(_on_prestige)
	GameState.mission_added.connect(func(_m): _refresh_missions())
	GameState.mission_updated.connect(func(_m): _refresh_missions(); _refresh_detail())
	GameState.mission_removed.connect(func(_m): _refresh_missions(); _refresh_detail())
	GameState.patrol_updated.connect(func(_p): _refresh_patrols())
	GameState.selection_changed.connect(func(_id): _sync_list_selection(); _refresh_detail())
	RadioBus.radio_message.connect(_on_radio)
	mission_list.item_selected.connect(_on_mission_item)
	dispatch_btn.pressed.connect(_on_dispatch)
	_on_time("%02d:%02d" % [GameState.hour, GameState.minute])
	_on_prestige(GameState.prestige)
	_refresh_missions()
	_refresh_patrols()
	_refresh_detail()
	RadioBus.push("Centralita en línea. Canal abierto. Cambio.", "info")


func _on_time(label: String) -> void:
	time_label.text = label


func _on_prestige(value: int) -> void:
	prestige_label.text = "Prestigio %d" % value


func _refresh_missions() -> void:
	mission_list.clear()
	_mission_ids.clear()
	var items: Array = GameState.active_missions.values()
	items.sort_custom(func(a, b): return str(a["created_at"]) > str(b["created_at"]))
	for m in items:
		_mission_ids.append(m["id"])
		var sev := str(m.get("severity", "")).to_upper()
		var st := str(m.get("status", ""))
		mission_list.add_item("%s  ·  %s  [%s]" % [m["title"], m["district_name"], sev])
		var idx := mission_list.item_count - 1
		match st:
			"open":
				mission_list.set_item_custom_fg_color(idx, Color(1, 0.9, 0.6))
			"dispatched", "resolving":
				mission_list.set_item_custom_fg_color(idx, Color(0.55, 0.8, 1))
			"resolved":
				mission_list.set_item_custom_fg_color(idx, Color(0.5, 0.9, 0.6))
			_:
				mission_list.set_item_custom_fg_color(idx, Color(1, 0.5, 0.5))
	_sync_list_selection()


func _sync_list_selection() -> void:
	var sel := GameState.selected_mission_id
	if sel == "":
		return
	var i := _mission_ids.find(sel)
	if i >= 0:
		mission_list.select(i)


func _on_mission_item(index: int) -> void:
	if index < 0 or index >= _mission_ids.size():
		return
	GameState.select_mission(_mission_ids[index])


func _refresh_detail() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty():
		empty_hint.visible = true
		mission_title.text = "Sin misión seleccionada"
		mission_meta.text = "Pulsa un marcador en el mapa o elige en la lista."
		mission_blurb.text = ""
		mission_art.texture = null
		dispatch_btn.disabled = true
		return
	empty_hint.visible = false
	mission_title.text = str(m["title"])
	mission_meta.text = "%s · %s · %s · avisado %s" % [
		str(m["district_name"]),
		str(m["category"]).capitalize(),
		str(m["severity"]).to_upper(),
		str(m["created_at"]),
	]
	mission_blurb.text = str(m["blurb"])
	var path := GameState.texture_path_for_event_file(str(m.get("file", "")))
	if ResourceLoader.exists(path):
		mission_art.texture = load(path)
	dispatch_btn.disabled = m["status"] != "open" or GameState.available_patrols().is_empty()
	_refresh_patrols()


func _refresh_patrols() -> void:
	var previously := ""
	if patrol_list.is_anything_selected():
		var sel := patrol_list.get_selected_items()
		if sel.size() > 0 and sel[0] < _patrol_ids.size():
			previously = _patrol_ids[sel[0]]
	patrol_list.clear()
	_patrol_ids.clear()
	for p in GameState.patrols.values():
		_patrol_ids.append(p["id"])
		var line := "%s — %s" % [p["callsign"], _status_es(p["status"])]
		if p["specialty"] != "general":
			line += " · %s" % str(p["specialty"])
		patrol_list.add_item(line)
		var idx := patrol_list.item_count - 1
		if p["status"] != "available":
			patrol_list.set_item_custom_fg_color(idx, Color(0.65, 0.7, 0.8))
			patrol_list.set_item_disabled(idx, true)
		else:
			patrol_list.set_item_disabled(idx, false)
	if previously != "":
		var i := _patrol_ids.find(previously)
		if i >= 0 and not patrol_list.is_item_disabled(i):
			patrol_list.select(i)
	elif not GameState.available_patrols().is_empty():
		for i in _patrol_ids.size():
			if not patrol_list.is_item_disabled(i):
				patrol_list.select(i)
				break
	var m := GameState.get_selected_mission()
	dispatch_btn.disabled = m.is_empty() or m.get("status", "") != "open" or GameState.available_patrols().is_empty()


func _status_es(st: String) -> String:
	match st:
		"available":
			return "disponible"
		"en_route":
			return "en ruta"
		"on_scene":
			return "en el lugar"
		"returning":
			return "regresando"
		_:
			return st


func _on_dispatch() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty():
		return
	if not patrol_list.is_anything_selected():
		RadioBus.push("Elige una patrulla disponible antes de transmitir.", "alert")
		return
	var idx: int = patrol_list.get_selected_items()[0]
	var patrol_id: String = _patrol_ids[idx]
	var ok: bool = get_tree().get_first_node_in_group("dispatch").dispatch(m["id"], patrol_id)
	if not ok:
		RadioBus.push("No se pudo despachar. Revisa estado de misión/patrulla.", "alert")


func _on_radio(text: String, kind: String) -> void:
	var color := "#c9d2e0"
	match kind:
		"dispatch":
			color = "#e2b14a"
		"scene":
			color = "#7eb0d6"
		"resolve":
			color = "#6bcf8e"
		"alert":
			color = "#e35d5d"
		_:
			color = "#c9d2e0"
	radio_log.append_text("[color=%s][%s] %s[/color]\n" % [color, time_label.text, text])
