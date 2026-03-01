class_name MainSpawn
extends RefCounted

static func spawn_entities(main) -> void:
	# Player — always spawns at bottom-center area
	spawn_entity(main, "Player", true, 10, 10, 3, 3, Color(1.5, 3.0, 5.0), Vector2(5, 9), "GRUNT")
	main.update_fog(Vector2(5, 9))
	spawn_enemies(main)
	var p = main._get_player()
	if p:
		print("Total entities: ", main.entities.size(), " Player spawned at: ", p.grid_pos)

static func spawn_enemies(main) -> void:
	var spawn_rates: Dictionary = main.weights.get("spawn_rates", {"GRUNT": 0.8, "AEGIS": 0.1, "FROST": 0.1})

	var valid_tiles: Array[Vector2] = []
	for x in range(main.GRID_SIZE):
		for y in range(5):
			var pos := Vector2(x, y)
			if not main._is_wall(pos) and not main._is_hazard(pos):
				valid_tiles.append(pos)

	valid_tiles.shuffle()

	var enemy_hp: int = 4 + (main.current_floor - 1)
	var enemy_count: int = mini(4, valid_tiles.size())
	for i in range(enemy_count):
		var v: String = pick_variant(spawn_rates)
		var color: Color = variant_color(v)
		var pos: Vector2 = valid_tiles[i]
		var ename: String = v + " " + str(i + 1)
		spawn_entity(main, ename, false, enemy_hp, enemy_hp, 2, 2, color, pos, v)

static func pick_variant(rates: Dictionary) -> String:
	var grunt_r: float = rates.get("GRUNT", 0.8)
	var aegis_r: float = rates.get("AEGIS", 0.1)
	var roll: float = randf()
	if roll < grunt_r:
		return "GRUNT"
	elif roll < grunt_r + aegis_r:
		return "AEGIS"
	return "FROST"

static func variant_color(v: String) -> Color:
	match v:
		"AEGIS":
			return Color(3.0, 1.8, 0.0)
		"FROST":
			return Color(0.0, 2.55, 2.55)
		_:
			return Color(3.0, 0.5, 0.5)

static func spawn_entity(main, p_name: String, p_is_player: bool, p_hp: int, p_max_hp: int, p_ap: int, p_max_ap: int, p_color: Color, p_grid_pos: Vector2, p_variant: String = "GRUNT") -> void:
	var instance = main.entity_scene.instantiate()
	main.world_node.add_child(instance)
	instance.setup(p_name, p_is_player, p_hp, p_max_hp, p_ap, p_max_ap, p_color, p_grid_pos, p_variant)
	instance.position += main.grid_offset
	main.entities.append(instance)
