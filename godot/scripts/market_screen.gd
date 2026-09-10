extends Control
## Mercado U.P.R.: tienda bonita + ruleta de cartas.

const SPIN_COST := 8
const REEL_CARD_W := 132.0
const REEL_GAP := 12.0

@onready var title: Label = %Title
@onready var sub: Label = %Sub
@onready var credits_label: Label = %CreditsLabel
@onready var credits_chip: PanelContainer = %CreditsChip
@onready var cards_grid: GridContainer = %CardsGrid
@onready var detail_art: TextureRect = %DetailArt
@onready var detail_name: Label = %DetailName
@onready var detail_meta: Label = %DetailMeta
@onready var detail_effect: RichTextLabel = %DetailEffect
@onready var detail_desc: Label = %DetailDesc
@onready var btn_buy: Button = %BtnBuy
@onready var btn_close: Button = %BtnClose
@onready var filter_row: HBoxContainer = %FilterRow
@onready var shop_pane: VBoxContainer = %ShopPane
@onready var roulette_pane: VBoxContainer = %RoulettePane
@onready var btn_mode_shop: Button = %BtnModeShop
@onready var btn_mode_roulette: Button = %BtnModeRoulette
@onready var roulette_panel: PanelContainer = %RoulettePanel
@onready var roulette_title: Label = %RouletteTitle
@onready var roulette_hint: Label = %RouletteHint
@onready var odds_row: HBoxContainer = %OddsRow
@onready var reel_clip: Control = %ReelClip
@onready var reel_row: HBoxContainer = %ReelRow
@onready var pointer: ColorRect = %Pointer
@onready var roulette_result: Label = %RouletteResult
@onready var btn_spin: Button = %BtnSpin
@onready var side: PanelContainer = %Side

var _filter: String = "todos"
var _selected_id: String = ""
var _patrol_id: String = "alpha"
var _mode: String = "shop" ## shop | roulette
var _spinning: bool = false
var _reel_ids: Array[String] = []
var _spin_tween: Tween


func _ready() -> void:
	_style_static_panels()
	var mode_group := ButtonGroup.new()
	btn_mode_shop.button_group = mode_group
	btn_mode_roulette.button_group = mode_group
	btn_close.pressed.connect(close)
	btn_buy.pressed.connect(_buy_selected)
	btn_mode_shop.pressed.connect(func(): _set_mode("shop"))
	btn_mode_roulette.pressed.connect(func(): _set_mode("roulette"))
	btn_spin.pressed.connect(_spin_roulette)
	GameState.credits_changed.connect(func(_v): _refresh_credits())
	visibility_changed.connect(func():
		if visible:
			_rebuild()
	)


func open(patrol_id: String = "alpha") -> void:
	_patrol_id = patrol_id if patrol_id != "" else "alpha"
	visible = true
	_set_mode(_mode if _mode != "" else "shop")
	_rebuild()


func close() -> void:
	if _spinning:
		return
	visible = false
	var router := get_parent()
	if router and router.has_method("show_map"):
		router.show_map()


func _style_static_panels() -> void:
	_apply_panel_style(credits_chip, Color(0.18, 0.12, 0.04, 0.95), Color(1.0, 0.78, 0.28), 2)
	_apply_panel_style(side, Color(0.06, 0.09, 0.14, 0.96), Color(0.85, 0.65, 0.28, 0.55), 2)
	_apply_panel_style(roulette_panel, Color(0.05, 0.08, 0.12, 0.96), Color(1.0, 0.72, 0.25, 0.7), 2)
	_style_mode_btn(btn_mode_shop, true)
	_style_mode_btn(btn_mode_roulette, false)
	_style_action_btn(btn_spin, Color(0.95, 0.62, 0.18))
	_style_action_btn(btn_buy, Color(0.28, 0.62, 0.95))
	_style_action_btn(btn_close, Color(0.35, 0.4, 0.48))


func _apply_panel_style(node: PanelContainer, bg: Color, border: Color, width: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	node.add_theme_stylebox_override("panel", sb)


func _style_mode_btn(b: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.12, 0.05, 0.95) if active else Color(0.08, 0.1, 0.14, 0.92)
	sb.border_color = Color(1.0, 0.78, 0.3) if active else Color(0.35, 0.42, 0.5)
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6) if active else Color(0.8, 0.86, 0.92))


func _style_action_btn(b: Button, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.35, accent.g * 0.28, accent.b * 0.18, 0.96)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(accent.r * 0.45, accent.g * 0.35, accent.b * 0.22, 0.98)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.88))


func _set_mode(mode: String) -> void:
	if _spinning and mode != "roulette":
		btn_mode_roulette.button_pressed = true
		btn_mode_shop.button_pressed = false
		return
	_mode = mode
	shop_pane.visible = mode == "shop"
	roulette_pane.visible = mode == "roulette"
	btn_mode_shop.button_pressed = mode == "shop"
	btn_mode_roulette.button_pressed = mode == "roulette"
	_style_mode_btn(btn_mode_shop, mode == "shop")
	_style_mode_btn(btn_mode_roulette, mode == "roulette")
	btn_buy.visible = mode == "shop"
	if mode == "roulette":
		_rebuild_roulette()
		_refresh_detail_roulette_idle()
	else:
		_rebuild_cards()
		_refresh_detail()


func _rebuild() -> void:
	_refresh_credits()
	title.text = "MERCADO U.P.R."
	var day_txt := "Día %d · Gana monedas en combates y mejora tu mazo" % GameState.day_index
	if GameState.boss_defeated:
		day_txt += " · Legendarias desbloqueadas"
	elif GameState.day_index >= GameState.BOSS_DAY:
		day_txt += " · Boss activo en el mapa"
	else:
		day_txt += " · Empieza fácil: compra mágicas/fuerza"
	sub.text = day_txt
	_rebuild_filters()
	_rebuild_odds()
	if _mode == "roulette":
		_rebuild_roulette()
		_refresh_detail_roulette_idle()
	else:
		_rebuild_cards()
		_refresh_detail()
	btn_spin.text = "GIRAR RULETA  %d monedas" % SPIN_COST
	btn_spin.disabled = _spinning or GameState.credits < SPIN_COST


func _refresh_credits() -> void:
	credits_label.text = "MONEDAS  %d" % GameState.credits
	btn_spin.disabled = _spinning or GameState.credits < SPIN_COST
	if _selected_id != "" and _mode == "shop":
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
		_style_filter_btn(b, _filter == t, t)
		var key: String = t
		b.pressed.connect(func():
			_filter = key
			_rebuild_filters()
			_rebuild_cards()
		)
		filter_row.add_child(b)


func _style_filter_btn(b: Button, active: bool, key: String) -> void:
	var col := Color(0.7, 0.78, 0.88)
	if key in ["basica", "magica", "fuerza", "legendaria"]:
		col = CardDB.rarity_color(key)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.25, col.g * 0.22, col.b * 0.18, 0.95) if active else Color(0.07, 0.09, 0.12, 0.9)
	sb.border_color = col if active else Color(0.3, 0.35, 0.42)
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_color_override("font_color", col if active else Color(0.82, 0.86, 0.92))


func _rebuild_odds() -> void:
	for c in odds_row.get_children():
		c.queue_free()
	var odds := _odds_table()
	for rar in ["basica", "magica", "fuerza", "legendaria"]:
		var pct := int(round(float(odds.get(rar, 0.0)) * 100.0))
		if pct <= 0:
			continue
		var l := Label.new()
		l.text = "%s %d%%" % [CardDB.rarity_label(rar), pct]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", CardDB.rarity_color(rar))
		odds_row.add_child(l)


func _odds_table() -> Dictionary:
	if GameState.boss_defeated:
		return {"basica": 0.48, "magica": 0.28, "fuerza": 0.17, "legendaria": 0.07}
	return {"basica": 0.52, "magica": 0.30, "fuerza": 0.18, "legendaria": 0.0}


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
		elif _filter != "todos" and typ != _filter:
			continue
		cards_grid.add_child(_make_card_tile(c))


func _make_card_tile(def: Dictionary) -> Control:
	var cid := str(def.get("id", ""))
	var rar := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	var price := CardDB.price_of(cid)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(156, 220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	sb.border_color = CardDB.rarity_color(rar)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var art_wrap := Control.new()
	art_wrap.custom_minimum_size = Vector2(0, 92)
	v.add_child(art_wrap)
	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1, 1, 1, 0.32)
	var fp := CardDB.frame_path(rar)
	if ResourceLoader.exists(fp):
		frame.texture = load(fp)
	art_wrap.add_child(frame)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_tex(art, str(def.get("art", def.get("icon", ""))))
	art_wrap.add_child(art)

	var name_l := Label.new()
	name_l.text = str(def.get("name", cid))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.clip_text = true
	name_l.add_theme_font_size_override("font_size", 12)
	v.add_child(name_l)

	var meta := Label.new()
	meta.text = "%s · %d monedas" % [CardDB.rarity_label(rar), price]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", CardDB.rarity_color(rar))
	v.add_child(meta)

	var fx := Label.new()
	fx.text = CardDB.effect_line(def)
	fx.add_theme_font_size_override("font_size", 11)
	fx.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.max_lines_visible = 2
	fx.clip_text = true
	v.add_child(fx)

	var btn := Button.new()
	btn.text = "VER"
	btn.pressed.connect(func():
		_selected_id = cid
		_refresh_detail()
	)
	v.add_child(btn)
	return panel


func _set_tex(node: TextureRect, path: String) -> void:
	if path == "":
		node.texture = null
		return
	if ResourceLoader.exists(path):
		node.texture = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		node.texture = ImageTexture.create_from_image(img) if img else null
	else:
		node.texture = null


func _refresh_detail() -> void:
	if _selected_id == "":
		detail_art.texture = null
		detail_name.text = "Elige una carta"
		detail_meta.text = ""
		detail_effect.text = "Compra en tienda o gira la ruleta para ampliar el mazo."
		detail_desc.text = ""
		btn_buy.disabled = true
		btn_buy.text = "COMPRAR"
		return
	var def := CardDB.get_card(_selected_id)
	var price := CardDB.price_of(_selected_id)
	_set_tex(detail_art, str(def.get("art", def.get("icon", ""))))
	detail_name.text = str(def.get("name", _selected_id))
	detail_meta.text = "%s · coste %d · %d monedas" % [
		CardDB.rarity_label(str(def.get("rarity", "basica"))),
		int(def.get("cost", 0)),
		price,
	]
	detail_meta.add_theme_color_override("font_color", CardDB.rarity_color(str(def.get("rarity", "basica"))))
	detail_effect.text = "[b]%s[/b]" % CardDB.effect_line(def)
	detail_desc.text = CardDB.flavor_line(def)
	btn_buy.disabled = GameState.credits < price
	btn_buy.text = "COMPRAR  %d monedas" % price


func _refresh_detail_roulette_idle() -> void:
	detail_art.texture = null
	detail_name.text = "Ruleta U.P.R."
	detail_meta.text = "Coste por giro: %d monedas" % SPIN_COST
	detail_meta.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	detail_effect.text = "Premio aleatorio según rareza."
	detail_desc.text = "La carta ganada se añade al mazo de Kick-Ass."
	btn_buy.disabled = true
	btn_buy.text = "COMPRAR"


func _buy_selected() -> void:
	if _selected_id == "" or _mode != "shop":
		return
	if GameState.buy_card_for_patrol(_patrol_id, _selected_id):
		_rebuild()
	else:
		RadioBus.push("Monedas insuficientes. Gana combates para conseguir más.", "alert")


func _pool_by_rarity() -> Dictionary:
	var pools := {
		"basica": [],
		"magica": [],
		"fuerza": [],
		"legendaria": [],
	}
	for c in CardDB.cards_for_market(GameState.boss_defeated):
		var rar := CardDB.normalize_rarity(str(c.get("rarity", "basica")))
		if pools.has(rar):
			pools[rar].append(str(c.get("id", "")))
	return pools


func _pick_roulette_card() -> String:
	var pools: Dictionary = _pool_by_rarity()
	var odds: Dictionary = _odds_table()
	var roll := randf()
	var acc := 0.0
	var chosen_rar := "basica"
	for rar in ["basica", "magica", "fuerza", "legendaria"]:
		acc += float(odds.get(rar, 0.0))
		if roll <= acc:
			chosen_rar = rar
			break
	var pool: Array = pools.get(chosen_rar, [])
	if pool.is_empty():
		# fallback a cualquier stock
		for rar2 in ["magica", "basica", "fuerza", "legendaria"]:
			pool = pools.get(rar2, [])
			if not pool.is_empty():
				break
	if pool.is_empty():
		return ""
	return str(pool[randi() % pool.size()])


func _rebuild_roulette() -> void:
	for c in reel_row.get_children():
		c.queue_free()
	_reel_ids.clear()
	var visual_pool: Array[String] = _weighted_visual_pool()
	if visual_pool.is_empty():
		roulette_result.text = "Sin cartas disponibles"
		btn_spin.disabled = true
		return
	visual_pool.shuffle()
	# Cinta larga: varias vueltas del pool ponderado
	for _loop in range(4):
		var loop_ids: Array[String] = visual_pool.duplicate()
		loop_ids.shuffle()
		for cid in loop_ids:
			_reel_ids.append(cid)
			reel_row.add_child(_make_reel_card(CardDB.get_card(cid)))
	reel_row.position = Vector2(0, 0)
	roulette_result.text = "Listo para girar · %d monedas" % SPIN_COST
	roulette_result.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))


func _weighted_visual_pool() -> Array[String]:
	## Más básicas en la cinta, pocas fuerza/legendarias (refleja odds).
	var out: Array[String] = []
	var pools: Dictionary = _pool_by_rarity()
	var weights := {"basica": 5, "magica": 3, "fuerza": 2, "legendaria": 1}
	for rar in ["basica", "magica", "fuerza", "legendaria"]:
		var pool: Array = pools.get(rar, [])
		if pool.is_empty():
			continue
		var copies: int = int(weights.get(rar, 1))
		for _c in range(copies):
			for cid in pool:
				out.append(str(cid))
	return out


func _make_reel_card(def: Dictionary) -> Control:
	var rar := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(REEL_CARD_W, 200)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.98)
	sb.border_color = CardDB.rarity_color(rar)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 100)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_tex(art, str(def.get("art", def.get("icon", ""))))
	v.add_child(art)
	var name_l := Label.new()
	name_l.text = str(def.get("name", "?"))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.clip_text = true
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var rar_l := Label.new()
	rar_l.text = CardDB.rarity_label(rar)
	rar_l.add_theme_font_size_override("font_size", 11)
	rar_l.add_theme_color_override("font_color", CardDB.rarity_color(rar))
	rar_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rar_l)
	return panel


func _spin_roulette() -> void:
	if _spinning:
		return
	if GameState.credits < SPIN_COST:
		RadioBus.push("Créditos insuficientes para la ruleta.", "alert")
		return
	var prize_id := _pick_roulette_card()
	if prize_id == "":
		RadioBus.push("Ruleta sin stock.", "alert")
		return
	if not GameState.spend_credits(SPIN_COST):
		RadioBus.push("Créditos insuficientes.", "alert")
		return

	_spinning = true
	btn_spin.disabled = true
	btn_close.disabled = true
	roulette_result.text = "Girando…"
	roulette_result.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))

	# Asegura que el premio aparece cerca del final de la cinta
	var stop_index := maxi(12, _reel_ids.size() - 8 - (randi() % 5))
	stop_index = mini(stop_index, _reel_ids.size() - 2)
	if stop_index < _reel_ids.size():
		_reel_ids[stop_index] = prize_id
		# refresca esa celda visual
		var cell: Control = reel_row.get_child(stop_index)
		if cell:
			var old_i := cell.get_index()
			reel_row.remove_child(cell)
			cell.queue_free()
			var fresh := _make_reel_card(CardDB.get_card(prize_id))
			reel_row.add_child(fresh)
			reel_row.move_child(fresh, old_i)

	await get_tree().process_frame
	var clip_w := reel_clip.size.x
	var card_span := REEL_CARD_W + REEL_GAP
	var target_x := (clip_w * 0.5) - (float(stop_index) * card_span + REEL_CARD_W * 0.5)
	reel_row.position = Vector2(0, 0)
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = create_tween()
	_spin_tween.tween_property(reel_row, "position:x", target_x, 2.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await _spin_tween.finished

	GameState.add_card_to_deck(_patrol_id, prize_id)
	var def := CardDB.get_card(prize_id)
	var rar := CardDB.normalize_rarity(str(def.get("rarity", "basica")))
	_selected_id = prize_id
	_set_tex(detail_art, str(def.get("art", def.get("icon", ""))))
	detail_name.text = str(def.get("name", prize_id))
	detail_meta.text = "PREMIO · %s" % CardDB.rarity_label(rar)
	detail_meta.add_theme_color_override("font_color", CardDB.rarity_color(rar))
	detail_effect.text = "[b]%s[/b]" % CardDB.effect_line(def)
	detail_desc.text = CardDB.flavor_line(def)
	roulette_result.text = "¡%s! Añadida al mazo." % str(def.get("name", prize_id))
	roulette_result.add_theme_color_override("font_color", CardDB.rarity_color(rar))
	RadioBus.push("Ruleta: «%s» (−%d monedas)." % [str(def.get("name", prize_id)), SPIN_COST], "resolve")

	_spinning = false
	btn_close.disabled = false
	_refresh_credits()
	btn_spin.disabled = GameState.credits < SPIN_COST
