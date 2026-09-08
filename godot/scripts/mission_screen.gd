extends Control
## Pantalla de misión a pantalla completa (estilo informe táctico).

@onready var title: Label = %MissionTitle
@onready var meta: Label = %MissionMeta
@onready var urgency: Label = %UrgencyBadge
@onready var timer_label: Label = %TimerLabel
@onready var art: TextureRect = %MissionArt
@onready var blurb: RichTextLabel = %MissionBlurb
@onready var objectives: RichTextLabel = %Objectives
@onready var location_label: Label = %LocationLabel
@onready var risk_label: Label = %RiskLabel
@onready var patrol_list: ItemList = %PatrolList
@onready var back_btn: Button = %BackButton
@onready var confirm_btn: Button = %ConfirmActions
@onready var action_cautious: Button = %ActionCautious
@onready var action_entry: Button = %ActionEntry
@onready var action_negotiate: Button = %ActionNegotiate
@onready var action_block: Button = %ActionBlock
@onready var support_check: CheckBox = %SupportCheck
@onready var step_label: Label = %StepLabel

var _patrol_ids: Array = []
var _action: String = "cautious"
var _elapsed: float = 0.0


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	back_btn.pressed.connect(_back)
	confirm_btn.pressed.connect(_confirm)
	action_cautious.pressed.connect(func(): _set_action("cautious"))
	action_entry.pressed.connect(func(): _set_action("entry"))
	action_negotiate.pressed.connect(func(): _set_action("negotiate"))
	action_block.pressed.connect(func(): _set_action("block"))
	_set_action("cautious")


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	var m := int(_elapsed)
	timer_label.text = "%02d:%02d" % [m / 60, m % 60]


func _on_vis() -> void:
	if visible:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty():
		return
	title.text = str(m["title"]).to_upper()
	meta.text = "%s · %s" % [str(m["category"]).to_upper(), m["district_name"]]
	location_label.text = "%s" % m["district_name"]
	blurb.text = "[b]DESCRIPCIÓN DE LA SITUACIÓN[/b]\n\n%s" % m["blurb"]
	urgency.visible = str(m.get("severity", "")) in ["high", "critical"]
	var rank := _risk(m)
	risk_label.text = "RIESGO  " + "●".repeat(rank) + "○".repeat(maxi(0, 5 - rank))
	objectives.text = "• Asegurar la zona\n• Neutralizar la amenaza\n• Proteger a civiles\n• Preservar evidencia"
	step_label.text = "INFORME INICIAL → EVIDENCIA → ESCENARIOS → DECISIÓN"
	var path := GameState.mission_art_path(m)
	art.texture = load(path) if ResourceLoader.exists(path) else null
	_refresh_patrols()
	confirm_btn.disabled = m.get("status", "") != "open" or GameState.available_patrols().is_empty()
	# Night UI accent when operating at night
	var night := GameState.time_of_day() == "night"
	modulate = Color(0.92, 0.95, 1.0) if night else Color.WHITE


func _risk(m: Dictionary) -> int:
	match str(m.get("severity", "")):
		"critical":
			return 5
		"high":
			return 4
		"medium":
			return 3
		_:
			return 2


func _refresh_patrols() -> void:
	patrol_list.clear()
	_patrol_ids.clear()
	for p in GameState.patrols.values():
		_patrol_ids.append(p["id"])
		var line: String = "%s — %s (%s)" % [p["name"], p["callsign"], _status(p["status"])]
		patrol_list.add_item(line)
		var idx: int = patrol_list.item_count - 1
		if p["status"] != "available":
			patrol_list.set_item_disabled(idx, true)
			patrol_list.set_item_custom_fg_color(idx, Color(0.6, 0.65, 0.75))
	for i in range(_patrol_ids.size()):
		if not patrol_list.is_item_disabled(i):
			patrol_list.select(i)
			break


func _status(st: String) -> String:
	match st:
		"available":
			return "EN BASE"
		"en_route":
			return "EN RUTA"
		"on_scene":
			return "EN SERVICIO"
		"returning":
			return "REGRESO"
		_:
			return st


func _set_action(action: String) -> void:
	_action = action
	_paint(action_cautious, action == "cautious", Color(0.35, 0.6, 1.0))
	_paint(action_entry, action == "entry", Color(1.0, 0.35, 0.35))
	_paint(action_negotiate, action == "negotiate", Color(1.0, 0.82, 0.3))
	_paint(action_block, action == "block", Color(0.35, 0.5, 0.85))


func _paint(btn: Button, on: bool, col: Color) -> void:
	btn.modulate = col if on else Color(0.7, 0.75, 0.82)


func _confirm() -> void:
	var m := GameState.get_selected_mission()
	if m.is_empty() or m.get("status", "") != "open":
		return
	if not patrol_list.is_anything_selected():
		RadioBus.push("Elige una patrulla disponible.", "alert")
		return
	var idx: int = patrol_list.get_selected_items()[0]
	var pid: String = String(_patrol_ids[idx])
	var dispatch = get_tree().get_first_node_in_group("dispatch")
	var ok: bool = dispatch.dispatch(m["id"], pid)
	if ok:
		var extra := " + apoyo extra" if support_check.button_pressed else ""
		RadioBus.push("Táctica: %s%s" % [_action_name(_action), extra], "dispatch")
		_back_to_map()
	else:
		RadioBus.push("No se pudo confirmar el despacho.", "alert")


func _action_name(a: String) -> String:
	match a:
		"cautious":
			return "acercamiento cauteloso"
		"entry":
			return "entrada inmediata"
		"negotiate":
			return "negociación"
		"block":
			return "bloqueo de fuga"
		_:
			return a


func _back() -> void:
	var router := get_parent()
	if router and router.has_method("show_missions"):
		router.show_missions()


func _back_to_map() -> void:
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()
