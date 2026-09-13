"""Constantes Niebla Norte."""
TILE = 48
MAP = 64
BLOCK = 8
ROAD_W = 2
WIN = (1280, 720)
MAX_HP = 160.0
DAY_LEN = 160.0
BASE_CAP = 12.0
WALK = 2.2
SPRINT = 3.5
PLAYER_R = 0.28

VOID, ROAD, SIDEWALK, CROSSWALK, PARK, PARKING, ALLEY = range(7)
FLOOR, WALL, DOOR, WATER, RUBBLE, BASE, BARRICADE = range(7, 14)

WALKABLE = {
    ROAD, SIDEWALK, CROSSWALK, PARK, PARKING, ALLEY,
    FLOOR, DOOR, RUBBLE, BASE, BARRICADE,
}

COLORS = {
    VOID: (12, 12, 14), ROAD: (56, 58, 60), SIDEWALK: (90, 92, 86),
    CROSSWALK: (115, 115, 102), PARK: (46, 82, 52), PARKING: (72, 72, 76),
    ALLEY: (52, 52, 46), FLOOR: (82, 72, 62), WALL: (30, 30, 28),
    DOOR: (102, 72, 42), WATER: (30, 72, 98), RUBBLE: (76, 66, 56),
    BASE: (72, 102, 64), BARRICADE: (115, 82, 38),
}

WEAPONS = {
    "bat": {"label": "Bate", "icon": "B", "firearm": False, "dmg": 48, "rng": 1.55, "cd": 0.52, "stam": 11, "w": 2.0},
    "crowbar": {"label": "Palanca", "icon": "P", "firearm": False, "dmg": 40, "rng": 1.45, "cd": 0.45, "stam": 9, "w": 2.0},
    "knife": {"label": "Cuchillo", "icon": "K", "firearm": False, "dmg": 28, "rng": 1.2, "cd": 0.28, "stam": 5, "w": 0.5},
    "pistol": {"label": "Pistola", "icon": "G", "firearm": True, "dmg": 34, "rng": 9.0, "cd": 0.28, "stam": 3, "w": 1.5,
               "ammo": "ammo_9mm", "pellets": 1, "spread": 0.04, "speed": 22.0, "noise": 9.0},
    "shotgun": {"label": "Escopeta", "icon": "S", "firearm": True, "dmg": 22, "rng": 5.5, "cd": 0.85, "stam": 6, "w": 3.0,
                "ammo": "ammo_shot", "pellets": 5, "spread": 0.22, "speed": 18.0, "noise": 14.0},
}
ITEMS = {
    "food": {"label": "Latas", "w": 1.0}, "water": {"label": "Agua", "w": 1.0},
    "scrap": {"label": "Chatarra", "w": 1.0}, "wood": {"label": "Tablas", "w": 1.0},
    "med": {"label": "Botiquin", "w": 1.0, "heal": 55},
    "ammo_9mm": {"label": "9mm", "w": 0.15}, "ammo_shot": {"label": "Cartuchos", "w": 0.2},
    "shirt": {"label": "Camisa", "w": 1.0, "slot": "body", "bite": 0.95, "cap": 0, "color": (90, 102, 115)},
    "hoodie": {"label": "Sudadera", "w": 1.5, "slot": "body", "bite": 0.85, "cap": 1, "color": (64, 90, 140)},
    "jacket": {"label": "Chaqueta", "w": 2.0, "slot": "body", "bite": 0.7, "cap": 2, "color": (90, 72, 56)},
    "vest": {"label": "Chaleco", "w": 3.0, "slot": "body", "bite": 0.55, "cap": 3, "color": (76, 82, 72)},
    "bag": {"label": "Mochila", "w": 1.0, "slot": "bag", "cap": 8},
    "flashlight": {"label": "Linterna", "w": 1.0, "slot": "light"},
}
ITEMS.update(WEAPONS)
CLOTHES = ["vest", "jacket", "hoodie", "shirt"]
BAGS = ["bag"]
LIGHTS = ["flashlight"]
WEAPON_ORDER = ["pistol", "shotgun", "bat", "crowbar", "knife"]
