extends Node
## Turn-based card combat (Slay-the-Spire style) for THE QUEST FINAL.
## One protagonist patrol vs suspects with intents.

signal combat_started
signal combat_updated
signal combat_ended(victory: bool)
signal log_message(text: String)

enum Phase { PLAYER, ENEMY, RESOLVING, ENDED }
enum Intent { ATTACK, BLOCK, FLEE }

var active: bool = false
var phase: Phase = Phase.PLAYER
var turn: int = 1

var player: Dictionary = {}
var enemies: Array = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []
var selected_enemy: int = 0
var mission_id: String = ""
var location_label: String = ""
var objective: String = "Detener a los sospechosos"
var last_log: String = ""

const HAND_SIZE := 5
const INTENT_LABELS := {
	Intent.ATTACK: "DISPARAR",
	Intent.BLOCK: "CUBRIRSE",
	Intent.FLEE: "HUIR",
}


func is_active() -> bool:
	return active and phase != Phase.ENDED


func start_combat(cfg: Dictionary) -> void:
	active = true
	phase = Phase.PLAYER
	turn = 1
	mission_id = str(cfg.get("mission_id", ""))
	location_label = str(cfg.get("location", "Intervención"))
	objective = str(cfg.get("objective", "Detener a los sospechosos"))
	last_log = "Intervención iniciada. Elige cartas."

	var max_hp := int(cfg.get("max_hp", 50))
	player = {
		"name": str(cfg.get("hero_name", "García")),
		"hp": max_hp,
		"max_hp": max_hp,
		"block": 0,
		"energy": int(cfg.get("energy_max", 3)),
		"energy_max": int(cfg.get("energy_max", 3)),
		"vulnerable": 0,
		"portrait": str(cfg.get("portrait", "garcia")),
		"sprite": str(cfg.get("sprite", "patrol_01")),
	}

	enemies.clear()
	var raw_enemies: Array = cfg.get("enemies", [])
	for i in range(raw_enemies.size()):
		var e: Dictionary = raw_enemies[i]
		var ehp := int(e.get("hp", 28 + i * 4))
		enemies.append({
			"id": str(e.get("id", "e%d" % i)),
			"name": str(e.get("name", "Sospechoso")),
			"hp": ehp,
			"max_hp": ehp,
			"block": 0,
			"intent": Intent.ATTACK,
			"intent_value": 8 + i * 2,
			"detained": false,
			"fled": false,
			"vulnerable": 0,
			"weak": 0,
			"portrait": str(e.get("portrait", "")),
			"sprite": str(e.get("sprite", "delinquent_01")),
		})
	_roll_intents()
	selected_enemy = _first_living_enemy()

	draw_pile.clear()
	discard_pile.clear()
	hand.clear()
	var deck: Array = cfg.get("deck", [])
	for c in deck:
		draw_pile.append(str(c))
	draw_pile.shuffle()
	_draw_cards(HAND_SIZE)

	combat_started.emit()
	combat_updated.emit()
	log_message.emit(last_log)


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"turn": turn,
		"player": player.duplicate(true),
		"enemies": enemies.duplicate(true),
		"hand": hand.duplicate(),
		"draw_count": draw_pile.size(),
		"discard_count": discard_pile.size(),
		"selected_enemy": selected_enemy,
		"location": location_label,
		"objective": objective,
		"mission_id": mission_id,
		"last_log": last_log,
	}


func select_enemy(index: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	var e: Dictionary = enemies[index]
	# Permite apuntar a derribados (0 PV) para Esposar.
	if bool(e.get("detained", false)) or bool(e.get("fled", false)):
		return
	selected_enemy = index
	combat_updated.emit()


func can_play_card(card_id: String) -> bool:
	if not is_active() or phase != Phase.PLAYER:
		return false
	if card_id not in hand:
		return false
	var def := CardDB.get_card(card_id)
	if def.is_empty():
		return false
	return int(player.get("energy", 0)) >= int(def.get("cost", 0))


func play_card(card_id: String, target_index: int = -1) -> bool:
	if not can_play_card(card_id):
		return false
	var def := CardDB.get_card(card_id)
	var cost := int(def.get("cost", 0))
	player["energy"] = int(player.get("energy", 0)) - cost

	var idx := hand.find(card_id)
	if idx >= 0:
		hand.remove_at(idx)
	discard_pile.append(card_id)

	var tgt := target_index if target_index >= 0 else selected_enemy
	_resolve_card(def, tgt)
	_check_end_conditions()
	combat_updated.emit()
	return true


func end_player_turn() -> void:
	if not is_active() or phase != Phase.PLAYER:
		return
	phase = Phase.ENEMY
	# Discard remaining hand
	for c in hand:
		discard_pile.append(c)
	hand.clear()
	combat_updated.emit()
	_enemy_turn()


func _resolve_card(def: Dictionary, target_index: int) -> void:
	var target_mode := str(def.get("target", "enemy"))
	var dmg := int(def.get("damage", 0))
	var hits := maxi(1, int(def.get("hits", 1)))
	var block := int(def.get("block", 0))
	var heal := int(def.get("heal", 0))
	var draw_n := int(def.get("draw", 0))
	var title := str(def.get("name", "Carta"))

	if block > 0:
		player["block"] = int(player.get("block", 0)) + block
		_log("%s: +%d defensa." % [title, block])

	if heal > 0:
		player["hp"] = mini(int(player.get("max_hp", 50)), int(player.get("hp", 0)) + heal)
		_log("%s: recuperas %d PV." % [title, heal])

	if draw_n > 0:
		_draw_cards(draw_n)
		_log("%s: robas %d." % [title, draw_n])

	if target_mode == "self":
		return

	var indices: Array[int] = []
	if target_mode == "all":
		for i in range(enemies.size()):
			if _enemy_alive(i):
				indices.append(i)
	else:
		if target_index < 0 or not _enemy_alive(target_index):
			target_index = _first_living_enemy()
		if target_index >= 0:
			indices.append(target_index)
			selected_enemy = target_index

	for i in indices:
		var e: Dictionary = enemies[i]
		if dmg > 0:
			var total := 0
			for _h in range(hits):
				var hit_dmg := dmg
				if int(e.get("vulnerable", 0)) > 0:
					hit_dmg = int(ceil(hit_dmg * 1.5))
				if int(e.get("weak", 0)) > 0:
					hit_dmg = int(floor(hit_dmg * 0.75))
				total += _deal_to_enemy(i, hit_dmg)
			_log("%s → %s: %d daño." % [title, e.get("name", "?"), total])

		var vul_n := int(def.get("vulnerable", 0))
		if vul_n > 0 or bool(def.get("vulnerable", false)):
			e["vulnerable"] = int(e.get("vulnerable", 0)) + maxi(1, vul_n)
			_log("%s vulnerable." % e.get("name", "?"))
		var weak_n := int(def.get("weaken", 0))
		if weak_n > 0 or bool(def.get("weaken", false)):
			e["weak"] = int(e.get("weak", 0)) + maxi(1, weak_n)
		if int(def.get("stun", 0)) > 0 or bool(def.get("stun", false)):
			e["stunned"] = true
			e["intent"] = Intent.BLOCK
			e["intent_value"] = 0
			_log("%s aturdido." % e.get("name", "?"))
		if bool(def.get("detain", false)):
			if int(e.get("hp", 0)) <= 0 and not bool(e.get("detained", false)):
				e["detained"] = true
				_log("%s detenido." % e.get("name", "?"))
		enemies[i] = e


func _deal_to_enemy(index: int, amount: int) -> int:
	var e: Dictionary = enemies[index]
	var blk := int(e.get("block", 0))
	var dealt := amount
	if blk > 0:
		var absorb := mini(blk, amount)
		e["block"] = blk - absorb
		dealt = amount - absorb
	e["hp"] = maxi(0, int(e.get("hp", 0)) - dealt)
	if int(e.get("hp", 0)) <= 0 and not bool(e.get("detained", false)):
		# Downed — can still be cuffed next card / auto-detain if already 0
		pass
	enemies[index] = e
	return dealt


func _deal_to_player(amount: int) -> int:
	var blk := int(player.get("block", 0))
	var dealt := amount
	if blk > 0:
		var absorb := mini(blk, amount)
		player["block"] = blk - absorb
		dealt = amount - absorb
	if int(player.get("vulnerable", 0)) > 0:
		dealt = int(ceil(dealt * 1.5))
	player["hp"] = maxi(0, int(player.get("hp", 0)) - dealt)
	return dealt


func _enemy_turn() -> void:
	phase = Phase.RESOLVING
	for i in range(enemies.size()):
		if not _enemy_alive(i):
			continue
		var e: Dictionary = enemies[i]
		if bool(e.get("stunned", false)):
			_log("%s está aturdido y no actúa." % e.get("name", "?"))
			e["stunned"] = false
		else:
			match int(e.get("intent", Intent.ATTACK)):
				Intent.ATTACK:
					var dmg := int(e.get("intent_value", 8))
					if int(e.get("weak", 0)) > 0:
						dmg = int(floor(dmg * 0.75))
					var dealt := _deal_to_player(dmg)
					_log("%s dispara: %d daño." % [e.get("name", "?"), dealt])
				Intent.BLOCK:
					var b := int(e.get("intent_value", 6))
					e["block"] = int(e.get("block", 0)) + b
					_log("%s se cubre (+%d)." % [e.get("name", "?"), b])
				Intent.FLEE:
					if int(e.get("hp", 0)) <= int(e.get("max_hp", 1)) * 0.35:
						e["fled"] = true
						e["hp"] = 0
						_log("%s huye!" % e.get("name", "?"))
					else:
						var poke := 4
						var dealt := _deal_to_player(poke)
						_log("%s intenta huir y te roza (%d)." % [e.get("name", "?"), dealt])
		# Decay statuses
		e["vulnerable"] = maxi(0, int(e.get("vulnerable", 0)) - 1)
		e["weak"] = maxi(0, int(e.get("weak", 0)) - 1)
		enemies[i] = e
		if int(player.get("hp", 0)) <= 0:
			break

	player["vulnerable"] = maxi(0, int(player.get("vulnerable", 0)) - 1)
	player["block"] = 0  # block resets each turn like STS

	if _check_end_conditions():
		return

	# New player turn
	turn += 1
	phase = Phase.PLAYER
	player["energy"] = int(player.get("energy_max", 3))
	_roll_intents()
	_draw_cards(HAND_SIZE)
	_log("Turno %d — tu jugada." % turn)
	combat_updated.emit()


func _roll_intents() -> void:
	for i in range(enemies.size()):
		if not _enemy_alive(i):
			continue
		var e: Dictionary = enemies[i]
		var roll := randi() % 100
		var hp_ratio := float(e.get("hp", 1)) / float(maxi(1, int(e.get("max_hp", 1))))
		if hp_ratio < 0.3 and roll < 40:
			e["intent"] = Intent.FLEE
			e["intent_value"] = 0
		elif roll < 55:
			e["intent"] = Intent.ATTACK
			e["intent_value"] = 7 + (turn / 2) + (i * 2)
		elif roll < 85:
			e["intent"] = Intent.BLOCK
			e["intent_value"] = 5 + i * 2
		else:
			e["intent"] = Intent.ATTACK
			e["intent_value"] = 10 + turn
		enemies[i] = e


func _draw_cards(n: int) -> void:
	for _i in range(n):
		if hand.size() >= 10:
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())


func _enemy_alive(index: int) -> bool:
	if index < 0 or index >= enemies.size():
		return false
	var e: Dictionary = enemies[index]
	if bool(e.get("detained", false)) or bool(e.get("fled", false)):
		return false
	return int(e.get("hp", 0)) > 0


func _first_living_enemy() -> int:
	for i in range(enemies.size()):
		if _enemy_alive(i):
			return i
	# Also allow targeting downed (0 hp) for cuff
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if not bool(e.get("detained", false)) and not bool(e.get("fled", false)):
			return i
	return -1


func living_enemy_count() -> int:
	var n := 0
	for i in range(enemies.size()):
		if _enemy_alive(i):
			n += 1
	return n


func all_neutralized() -> bool:
	for e in enemies:
		var ed: Dictionary = e
		if bool(ed.get("fled", false)):
			continue
		if bool(ed.get("detained", false)):
			continue
		if int(ed.get("hp", 0)) > 0:
			return false
		# Downed but not detained — still need cuff ideally, but count as win if all <=0
	# Victory if no living threats
	return living_enemy_count() == 0


func _check_end_conditions() -> bool:
	if int(player.get("hp", 0)) <= 0:
		_end_combat(false)
		return true
	# Auto-detain downed enemies at end of card resolve if player used cuff; else win when all hp<=0
	if living_enemy_count() == 0:
		# Mark remaining downed as detained for flavor
		for i in range(enemies.size()):
			var e: Dictionary = enemies[i]
			if int(e.get("hp", 0)) <= 0 and not bool(e.get("fled", false)):
				e["detained"] = true
				enemies[i] = e
		_end_combat(true)
		return true
	return false


func _end_combat(victory: bool) -> void:
	phase = Phase.ENDED
	active = false
	last_log = "Intervención exitosa." if victory else "La unidad cae. Abortar."
	_log(last_log)
	combat_ended.emit(victory)
	combat_updated.emit()


func intent_label(intent: int) -> String:
	return str(INTENT_LABELS.get(intent, "?"))


func _log(text: String) -> void:
	last_log = text
	log_message.emit(text)
