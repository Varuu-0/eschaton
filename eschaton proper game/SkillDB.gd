extends RefCounted
class_name SkillDB

const DATA: Dictionary = {
	"MOVE": {
		"name": "Move / Melee",
		"type": "MOVE",
		"ap": 1,
		"range": 1,
		"damage": 2, # Note: Moving into an enemy deals 2 melee damage.
		"tags": []
	},
	"THERMAL_LASER": {
		"name": "Thermal Laser",
		"type": "THERMAL",
		"ap": 1,
		"range": 4,
		"damage": 2,
		"tags": ["BURN"]
	},
	"CRYO_BOMB": {
		"name": "Cryo Bomb",
		"type": "CRYO",
		"ap": 2,
		"range": 3,
		"damage": 1,
		"radius": 1,
		"tags": ["FREEZE"]
	},
	"DESYNC_GLITCH": {
		"name": "Desync Glitch",
		"type": "GLITCH",
		"ap": 0,
		"range": 99,
		"tags": ["TELEPORT_RANDOM_EMPTY"]
	}
}
