extends Control
## Mercado de cartas: comprar con créditos para ampliar el mazo.

@onready var title: Label = %Title
@onready var sub: Label = %Sub
@onready var credits_label: Label = %CreditsLabel
@onready var cards_grid: GridContainer = %CardsGrid
@onready var detail_name: Label = %DetailName
@onready var detail_meta: Label = %DetailMeta
@onready var detail_effect: RichTextLabel = %DetailEffect
@onready var detail_desc: Label = %DetailDesc
@onready var btn_buy: Button = %BtnBuy
@onready var btn_close: Button = %BtnClose
@onready var filter_row: HBoxContainer = %FilterRow

var _filter: String = "todos"
var _selected_id: String = ""
var _patrol_id: String = "alpha"


func _ready() -> void:
	btn_close.pressed.connect(close)
	btn_buy.pressed.connect(_buy_selected)
	GameState.credits_changed.connect(func(v): credits_label.text = "CRÉDITOS  %d" % v)
	visibility_changed.connect(func():
		if visible:
			_rebuild()
	)


func open(patrol_id: String = "alpha") -> void:
	_patrol_id = patrol_id if patrol_id != "" else "alpha"
	visible = true
	_rebuild()


func close() -> void:
	visible = false
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()


func _rebuild() -> void:
	credits_label.text = "CRÉDITOS  %d" % GameState.credits
	title.text = "MERCADO DE CARTAS"
	var day_txt := "Día %d" % GameState.day_index
	if GameState.boss_defeated:
		day_txt += " · Boss derrotado — legendarias desbloqueadas"
	elif GameState.day_index >= GameState.BOSS_DAY:
		day_txt += " · Boss activo en el mapa"
	else:
		day_txt += " · El Capo aparece el día 2"
	sub.text = day_txt
	_rebuild_filters()
	_rebuild_cards()
	_refresh_detail()


func _rebuild_filters() -> void:
	for c in filter_row.get_children():
		c.queue_free()
	var filters := [
		["todos", "TODAS"],
		["ataque", "ATAQUE"],
		["defensa", "DEFENSA"],
		["control", "CONTROL"],
		["cura", "CURA"],
		["utilidad", "UTILIDAD"],
		["basica", "BÁSICA"],
		["magica", "MÁGICA"],
		["fuerza", "FUERZA"],
		["legendaria", "LEGENDARIA"],
	]
	for pair in filters:
		var t: String = str(pair[0])
		var b := Button.new()
		b.text = str(pair[1])
		b.toggle_mode = true
		b.button_pressed = _filter == t
		var key: String = t
		b.pressed.connect(func():
			_filter = key
			_rebuild_cards()
		)
		filter_row.add_child(b)


func _rebuild_cards() -> void:
	for c in cards_grid.get_children():
		c.queue_free()
	var stock: Array = CardDB.cards_for_market(GameState.boss_defeated)
	for c in stock:
		var cid := str(c.get("id", ""))
		var rar := CardDB.normalize_rarity(str(c.get("rarity", "basica")))
		var typ := str(c.get("type", ""))
		if _filter in ["basica", "magica", "fuerza", "legendaria"]:
			if rar != _filter:
				continue
		elif _filter == "legendary": # alias antiguo
			if rar != "legendaria":
				continue
		elif _filter != "todos" and typ != _filter:
			continue
		cards_grid.add_child(_make_card_tile(c))


func _make_card_tile(def: Dictionary) -> Control:
	var cid := str(def.get("id", ""))
	var rar := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	var price := CardDB.price_of(cid)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 210)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.98)
	sb.border_color = CardDB.rarity_color(rar)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var art_wrap := Control.new()
	art_wrap.custom_minimum_size = Vector2(0, 88)
	v.add_child(art_wrap)
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1, 1, 1, 0.35)
	var fp := CardDB.frame_path(rar)
	if ResourceLoader.exists(fp):
		frame.texture = load(fp)
	art_wrap.add_child(frame)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := str(def.get("art", def.get("icon", "")))
	if ResourceLoader.exists(path):
		art.texture = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			art.texture = ImageTexture.create_from_image(img)
	art_wrap.add_child(art)

	var name_l := Label.new()
	name_l.text = str(def.get("name", cid))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 12)
	v.add_child(name_l)

	var meta := Label.new()
	meta.text = "%s · %d★" % [CardDB.rarity_label(rar), price]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", CardDB.rarity_color(rar))
	v.add_child(meta)

	var btn := Button.new()
	btn.text = "VER"
	btn.pressed.connect(func():
		_selected_id = cid
		_refresh_detail()
	)
	v.add_child(btn)
	return panel


func _refresh_detail() -> void:
	if _selected_id == "":
		detail_name.text = "Elige una carta"
		detail_meta.text = ""
		detail_effect.text = "Las cartas compradas se añaden al mazo de García."
		detail_desc.text = ""
		btn_buy.disabled = true
		btn_buy.text = "COMPRAR"
		return
	var def := CardDB.get_card(_selected_id)
	var price := CardDB.price_of(_selected_id)
	detail_name.text = str(def.get("name", _selected_id))
	detail_meta.text = "%s · coste %d · %d★" % [
		CardDB.rarity_label(str(def.get("rarity", "basica"))),
		int(def.get("cost", 0)),
		price,
	]
	detail_meta.add_theme_color_override("font_color", CardDB.rarity_color(str(def.get("rarity", "basica"))))
	detail_effect.text = CardDB.effect_line(def)
	detail_desc.text = CardDB.flavor_line(def)
	btn_buy.disabled = GameState.credits < price
	btn_buy.text = "COMPRAR  %d★" % price


func _buy_selected() -> void:
	if _selected_id == "":
		return
	if GameState.buy_card_for_patrol(_patrol_id, _selected_id):
		_rebuild()
	else:
		RadioBus.push("Créditos insuficientes.", "alert")
