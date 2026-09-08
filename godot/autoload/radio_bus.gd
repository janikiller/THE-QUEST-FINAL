extends Node
## Bus de radio de la comisaría: mensajes, tono y despachos.

signal radio_message(text: String, kind: String)
signal dispatch_started(mission_id: String, patrol_id: String)
signal dispatch_resolved(mission_id: String, success: bool, report: String)

enum Kind { INFO, DISPATCH, SCENE, RESOLVE, ALERT }

func push(text: String, kind: String = "info") -> void:
	radio_message.emit(text, kind)


func announce_dispatch(patrol_callsign: String, mission_title: String, district: String) -> void:
	push("%s en ruta a «%s» (%s). Cambio." % [patrol_callsign, mission_title, district], "dispatch")


func announce_on_scene(patrol_callsign: String) -> void:
	push("%s en el lugar. Evaluando. Cambio." % patrol_callsign, "scene")


func announce_resolve(patrol_callsign: String, success: bool, detail: String) -> void:
	if success:
		push("%s: %s. Situación controlada. Regresamos. Cambio." % [patrol_callsign, detail], "resolve")
	else:
		push("%s: %s. Pedimos apoyo / reintento. Cambio." % [patrol_callsign, detail], "alert")
