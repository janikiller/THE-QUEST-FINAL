extends Node
## Turn-based card combat (Slay-the-Spire style) for THE QUEST FINAL.
## One protagonist patrol vs suspects with intents.

signal combat_started
signal combat_updated
signal combat_ended(victory: bool)
signal log_message(text: String)
signal enemy_defeated(enemy_index: int, xp_gained: int)

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
var combat_xp_gained: int = 0
var combat_kills: int = 0
var combat_levels_gained: int = 0

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
		"name": str(cfg.get("hero_name", "Kick-Ass")),
		"hp": max_hp,
		"max_hp": max_hp,
		"block": 0,
		"energy": int(cfg.get("energy_max", 3)),
		"energy_max": int(cfg.get("energy_max", 3)),
		"vulnerable": 0,
		"weak": 0,
		"portrait": str(cfg.get("portrait", "garcia")),
		"sprite": str(cfg.get("sprite", "patrol_01")),
		"next_bonus": 0,
		"double_next": false,
		"fury_turns": 0,
		"lifesteal_turns": 0,
		"dodge_turn": false,
		"reflect_turn": false,
		"free_play": false,
		"infinite_draw": false,
		"transform_turns": 0,
		"revive": 0,
		"share_damage": false,
		"ally_turns": 0,
		"ally_power": 0,
		"last_card_id": "",
	}

	enemies.clear()
	var raw_enemies: Array = cfg.get("enemies", [])
	for i in range(raw_enemies.size()):
		var e: Dictionary = raw_enemies[i]
		var ehp := int(e.get("hp", 28 + i * 4))
		enemies.append({
			"id": str(e.get("id", "e%d" % i)),
			"name": str(e.get("name", "Sospechoso")),
			"alias": str(e.get("alias", "")),
			"hp": ehp,
			"max_hp": ehp,
			"block": 0,
			"intent": Intent.ATTACK,
			"intent_value": 8 + i * 2,
			"detained": false,
			"fled": false,
			"vulnerable": 0,
			"weak": 0,
			"burn": 0,
			"mark": 0,
			"miss_attack": false,
			"stunned": false,
			"portrait": str(e.get("portrait", "")),
			"sprite": str(e.get("sprite", "delinquent_01")),
			"is_boss": bool(e.get("is_boss", false)),
			"pose_attack": str(e.get("pose_attack", "")),
			"pose_hurt": str(e.get("pose_hurt", "")),
			"role": str(e.get("role", e.get("archetype", "ataque"))),
			"boss_id": str(e.get("boss_id", e.get("id", ""))),
			"card_pool": _build_enemy_pool(e),
			"next_card": "",
			"next_card_name": "",
			"next_card_effect": "",
		})
	_roll_intents()
	selected_enemy = _first_living_enemy()

	draw_pile.clear()
	discard_pile.clear()
	hand.clear()
	combat_xp_gained = 0
	combat_kills = 0
	combat_levels_gained = 0
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
		"combat_xp": combat_xp_gained,
		"combat_kills": combat_kills,
		"combat_levels": combat_levels_gained,
		"hero_level": GameState.hero_level,
		"hero_xp": GameState.hero_xp,
		"xp_to_next": GameState.xp_to_next_level(),
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
	var cost := _card_cost(def)
	return int(player.get("energy", 0)) >= cost


func _card_cost(def: Dictionary) -> int:
	if bool(player.get("free_play", false)):
		return 0
	return int(def.get("cost", 0))


func play_card(card_id: String, target_index: int = -1) -> bool:
	if not can_play_card(card_id):
		return false
	var def := CardDB.get_card(card_id)
	var cost := _card_cost(def)
	player["energy"] = int(player.get("energy", 0)) - cost

	var idx := hand.find(card_id)
	if idx >= 0:
		hand.remove_at(idx)
	discard_pile.append(card_id)

	var tgt := target_index if target_index >= 0 else selected_enemy
	_resolve_card(def, tgt)
	# Infinito: cada carta jugada roba otra.
	if bool(player.get("infinite_draw", false)) and str(def.get("id", "")) != "infinito":
		_draw_cards(1)
	if str(def.get("id", "")) != "eco":
		player["last_card_id"] = str(def.get("id", card_id))
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
	var pierce := bool(def.get("pierce", false))

	# Buffs / utilidades de self
	if int(def.get("next_bonus", 0)) > 0:
		player["next_bonus"] = int(player.get("next_bonus", 0)) + int(def.get("next_bonus", 0))
		_log("%s: siguiente carta +%d daño." % [title, int(def.get("next_bonus", 0))])
	if bool(def.get("double_next", false)):
		player["double_next"] = true
		_log("%s: el siguiente ataque se repite." % title)
	if int(def.get("fury_turns", 0)) > 0:
		player["fury_turns"] = maxi(int(player.get("fury_turns", 0)), int(def.get("fury_turns", 0)))
		_log("%s: furia %d turnos." % [title, int(def.get("fury_turns", 0))])
	if int(def.get("lifesteal_turns", 0)) > 0:
		player["lifesteal_turns"] = maxi(int(player.get("lifesteal_turns", 0)), int(def.get("lifesteal_turns", 0)))
		_log("%s: aura de sangre %d turnos." % [title, int(def.get("lifesteal_turns", 0))])
	if bool(def.get("dodge", false)):
		player["dodge_turn"] = true
		_log("%s: esquivas todos los golpes este turno." % title)
	if bool(def.get("reflect", false)):
		player["reflect_turn"] = true
		_log("%s: reflejas el daño este turno." % title)
	if bool(def.get("free_play", false)):
		player["free_play"] = true
		_log("%s: cartas a coste 0 este turno." % title)
	if bool(def.get("infinite_draw", false)):
		player["infinite_draw"] = true
		_log("%s: cada carta roba otra." % title)
	if int(def.get("transform_turns", 0)) > 0:
		player["transform_turns"] = maxi(int(player.get("transform_turns", 0)), int(def.get("transform_turns", 0)))
		player["energy_max"] = maxi(int(player.get("energy_max", 3)), 4)
		player["energy"] = int(player.get("energy", 0)) + 1
		_log("%s: Avatar activo %d turnos." % [title, int(def.get("transform_turns", 0))])
	if int(def.get("grant_revive", 0)) > 0:
		player["revive"] = int(player.get("revive", 0)) + int(def.get("grant_revive", 0))
		_log("%s: ganas un segundo latido." % title)
	if bool(def.get("share_damage", false)):
		player["share_damage"] = true
		_log("%s: vínculo maldito activo." % title)
	if int(def.get("ally_turns", 0)) > 0:
		player["ally_turns"] = maxi(int(player.get("ally_turns", 0)), int(def.get("ally_turns", 0)))
		player["ally_power"] = maxi(int(player.get("ally_power", 0)), int(def.get("ally_power", 0)))
		_log("%s: aliado sombra %d turnos." % [title, int(def.get("ally_turns", 0))])
	if bool(def.get("recover_discard", false)):
		var n := discard_pile.size()
		for c in discard_pile:
			draw_pile.append(c)
		discard_pile.clear()
		draw_pile.shuffle()
		_log("%s: recuperas %d descartes." % [title, n])
	if bool(def.get("replay_last", false)):
		var last_id := str(player.get("last_card_id", ""))
		if last_id != "" and last_id != "eco":
			var last_def := CardDB.get_card(last_id)
			if not last_def.is_empty():
				_log("%s: repite %s." % [title, last_def.get("name", last_id)])
				_resolve_card(last_def, target_index)
				return

	if block > 0:
		player["block"] = int(player.get("block", 0)) + block
		_log("%s: +%d defensa." % [title, block])

	if heal > 0:
		player["hp"] = mini(int(player.get("max_hp", 50)), int(player.get("hp", 0)) + heal)
		_log("%s: recuperas %d PV." % [title, heal])

	if draw_n > 0:
		_draw_cards(draw_n)
		_log("%s: robas %d." % [title, draw_n])

	if target_mode == "self" and dmg <= 0 and not bool(def.get("break_block", false)) and int(def.get("execute_weak", 0)) == 0 and not bool(def.get("stun", false)):
		return

	var indices: Array[int] = []
	if target_mode == "all":
		for i in range(enemies.size()):
			if _enemy_alive(i) or bool(def.get("break_block", false)):
				if not bool(enemies[i].get("detained", false)) and not bool(enemies[i].get("fled", false)):
					if _enemy_alive(i) or bool(def.get("break_block", false)):
						indices.append(i)
	else:
		if target_index < 0 or not _enemy_alive(target_index):
			target_index = _first_living_enemy()
		if target_index >= 0:
			indices.append(target_index)
			selected_enemy = target_index

	# Bonos de daño globales
	var bonus := int(player.get("next_bonus", 0))
	if dmg > 0 and bonus > 0:
		dmg += bonus
		player["next_bonus"] = 0
	if dmg > 0 and int(player.get("fury_turns", 0)) > 0:
		dmg = int(ceil(float(dmg) * 1.35))
	if dmg > 0 and int(player.get("transform_turns", 0)) > 0:
		dmg = int(ceil(float(dmg) * 1.25))
	if dmg > 0 and bool(player.get("double_next", false)) and str(def.get("type", "")) == "ataque":
		hits *= 2
		player["double_next"] = false
		_log("Doble impacto!")

	for i in indices:
		var e: Dictionary = enemies[i]
		if bool(def.get("break_block", false)):
			e["block"] = 0
			_log("%s: rompe el escudo de %s." % [title, e.get("name", "?")])
		if dmg > 0 and _enemy_alive(i):
			var total := 0
			for _h in range(hits):
				var hit_dmg := dmg
				if int(e.get("vulnerable", 0)) > 0:
					hit_dmg = int(ceil(hit_dmg * 1.5))
				if int(player.get("weak", 0)) > 0:
					hit_dmg = int(floor(hit_dmg * 0.75))
				hit_dmg += int(e.get("mark", 0))
				total += _deal_to_enemy(i, hit_dmg, pierce)
			_log("%s → %s: %d daño." % [title, e.get("name", "?"), total])
			if int(player.get("lifesteal_turns", 0)) > 0 and total > 0:
				var healed := mini(4, total)
				player["hp"] = mini(int(player.get("max_hp", 50)), int(player.get("hp", 0)) + healed)
				_log("Aura de sangre: +%d PV." % healed)
		e = enemies[i]
		var vul_n := int(def.get("vulnerable", 0))
		if vul_n > 0 or bool(def.get("vulnerable", false)):
			e["vulnerable"] = int(e.get("vulnerable", 0)) + maxi(1, vul_n)
			_log("%s vulnerable." % e.get("name", "?"))
		var weak_n := int(def.get("weaken", 0))
		if weak_n > 0 or bool(def.get("weaken", false)):
			e["weak"] = int(e.get("weak", 0)) + maxi(1, weak_n)
			_log("%s debilitado." % e.get("name", "?"))
		if int(def.get("burn", 0)) > 0:
			e["burn"] = int(e.get("burn", 0)) + int(def.get("burn", 0))
			_log("%s arde (%d)." % [e.get("name", "?"), e["burn"]])
		if int(def.get("mark", 0)) > 0:
			e["mark"] = int(e.get("mark", 0)) + int(def.get("mark", 0))
			_log("%s marcado (+%d)." % [e.get("name", "?"), int(def.get("mark", 0))])
		if bool(def.get("miss_attack", false)):
			e["miss_attack"] = true
			_log("%s fallará su próximo ataque." % e.get("name", "?"))
		if int(def.get("stun", 0)) > 0 or bool(def.get("stun", false)):
			e["stunned"] = true
			e["intent"] = Intent.BLOCK
			e["intent_value"] = 0
			_log("%s aturdido." % e.get("name", "?"))
		# Execute weak
		var exec_r := float(def.get("execute_weak", 0))
		if exec_r > 0.0 and _enemy_alive(i):
			var ratio := float(e.get("hp", 0)) / maxf(1.0, float(e.get("max_hp", 1)))
			if ratio <= exec_r:
				_deal_to_enemy(i, int(e.get("hp", 0)) + int(e.get("block", 0)), true)
				_log("Corte absoluto: %s eliminado." % e.get("name", "?"))
		if bool(def.get("detain", false)):
			if int(e.get("hp", 0)) <= 0 and not bool(e.get("detained", false)):
				e["detained"] = true
				_log("%s detenido." % e.get("name", "?"))
		enemies[i] = e


func _deal_to_enemy(index: int, amount: int, pierce: bool = false) -> int:
	var e: Dictionary = enemies[index]
	var hp_before := int(e.get("hp", 0))
	var blk := int(e.get("block", 0))
	var dealt := amount
	if (not pierce) and blk > 0:
		var absorb := mini(blk, amount)
		e["block"] = blk - absorb
		dealt = amount - absorb
	e["hp"] = maxi(0, int(e.get("hp", 0)) - dealt)
	if hp_before > 0 and int(e.get("hp", 0)) <= 0 and not bool(e.get("xp_granted", false)):
		e["xp_granted"] = true
		var xp := _xp_for_enemy(e)
		var res: Dictionary = GameState.add_combat_xp(xp)
		combat_xp_gained += int(res.get("xp", xp))
		combat_kills += 1
		combat_levels_gained += int(res.get("levels", 0))
		_log("%s neutralizado (+%d XP)." % [e.get("name", "?"), xp])
		enemy_defeated.emit(index, xp)
	enemies[index] = e
	return dealt


func _xp_for_enemy(e: Dictionary) -> int:
	var max_hp := maxi(1, int(e.get("max_hp", 28)))
	if bool(e.get("is_boss", false)):
		return 90 + max_hp / 4
	return 10 + max_hp / 3


func _deal_to_player(amount: int, from_enemy: int = -1) -> int:
	if bool(player.get("dodge_turn", false)):
		_log("Paso Fantasma: esquivas el golpe.")
		return 0
	var blk := int(player.get("block", 0))
	var dealt := amount
	if blk > 0:
		var absorb := mini(blk, amount)
		player["block"] = blk - absorb
		dealt = amount - absorb
	if int(player.get("vulnerable", 0)) > 0:
		dealt = int(ceil(dealt * 1.5))
	player["hp"] = maxi(0, int(player.get("hp", 0)) - dealt)
	if dealt > 0 and bool(player.get("reflect_turn", false)) and from_enemy >= 0 and _enemy_alive(from_enemy):
		_deal_to_enemy(from_enemy, dealt, true)
		_log("Reflejo Mortal: devuelves %d." % dealt)
	if dealt > 0 and bool(player.get("share_damage", false)):
		var share_i := selected_enemy if _enemy_alive(selected_enemy) else _first_living_enemy()
		if share_i >= 0:
			_deal_to_enemy(share_i, dealt, false)
			_log("Vínculo Maldito: compartes %d." % dealt)
	if int(player.get("hp", 0)) <= 0 and int(player.get("revive", 0)) > 0:
		player["revive"] = int(player.get("revive", 0)) - 1
		player["hp"] = maxi(1, int(float(player.get("max_hp", 50)) * 0.5))
		player["block"] = maxi(int(player.get("block", 0)), 6)
		_log("Segundo Latido: vuelves con %d PV." % int(player.get("hp", 0)))
	return dealt


func _enemy_turn() -> void:
	phase = Phase.RESOLVING
	# Aliado sombra actúa al inicio del turno enemigo.
	if int(player.get("ally_turns", 0)) > 0:
		var power := int(player.get("ally_power", 0))
		for i in range(enemies.size()):
			if _enemy_alive(i):
				_deal_to_enemy(i, power, false)
		player["block"] = int(player.get("block", 0)) + maxi(2, power / 2)
		_log("Sombra aliada: %d daño y +%d escudo." % [power, maxi(2, power / 2)])
		player["ally_turns"] = int(player.get("ally_turns", 0)) - 1
	for i in range(enemies.size()):
		if not _enemy_alive(i):
			continue
		var e: Dictionary = enemies[i]
		# Quemadura al inicio de su acción
		if int(e.get("burn", 0)) > 0:
			var b := int(e.get("burn", 0))
			_deal_to_enemy(i, b, true)
			e = enemies[i]
			e["burn"] = maxi(0, b - 1)
			enemies[i] = e
			_log("%s sufre %d de quemadura." % [e.get("name", "?"), b])
			e = enemies[i]
		if bool(e.get("stunned", false)):
			_log("%s está aturdido y no actúa." % e.get("name", "?"))
			e["stunned"] = false
			enemies[i] = e
		elif bool(e.get("miss_attack", false)):
			_log("%s falla el ataque (provocado)." % e.get("name", "?"))
			e["miss_attack"] = false
			enemies[i] = e
		else:
			_play_enemy_card(i)
			e = enemies[i]
		# Decay statuses
		e["vulnerable"] = maxi(0, int(e.get("vulnerable", 0)) - 1)
		e["weak"] = maxi(0, int(e.get("weak", 0)) - 1)
		enemies[i] = e
		if int(player.get("hp", 0)) <= 0:
			break

	player["vulnerable"] = maxi(0, int(player.get("vulnerable", 0)) - 1)
	player["weak"] = maxi(0, int(player.get("weak", 0)) - 1)
	player["block"] = 0  # block resets each turn like STS
	# Flags de un solo turno
	player["dodge_turn"] = false
	player["reflect_turn"] = false
	player["free_play"] = false
	player["infinite_draw"] = false
	player["share_damage"] = false
	if int(player.get("fury_turns", 0)) > 0:
		player["fury_turns"] = int(player.get("fury_turns", 0)) - 1
	if int(player.get("lifesteal_turns", 0)) > 0:
		player["lifesteal_turns"] = int(player.get("lifesteal_turns", 0)) - 1
	if int(player.get("transform_turns", 0)) > 0:
		player["transform_turns"] = int(player.get("transform_turns", 0)) - 1
		if int(player.get("transform_turns", 0)) <= 0:
			player["energy_max"] = 3
			_log("El Avatar Carmesí se disipa.")

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


func _build_enemy_pool(e: Dictionary) -> Array:
	if e.has("card_pool") and e.get("card_pool") is Array and not (e.get("card_pool") as Array).is_empty():
		return (e.get("card_pool") as Array).duplicate()
	if bool(e.get("is_boss", false)):
		var bid := str(e.get("boss_id", e.get("id", "")))
		return CardDB.enemy_pool_for_boss(bid)
	return CardDB.enemy_pool_for_role(str(e.get("role", "ataque")))


func _play_enemy_card(index: int) -> void:
	var e: Dictionary = enemies[index]
	var cid := str(e.get("next_card", ""))
	var def := CardDB.get_enemy_card(cid)
	if def.is_empty():
		var dmg := int(e.get("intent_value", 8))
		if int(e.get("weak", 0)) > 0:
			dmg = int(floor(dmg * 0.75))
		var dealt := _deal_to_player(dmg, index)
		_log("%s ataca: %d daño." % [e.get("name", "?"), dealt])
		return
	_resolve_enemy_card(def, index)


func _resolve_enemy_card(def: Dictionary, enemy_index: int) -> void:
	var e: Dictionary = enemies[enemy_index]
	var title := str(def.get("name", "Carta"))
	var kind := CardDB.enemy_card_intent_kind(def)

	if kind == "flee":
		var hp_ratio := float(e.get("hp", 1)) / float(maxi(1, int(e.get("max_hp", 1))))
		if bool(e.get("is_boss", false)):
			var poke := 6 + turn
			var dealt_b := _deal_to_player(poke, enemy_index)
			_log("%s «%s»: %d daño." % [e.get("name", "?"), title, dealt_b])
		elif hp_ratio <= 0.4:
			e["fled"] = true
			e["hp"] = 0
			if not bool(e.get("xp_granted", false)):
				e["xp_granted"] = true
				var flee_xp := maxi(4, _xp_for_enemy(e) / 3)
				var res: Dictionary = GameState.add_combat_xp(flee_xp)
				combat_xp_gained += int(res.get("xp", flee_xp))
				combat_levels_gained += int(res.get("levels", 0))
			_log("%s juega «%s» y huye! (+%d XP)" % [e.get("name", "?"), title, maxi(4, _xp_for_enemy(e) / 3)])
		else:
			var poke2 := 4
			var dealt2 := _deal_to_player(poke2, enemy_index)
			_log("%s intenta «%s» y te roza (%d)." % [e.get("name", "?"), title, dealt2])
		enemies[enemy_index] = e
		return

	var block := int(def.get("block", 0))
	if block > 0:
		e["block"] = int(e.get("block", 0)) + block
		_log("%s «%s»: +%d defensa." % [e.get("name", "?"), title, block])

	var heal := int(def.get("heal", 0))
	if heal > 0:
		e["hp"] = mini(int(e.get("max_hp", e.get("hp", 0))), int(e.get("hp", 0)) + heal)
		_log("%s «%s»: recupera %d PV." % [e.get("name", "?"), title, heal])

	var dmg := int(def.get("damage", 0))
	var hits := maxi(1, int(def.get("hits", 1)))
	if dmg > 0:
		var total := 0
		for _h in range(hits):
			var hit := dmg
			if int(e.get("weak", 0)) > 0:
				hit = int(floor(hit * 0.75))
			total += _deal_to_player(hit, enemy_index)
		_log("%s «%s»: %d daño." % [e.get("name", "?"), title, total])

	var vul := int(def.get("vulnerable", 0))
	if vul > 0 or bool(def.get("vulnerable", false)):
		player["vulnerable"] = int(player.get("vulnerable", 0)) + maxi(1, vul)
		_log("Quedas vulnerable.")

	var weak_n := int(def.get("weaken", 0))
	if weak_n > 0 or bool(def.get("weaken", false)):
		player["weak"] = int(player.get("weak", 0)) + maxi(1, weak_n)
		_log("Quedas debilitado.")

	if int(def.get("stun", 0)) > 0 or bool(def.get("stun", false)):
		player["energy"] = maxi(0, int(player.get("energy", 0)) - 1)
		player["stunned"] = true
		_log("¡Aturdido! (−1 energía).")

	enemies[enemy_index] = e


func _roll_intents() -> void:
	for i in range(enemies.size()):
		if not _enemy_alive(i):
			continue
		_pick_enemy_card(i)


func _pick_enemy_card(index: int) -> void:
	var e: Dictionary = enemies[index]
	var pool: Array = e.get("card_pool", [])
	if pool.is_empty():
		pool = _build_enemy_pool(e)
		e["card_pool"] = pool
	var is_boss := bool(e.get("is_boss", false))
	var hp_ratio := float(e.get("hp", 1)) / float(maxi(1, int(e.get("max_hp", 1))))
	var candidates: Array = []
	for cid in pool:
		var def := CardDB.get_enemy_card(str(cid))
		if def.is_empty():
			continue
		var kind := CardDB.enemy_card_intent_kind(def)
		if kind == "flee":
			if is_boss or hp_ratio > 0.35:
				continue
			for _w in range(3):
				candidates.append(str(cid))
			continue
		if kind in ["block", "heal"] and hp_ratio < 0.45:
			for _w2 in range(2):
				candidates.append(str(cid))
		else:
			candidates.append(str(cid))
		if str(cid).begins_with("boss_") and hp_ratio < 0.55:
			candidates.append(str(cid))
	if candidates.is_empty():
		candidates = ["foe_shot"]
	var pick := str(candidates[randi() % candidates.size()])
	var cdef := CardDB.get_enemy_card(pick)
	e["next_card"] = pick
	e["next_card_name"] = str(cdef.get("name", pick))
	e["next_card_effect"] = CardDB.enemy_effect_line(cdef)
	var kind2 := CardDB.enemy_card_intent_kind(cdef)
	match kind2:
		"flee":
			e["intent"] = Intent.FLEE
			e["intent_value"] = 0
		"block", "heal":
			e["intent"] = Intent.BLOCK
			e["intent_value"] = CardDB.enemy_card_preview_value(cdef)
		_:
			e["intent"] = Intent.ATTACK
			e["intent_value"] = CardDB.enemy_card_preview_value(cdef)
	enemies[index] = e


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
	if victory and combat_xp_gained > 0:
		last_log = "Intervención exitosa. +%d XP." % combat_xp_gained
		if combat_levels_gained > 0:
			last_log += " ¡Subes de nivel!"
	else:
		last_log = "Intervención exitosa." if victory else "La unidad cae. Abortar."
	_log(last_log)
	combat_ended.emit(victory)
	combat_updated.emit()


func intent_label(intent: int) -> String:
	return str(INTENT_LABELS.get(intent, "?"))


func _log(text: String) -> void:
	last_log = text
	log_message.emit(text)
