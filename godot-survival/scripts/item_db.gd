extends Node
## Catálogo de objetos.

const WEAPONS := ["pistol", "shotgun", "rifle", "bat", "crowbar", "axe", "hammer", "knife"]
const CLOTHES := ["vest", "raincoat", "jacket", "hoodie", "shirt"]
const BAGS := ["bag_big", "bag"]
const LIGHTS := ["flashlight", "lantern"]

var defs := {}

func _ready() -> void:
	defs = {
		"food": {"label": "Latas", "weight": 1.0, "icon": "🥫"},
		"water": {"label": "Agua", "weight": 1.0, "icon": "💧"},
		"scrap": {"label": "Chatarra", "weight": 1.0, "icon": "🔩"},
		"wood": {"label": "Tablas", "weight": 1.0, "icon": "🪵"},
		"med": {"label": "Botiquín", "weight": 1.0, "icon": "✚", "heal": 55},
		"ammo_9mm": {"label": "9mm", "weight": 0.15, "icon": "🔸"},
		"ammo_shot": {"label": "Cartuchos", "weight": 0.2, "icon": "🔶"},
		"ammo_rifle": {"label": "Munición rifle", "weight": 0.18, "icon": "🟠"},
		"bat": {"label": "Bate", "slot": "hand", "weapon": true, "damage": 48, "range": 1.55, "cd": 0.52, "stamina": 11, "weight": 2.0, "icon": "🏏"},
		"crowbar": {"label": "Palanca", "slot": "hand", "weapon": true, "damage": 40, "range": 1.45, "cd": 0.45, "stamina": 9, "weight": 2.0, "icon": "🔧"},
		"axe": {"label": "Hacha", "slot": "hand", "weapon": true, "damage": 58, "range": 1.5, "cd": 0.62, "stamina": 14, "weight": 2.5, "icon": "🪓"},
		"hammer": {"label": "Martillo", "slot": "hand", "weapon": true, "damage": 36, "range": 1.25, "cd": 0.4, "stamina": 8, "weight": 1.5, "icon": "🔨"},
		"knife": {"label": "Cuchillo", "slot": "hand", "weapon": true, "damage": 28, "range": 1.2, "cd": 0.28, "stamina": 5, "weight": 0.5, "icon": "🔪"},
		"pistol": {"label": "Pistola", "slot": "hand", "weapon": true, "firearm": true, "damage": 34, "range": 9.0, "cd": 0.28, "stamina": 3, "weight": 1.5, "icon": "🔫", "ammo": "ammo_9mm", "pellets": 1, "spread": 0.04, "bullet_speed": 22.0, "noise": 9.0},
		"shotgun": {"label": "Escopeta", "slot": "hand", "weapon": true, "firearm": true, "damage": 22, "range": 5.5, "cd": 0.85, "stamina": 6, "weight": 3.0, "icon": "💥", "ammo": "ammo_shot", "pellets": 5, "spread": 0.22, "bullet_speed": 18.0, "noise": 14.0},
		"rifle": {"label": "Rifle", "slot": "hand", "weapon": true, "firearm": true, "damage": 62, "range": 14.0, "cd": 0.7, "stamina": 5, "weight": 2.5, "icon": "🎯", "ammo": "ammo_rifle", "pellets": 1, "spread": 0.02, "bullet_speed": 28.0, "noise": 12.0},
		"shirt": {"label": "Camisa", "slot": "body", "weight": 1.0, "icon": "👕", "bite_mult": 0.95, "capacity": 0, "color": Color(0.35, 0.4, 0.45)},
		"hoodie": {"label": "Sudadera", "slot": "body", "weight": 1.5, "icon": "🧥", "bite_mult": 0.85, "capacity": 1, "color": Color(0.25, 0.35, 0.55)},
		"jacket": {"label": "Chaqueta", "slot": "body", "weight": 2.0, "icon": "🧥", "bite_mult": 0.7, "capacity": 2, "color": Color(0.35, 0.28, 0.22)},
		"raincoat": {"label": "Impermeable", "slot": "body", "weight": 1.5, "icon": "🧥", "bite_mult": 0.8, "capacity": 1, "color": Color(0.2, 0.45, 0.35)},
		"vest": {"label": "Chaleco", "slot": "body", "weight": 3.0, "icon": "🦺", "bite_mult": 0.55, "capacity": 3, "color": Color(0.3, 0.32, 0.28)},
		"bag": {"label": "Mochila", "slot": "bag", "weight": 1.0, "icon": "🎒", "capacity": 8},
		"bag_big": {"label": "Mochila grande", "slot": "bag", "weight": 2.0, "icon": "🎒", "capacity": 14},
		"flashlight": {"label": "Linterna", "slot": "light", "weight": 1.0, "icon": "🔦", "light_radius": 4.5, "light_color": Color(0.75, 0.85, 1.0)},
		"lantern": {"label": "Farol", "slot": "light", "weight": 1.5, "icon": "🏮", "light_radius": 3.5, "light_color": Color(1.0, 0.75, 0.4)},
	}

func get_def(id: String) -> Dictionary:
	return defs.get(id, {"label": id, "weight": 1.0, "icon": "?"})

func label_of(id: String) -> String:
	return str(get_def(id).get("label", id))
