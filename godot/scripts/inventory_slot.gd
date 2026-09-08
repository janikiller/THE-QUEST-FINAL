extends PanelContainer
## Slot de inventario con arrastre, soltar y tooltip.

signal slot_changed

const SLOT_SIZE := Vector2(64, 64)

var container_path: String = "" ## e.g. "shared", "trunk", "agents/0/principal"
var index: int = 0
var accepted_kinds: PackedStringArray = PackedStringArray() ## empty = any
var item_id: String = ""
var quantity: int = 1
var locked: bool = false
var _hint: String = ""

@onready var icon: TextureRect = $Margin/Icon
@onready var qty_label: Label = $Margin/Qty
@onready var empty_hint: Label = $Margin/EmptyHint


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if empty_hint and _hint != "":
		empty_hint.text = _hint
	_refresh()


func setup(path: String, idx: int, accepts: PackedStringArray = PackedStringArray(), hint: String = "") -> void:
	container_path = path
	index = idx
	accepted_kinds = accepts
	_hint = hint
	if empty_hint:
		empty_hint.text = hint
	_refresh()


func set_item(id: String, qty: int = 1) -> void:
	item_id = id
	quantity = qty
	_refresh()
	slot_changed.emit()


func clear_item() -> void:
	item_id = ""
	quantity = 0
	_refresh()
	slot_changed.emit()


func _refresh() -> void:
	if icon == null:
		return
	if item_id == "":
		icon.texture = null
		qty_label.text = ""
		empty_hint.visible = empty_hint.text != ""
		tooltip_text = ""
		modulate = Color(1, 1, 1, 1)
		return
	empty_hint.visible = false
	var def: Dictionary = ItemDB.get_item(item_id)
	var tex_path := str(def.get("icon", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		icon.texture = load(tex_path)
	else:
		icon.texture = null
	qty_label.text = ("x%d" % quantity) if quantity > 1 else ""
	var nombre := str(def.get("name", item_id))
	var desc := str(def.get("description", ""))
	tooltip_text = "%s\n%s" % [nombre, desc]


func _get_drag_data(_at: Vector2) -> Variant:
	if locked or item_id == "":
		return null
	var preview := TextureRect.new()
	preview.texture = icon.texture
	preview.custom_minimum_size = Vector2(56, 56)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.9)
	set_drag_preview(preview)
	modulate = Color(1, 1, 1, 0.35)
	return {
		"type": "inventory_item",
		"item_id": item_id,
		"quantity": quantity,
		"from_path": container_path,
		"from_index": index,
		"source": self,
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1, 1, 1, 1)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if locked:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("type", "") != "inventory_item":
		return false
	var incoming: String = str(data.get("item_id", ""))
	if incoming == "":
		return false
	# Same slot
	if data.get("from_path", "") == container_path and int(data.get("from_index", -1)) == index:
		return false
	if accepted_kinds.is_empty():
		return true
	var def: Dictionary = ItemDB.get_item(incoming)
	var kind := str(def.get("slot", "varios"))
	var cat := str(def.get("category", "varios"))
	for a in accepted_kinds:
		if a == kind or a == cat or a == "any":
			return true
	return false


func _drop_data(_at: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at, data):
		return
	var screen := _find_inventory_screen()
	if screen and screen.has_method("transfer_item"):
		screen.transfer_item(
			str(data.get("from_path", "")),
			int(data.get("from_index", 0)),
			container_path,
			index
		)
	else:
		# Fallback swap local
		var src: Control = data.get("source")
		if src and src.has_method("set_item"):
			var other_id: String = item_id
			var other_qty: int = quantity
			set_item(str(data.get("item_id", "")), int(data.get("quantity", 1)))
			src.set_item(other_id, other_qty)


func _find_inventory_screen() -> Node:
	var n: Node = self
	while n:
		if n.has_method("transfer_item"):
			return n
		n = n.get_parent()
	return null
