extends Control
## Lista de misiones a pantalla completa.

@onready var filter_list: ItemList = %FilterList
@onready var mission_list: ItemList = %MissionList
@onready var detail_title: Label = %DetailTitle
@onready var detail_meta: Label = %DetailMeta
@onready var detail_blurb: RichTextLabel = %DetailBlurb
@onready var detail_art: TextureRect = %DetailArt
@onready var urgency: Label = %Urgency
@onready var btn_open: Button = %BtnOpen
@onready var btn_back: Button = %BtnBack
@onready var count_label: Label = %CountLabel

var _ids: Array = []
var _filter: String = "todas"


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	filter_list.item_selected.connect(_on_filter)
	mission_list.item_selected.connect(_on_pick)
	mission_list.item_activated.connect(_on_activate)
	btn_open.pressed.connect(_open_selected)
	btn_back.pressed.connect(_back)
	_setup_filters()


func _on_vis() -> void:
	if visible:
		_refresh()


func _setup_filters() -> void:
	filter_list.clear()
	for item in [
		["todas", "TODAS"],
		["urgentes", "URGENTES"],
		["delitos", "DELITOS"],
		["trafico", "TRÁFICO"],
		["civiles", "ASISTENCIA"],
		["organizado", "ORGANIZADO"],
		["especiales", "ESPECIALES"],
	]:
		filter_list.add_item(item[1])
		filter_list.set_item_metadata(filter_list.item_count - 1, item[0])
	filter_list.select(0)


func _on_filter(index: int) -> void:
	_filter = str(filter_list.get_item_metadata(index))
	_refresh()


func _filtered() -> Array:
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
	return out


func _refresh() -> void:
	mission_list.clear()
	_ids.clear()
	var items := _filtered()
	count_label.text = "%d misiones" % items.size()
	for m in items:
		_ids.append(m["id"])
		var tag := "URGENTE" if str(m.get("severity", "")) in ["high", "critical"] else str(m.get("category", "")).to_upper()
		mission_list.add_item("%s\n%s · %s" % [m["title"], m["district_name"], tag])
		var idx: int = mission_list.item_count - 1
		if str(m.get("severity", "")) in ["high", "critical"]:
			mission_list.set_item_custom_fg_color(idx, Color(1.0, 0.45, 0.45))
	if _ids.size() > 0:
		mission_list.select(0)
		_show_detail(_ids[0])
	else:
		_clear_detail()


func _on_pick(index: int) -> void:
	if index >= 0 and index < _ids.size():
		_show_detail(_ids[index])


func _on_activate(index: int) -> void:
	_on_pick(index)
	_open_selected()


func _show_detail(mid: String) -> void:
	GameState.select_mission(mid)
	var m := GameState.get_selected_mission()
	if m.is_empty():
		_clear_detail()
		return
	detail_title.text = str(m["title"]).to_upper()
	detail_meta.text = "%s · %s · %s" % [m["district_name"], str(m["category"]).to_upper(), m["created_at"]]
	detail_blurb.text = str(m["blurb"])
	urgency.visible = str(m.get("severity", "")) in ["high", "critical"]
	var path := GameState.texture_path_for_event_file(str(m.get("file", "")))
	detail_art.texture = load(path) if ResourceLoader.exists(path) else null
	btn_open.disabled = false


func _clear_detail() -> void:
	detail_title.text = "Sin misiones"
	detail_meta.text = ""
	detail_blurb.text = "Cuando haya avisos, aparecerán aquí."
	detail_art.texture = null
	urgency.visible = false
	btn_open.disabled = true


func _open_selected() -> void:
	if GameState.selected_mission_id == "":
		return
	var router := get_parent()
	if router and router.has_method("show_mission"):
		router.show_mission(GameState.selected_mission_id)


func _back() -> void:
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()
