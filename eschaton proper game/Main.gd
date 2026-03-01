extends Node2D

const SDB = preload("res://SkillDB.gd")
const MainSpawn = preload("res://MainSpawn.gd")
const MainEnemyAI = preload("res://MainEnemyAI.gd")
const MainTelemetry = preload("res://MainTelemetry.gd")

# ============================================================
# ESCHATON — Main Game Engine (Godot 4 Port)
# Sprints 11 & 12: Procedural Map + Adaptive Enemy Composition
# ============================================================

const GRID_SIZE: int = 10
const CELL_SIZE: int = 64
const GRID_PIXEL: int = GRID_SIZE * CELL_SIZE # 640
var grid_offset = Vector2(40, 64)

# Procedural map data (populated by MapGenerator)
var WALLS: Array[Vector2] = []
var HAZARDS: Array[Vector2] = []

# AI Weights (loaded from weights.json)
var weights: Dictionary = {
	"aggression": 1.0,
	"cowardice": 0.0,
	"flanking": 0.5,
	"cover_density": 0.2,
	"hazard_density": 0.1,
	"spawn_rates": {"GRUNT": 0.8, "AEGIS": 0.1, "FROST": 0.1},
}

# Game state
var current_turn: String = "PLAYER" # "PLAYER" or "ENEMY"
var player_loadout: Array = ["MOVE", "THERMAL_LASER", "CRYO_BOMB"]
var selected_skill_idx: int = 0
var glitch_cooldown: int = 0
var game_over: String = "" # "", "Win", or "Loss"
var current_floor: int = 1
var player_coolant_level: int = 0

# Entities
var entities: Array = []
var entity_scene: PackedScene
var audio_manager: Node

# Telemetry
var telemetry: Dictionary = {
	"total_moves": 0,
	"total_attacks": 0,
	"distances_to_enemies": [],
	"glitches_used": 0,
	"thermal_attacks_used": 0,
	"cryo_attacks_used": 0,
	"burn_damage_dealt": 0,
	"turns_enemies_frozen": 0,
}

# Node references
@onready var world_node: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var ui: CanvasLayer = $UI

var vfx: Node2D
var visibility_grid: Array = []
var fog_node: Node2D

# Enemy turn processing
var enemy_turn_active: bool = false

func _ready() -> void:
	print("MAIN _READY OK")
	process_mode = Node.PROCESS_MODE_ALWAYS # Sprint 14: allow processing during pause
	entity_scene = preload("res://Entity.tscn")
	
	var we_scene = preload("res://WorldEnvironment.tscn")
	if we_scene:
		add_child(we_scene.instantiate())
		
	var v_scene = preload("res://VFX.tscn")
	if v_scene:
		vfx = v_scene.instantiate()
		add_child(vfx)
		
	fog_node = Node2D.new()
	fog_node.z_index = 100
	fog_node.draw.connect(_on_fog_draw)
	add_child(fog_node)
	
	# Sprint 15 Debug: camera centering
	if camera:
		camera.position = Vector2(512, 384)
		camera.offset = Vector2.ZERO # Remove old offset from .tscn
		camera.make_current()
	
	audio_manager = load("res://AudioManager.gd").new()
	add_child(audio_manager)
		
	_load_weights()
	_generate_map()
	_spawn_entities()
	
	if ui:
		ui.upgrade_selected.connect(_apply_upgrade)
	
	_update_ui()
	queue_redraw()

# ============================================================
# FOG OF War
# ============================================================

func _on_fog_draw() -> void:
	if visibility_grid.is_empty(): return
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if not visibility_grid[x][y]:
				var rect := Rect2(x * CELL_SIZE + grid_offset.x, y * CELL_SIZE + grid_offset.y, CELL_SIZE, CELL_SIZE)
				fog_node.draw_rect(rect, Color.BLACK)

func update_fog(player_pos: Vector2) -> void:
	var px = int(player_pos.x)
	var py = int(player_pos.y)
	for x in range(px - 1, px + 2):
		for y in range(py - 1, py + 2):
			if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
				visibility_grid[x][y] = true
	if fog_node:
		fog_node.queue_redraw()

# ============================================================
# MAP GENERATION
# ============================================================

func _generate_map() -> void:
	print("[DEBUG] Generating new floor layout...")
	var cover: float = weights.get("cover_density", 0.2)
	var hazard: float = weights.get("hazard_density", 0.1)
	var result: Dictionary = load("res://MapGenerator.gd").generate(cover, hazard)
	WALLS = result["walls"]
	HAZARDS = result["hazards"]
	
	visibility_grid.clear()
	for x in range(GRID_SIZE):
		var col = []
		col.resize(GRID_SIZE)
		col.fill(false)
		visibility_grid.append(col)
		
	_add_log("Map generated: %d walls, %d hazards" % [WALLS.size(), HAZARDS.size()])
	print("[DEBUG] Map generation complete.")
	print("Walls count: ", WALLS.size(), " Hazards count: ", HAZARDS.size())

# ============================================================
# DRAWING
# ============================================================

var _main_draw_printed: bool = false
func _draw() -> void:
	if not _main_draw_printed:
		print("MAIN _DRAW FIRING")
		_main_draw_printed = true

	# Draw grid background
	draw_rect(Rect2(grid_offset.x, grid_offset.y, GRID_PIXEL, GRID_PIXEL), Color.html("#050505"))

	var grid_color = Color(0.0, 0.3, 0.3, 0.3) # Dim Cyan, semi-transparent
	var line_width = 2.0
	var tile_size = 64
	
	# Draw Vertical Lines
	for i in range(11):
		var x = i * tile_size
		draw_line(Vector2(x, 0) + grid_offset, Vector2(x, 640) + grid_offset, grid_color, line_width)
	
	# Draw Horizontal Lines
	for i in range(11):
		var y = i * tile_size
		draw_line(Vector2(0, y) + grid_offset, Vector2(640, y) + grid_offset, grid_color, line_width)

	# Draw hazard tiles (acid pools) — green tint
	for h in HAZARDS:
		var rect := Rect2(h.x * CELL_SIZE + grid_offset.x, h.y * CELL_SIZE + grid_offset.y, CELL_SIZE, CELL_SIZE)
		draw_rect(rect, Color(0.0, 0.8, 0.0, 0.35))

	# Draw walls
	for wall in WALLS:
		var rect := Rect2(wall.x * CELL_SIZE + grid_offset.x, wall.y * CELL_SIZE + grid_offset.y, CELL_SIZE, CELL_SIZE)
		draw_rect(rect, Color(0.2, 0.2, 0.2)) # Dark Grey, no glow

# ============================================================
# LOADING
# ============================================================

func _load_weights() -> void:
	MainTelemetry.load_weights(self)

# ============================================================
# SPAWNING
# ============================================================

func _spawn_entities() -> void:
	MainSpawn.spawn_entities(self)

func _spawn_enemies() -> void:
	MainSpawn.spawn_enemies(self)

func _pick_variant(rates: Dictionary) -> String:
	return MainSpawn.pick_variant(rates)

func _variant_color(v: String) -> Color:
	return MainSpawn.variant_color(v)

func _spawn_entity(p_name: String, p_is_player: bool, p_hp: int, p_max_hp: int, p_ap: int, p_max_ap: int, p_color: Color, p_grid_pos: Vector2, p_variant: String = "GRUNT") -> void:
	MainSpawn.spawn_entity(self, p_name, p_is_player, p_hp, p_max_hp, p_ap, p_max_ap, p_color, p_grid_pos, p_variant)

# ============================================================
# INPUT HANDLING
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if game_over != "":
		return
	if current_turn != "PLAYER":
		return
	if enemy_turn_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			# Skill switching
			KEY_1:
				if player_loadout.size() > 0:
					selected_skill_idx = 0
					var sname: String = SDB.DATA[player_loadout[0]]["name"]
					_add_log("Skill: " + sname.to_upper())
					_update_ui()
			KEY_2:
				if player_loadout.size() > 1:
					selected_skill_idx = 1
					var sname: String = SDB.DATA[player_loadout[1]]["name"]
					_add_log("Skill: " + sname.to_upper())
					_update_ui()
			KEY_3:
				if player_loadout.size() > 2:
					selected_skill_idx = 2
					var sname: String = SDB.DATA[player_loadout[2]]["name"]
					_add_log("Skill: " + sname.to_upper())
					_update_ui()
			# Glitch
			KEY_G:
				_handle_glitch()
			# Movement / Melee mapping to current loadout IF move is selected
			KEY_W, KEY_UP:
				if player_loadout[selected_skill_idx] == "MOVE":
					var p = _get_player()
					if p: _attempt_skill(p.grid_pos.x, p.grid_pos.y - 1)
			KEY_S, KEY_DOWN:
				if player_loadout[selected_skill_idx] == "MOVE":
					var p = _get_player()
					if p: _attempt_skill(p.grid_pos.x, p.grid_pos.y + 1)
			KEY_A, KEY_LEFT:
				if player_loadout[selected_skill_idx] == "MOVE":
					var p = _get_player()
					if p: _attempt_skill(p.grid_pos.x - 1, p.grid_pos.y)
			KEY_D, KEY_RIGHT:
				if player_loadout[selected_skill_idx] == "MOVE":
					var p = _get_player()
					if p: _attempt_skill(p.grid_pos.x + 1, p.grid_pos.y)
			# End turn
			KEY_SPACE:
				_end_player_turn()

	# Mouse click for abstract skill execution
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player_loadout[selected_skill_idx] != "MOVE":
			var mouse_pos: Vector2 = get_global_mouse_position() - grid_offset
			var grid_x: int = int(mouse_pos.x / CELL_SIZE)
			var grid_y: int = int(mouse_pos.y / CELL_SIZE)
			if grid_x >= 0 and grid_x < GRID_SIZE and grid_y >= 0 and grid_y < GRID_SIZE:
				_attempt_skill(grid_x, grid_y)

# ============================================================
# PLAYER ACTIONS
# ============================================================

func _get_player():
	for e in entities:
		if e.is_player and e.hp > 0:
			return e
		
	return null

func _get_enemies() -> Array:
	var result: Array = []
	for e in entities:
		if not e.is_player and e.hp > 0:
			result.append(e)
	return result

func _entity_at(pos: Vector2):
	for e in entities:
		if e.grid_pos == pos and e.hp > 0:
			return e
	return null

func _manhattan(a: Vector2, b: Vector2) -> int:
	return int(abs(a.x - b.x) + abs(a.y - b.y))

func _is_wall(pos: Vector2) -> bool:
	return pos in WALLS

func _is_hazard(pos: Vector2) -> bool:
	return pos in HAZARDS

func _attempt_skill(grid_x: int, grid_y: int) -> void:
	var player = _get_player()
	if player == null: return
	
	if _is_wall(Vector2(grid_x, grid_y)) and player_loadout[selected_skill_idx] == "MOVE":
		return
		
	if not visibility_grid[grid_x][grid_y]:
		_add_log("Unknown Sector")
		_update_ui()
		return
		
	var skill: Dictionary = SDB.DATA[player_loadout[selected_skill_idx]]
	
	if player.ap < skill.get("ap", 1):
		_add_log("Not enough AP for " + skill.get("name", "Skill") + "!")
		_update_ui()
		return
		
	var target_pos := Vector2(grid_x, grid_y)
	var dist: int = _manhattan(player.grid_pos, target_pos)
	if dist > skill.get("range", 1):
		_add_log("Target out of range (Max " + str(skill.get("range", 1)) + ").")
		_update_ui()
		return
		
	# Special MOVE logic overlay
	if skill.get("type", "") == "MOVE":
		var target = _entity_at(target_pos)
		if target != null:
			if not target.is_player:
				target.take_damage(skill.get("damage", 2), "MELEE")
				_add_log("Player attacked " + target.entity_name + " for %d damage." % skill.get("damage", 2))
				telemetry["total_attacks"] += 1
			else: return # clicked self
		else:
			if _is_wall(target_pos): return
			player.move_to_grid(int(target_pos.x), int(target_pos.y))
			telemetry["total_moves"] += 1
			update_fog(target_pos)
			if audio_manager: audio_manager.play_sfx("SFX_Move")
			_add_log("Player moved to (" + str(target_pos.x) + ", " + str(target_pos.y) + ").")
		
		# Pay AP & telemetry distance
		player.ap -= skill.get("ap", 1)
		_record_enemy_distances()
	else:
		# Data-driven capability path
		player.ap -= skill.get("ap", 1)
		_execute_skill_effect(skill, target_pos)
		
	_remove_dead()
	_check_turn_end()
	_check_game_over()
	_update_ui()

func _execute_skill_effect(skill: Dictionary, target_pos: Vector2) -> void:
	var player = _get_player()
	var affected_tiles: Array[Vector2] = []
	
	if skill.has("radius"):
		var r: int = skill.get("radius", 0)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var tile = Vector2(target_pos.x + dx, target_pos.y + dy)
				if tile.x >= 0 and tile.x < GRID_SIZE and tile.y >= 0 and tile.y < GRID_SIZE:
					affected_tiles.append(tile)
	else:
		affected_tiles.append(target_pos)
		
	var tags: Array = skill.get("tags", [])
	
	# Action Tags - positional replacements
	if "SWAP" in tags:
		print("Feature Pending")
	if "TELEPORT_SELF" in tags:
		print("Feature Pending")
		
	# Execute logic across tiles
	var effect_hit = false
	for tile in affected_tiles:
		var target = _entity_at(tile)
		if target != null:
			if skill.has("damage") and not target.is_player:
				target.take_damage(skill.get("damage", 1), skill.get("type", ""))
				effect_hit = true
			if "BURN" in tags and not target.is_player:
				target.apply_status("BURN", 3)
				effect_hit = true
			if "FREEZE" in tags and not target.is_player:
				target.apply_status("FREEZE", 2)
				effect_hit = true
			if "HEAL" in tags and target.is_player:
				player.heal(999)
				_add_log("Player healed to full!")
				
	# Telemetry mapping
	var t_key = str(skill.get("type", "UNKNOWN")).to_lower() + "_attacks_used"
	if not telemetry.has(t_key):
		telemetry[t_key] = 0
	telemetry[t_key] += 1
	
	# VFX
	var s_type = skill.get("type", "")
	if s_type == "THERMAL":
		if audio_manager: audio_manager.play_sfx("SFX_Laser")
		var t_pos_pixel = target_pos * CELL_SIZE + grid_offset + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var p_pos_pixel = player.grid_pos * CELL_SIZE + grid_offset + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		if vfx: vfx.spawn_laser(p_pos_pixel, t_pos_pixel, world_node)
	elif s_type == "CRYO":
		if audio_manager: audio_manager.play_sfx("SFX_Explosion")
		var t_pos_pixel = target_pos * CELL_SIZE + grid_offset + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		if vfx: vfx.spawn_explosion(t_pos_pixel, world_node)
		
	_add_log("Player used " + skill.get("name", "Skill") + "!")

func _record_enemy_distances() -> void:
	var player = _get_player()
	var enemies := _get_enemies()
	if enemies.size() > 0:
		var dist_sum: float = 0.0
		for e in enemies:
			dist_sum += _manhattan(player.grid_pos, e.grid_pos)
		telemetry["distances_to_enemies"].append(dist_sum / enemies.size())

func _handle_glitch() -> void:
	var player = _get_player()
	if player == null:
		return
	if glitch_cooldown > 0:
		_add_log("Glitch on cooldown (" + str(glitch_cooldown) + " turns).")
		_update_ui()
		return
	
	var glitch_skill = SDB.DATA["DESYNC_GLITCH"]
	if player.ap < glitch_skill.get("ap", 0):
		_add_log("Not enough AP for Glitch!")
		_update_ui()
		return

	# Handle teleport
	var valid_tiles: Array[Vector2] = []
	for gx in range(GRID_SIZE):
		for gy in range(GRID_SIZE):
			var pos := Vector2(gx, gy)
			if not _is_wall(pos) and _entity_at(pos) == null:
				valid_tiles.append(pos)
				
	if valid_tiles.size() == 0: return
	var random_tile: Vector2 = valid_tiles[randi() % valid_tiles.size()]
	
	player.move_to_grid(int(random_tile.x), int(random_tile.y))
	update_fog(random_tile)
	
	player.ap -= glitch_skill.get("ap", 0)
	glitch_cooldown = maxi(1, 4 - player_coolant_level)
	telemetry["glitch_attacks_used"] = telemetry.get("glitch_attacks_used", 0) + 1
	_add_log("Player used Desync Glitch!")

	_remove_dead()
	_check_turn_end()
	_check_game_over()
	_update_ui()

func _end_player_turn() -> void:
	if current_turn != "PLAYER" or game_over != "":
		return
	_add_log("Player turn ended.")
	_apply_hazard_damage()
	_reset_enemy_ap()
	current_turn = "ENEMY"
	_update_ui()
	_start_enemy_turn()

func _check_turn_end() -> void:
	var player = _get_player()
	if player and player.ap <= 0:
		_add_log("Player turn ended.")
		_apply_hazard_damage()
		_reset_enemy_ap()
		current_turn = "ENEMY"
		_start_enemy_turn()

func _reset_enemy_ap() -> void:
	for e in entities:
		if not e.is_player and e.hp > 0:
			e.ap = e.max_ap
			e.process_status_effects(telemetry)

func _remove_dead() -> void:
	var to_remove: Array = []
	for e in entities:
		if e.hp <= 0:
			to_remove.append(e)
	for e in to_remove:
		entities.erase(e)
		e.queue_free()

# ============================================================
# HAZARD DAMAGE
# ============================================================

func _apply_hazard_damage() -> void:
	## Check all entities — if standing on a hazard tile, deal 1 damage.
	for e in entities:
		if e.hp > 0 and _is_hazard(e.grid_pos):
			e.take_damage(1, "HAZARD")
			_add_log(e.entity_name + " took 1 acid damage!")
	_remove_dead()
	_check_game_over()

# ============================================================
# GAME OVER
# ============================================================

func _check_game_over() -> void:
	if game_over != "":
		return

	var player = _get_player()
	var enemies := _get_enemies()

	if player == null or player.hp <= 0:
		# Sprint 15: Death is the only game over
		game_over = "Loss"
		_generate_telemetry()
		_run_learning_server()
		ui.show_game_over(game_over)
		_add_log("Game Over: " + game_over)
		_add_log("Telemetry Saved to run_data.json")
		_update_ui()
	elif enemies.size() == 0:
		_add_log("Floor " + str(current_floor) + " Cleared!")
		# Sprint 14: Upgrades every 3 floors
		if current_floor % 3 == 0:
			get_tree().paused = true
			ui.show_upgrade_menu()
		else:
			_generate_next_floor()

var current_upgrades: Array = []

func _apply_upgrade(idx: int) -> void:
	get_tree().paused = false
	ui.hide_upgrade_menu()
	var player = _get_player()
	
	if player:
		if idx == 0: # Heal 50% max HP
			var heal_amount = int(player.max_hp * 0.5)
			player.heal(heal_amount)
			_add_log("UPGRADE: REPAIR (Healed %d HP)" % heal_amount)
		elif idx == 1:
			var old_skill = SDB.DATA[player_loadout[1]]["name"]
			player_loadout[1] = current_upgrades[0]
			var new_skill = SDB.DATA[player_loadout[1]]["name"]
			_add_log("UPGRADE: Replaced " + old_skill + " with " + new_skill)
		elif idx == 2:
			var old_skill = SDB.DATA[player_loadout[2]]["name"]
			player_loadout[2] = current_upgrades[1]
			var new_skill = SDB.DATA[player_loadout[2]]["name"]
			_add_log("UPGRADE: Replaced " + old_skill + " with " + new_skill)
			
	_generate_next_floor()

func get_random_upgrades() -> Array:
	var keys = SDB.DATA.keys()
	var valid_keys = []
	for k in keys:
		if k != "MOVE" and k != "DESYNC_GLITCH":
			valid_keys.append(k)
			
	valid_keys.shuffle()
	
	# Safety check if we add tons of skills
	var options = []
	if valid_keys.size() > 0: options.append(valid_keys[0])
	else: options.append("THERMAL_LASER") # fallback
	if valid_keys.size() > 1: options.append(valid_keys[1])
	else: options.append("CRYO_BOMB") # fallback
	
	current_upgrades = options
	return current_upgrades

func _generate_next_floor() -> void:
	current_floor += 1
	var player = _get_player()
	
	if player:
		# Heal player for 2 HP, maxing out at their max_hp
		player.heal(2)
		# Reset position to start
		player.move_to_grid(5, 9)
		# Reset AP
		player.ap = player.max_ap
	
	_add_log("Descending to Floor " + str(current_floor) + "...")
	_generate_map()
	_spawn_enemies()
	
	if player:
		update_fog(player.grid_pos)
	
	current_turn = "PLAYER"
	_update_ui()
	queue_redraw()

# ============================================================
# ENEMY AI
# ============================================================

func _start_enemy_turn() -> void:
	if enemy_turn_active:
		return
	enemy_turn_active = true
	await _execute_enemy_turn()
	enemy_turn_active = false

func _execute_enemy_turn() -> void:
	await MainEnemyAI.execute_turn(self)

# ============================================================
# TELEMETRY
# ============================================================

func _generate_telemetry() -> void:
	MainTelemetry.generate_telemetry(self)

func _run_learning_server() -> void:
	MainTelemetry.run_learning_server(self)

# ============================================================
# UI UPDATES
# ============================================================

func _update_ui() -> void:
	if not ui:
		return

	ui.update_turn(current_turn)
	ui.update_floor(current_floor)

	var player = _get_player()
	if player:
		ui.update_player_stats(player.hp, player.max_hp, player.ap, player.max_ap)

	ui.update_oracle(weights["aggression"], weights["cowardice"], weights["flanking"])
	ui.update_active_skill(selected_skill_idx, player_loadout)
	ui.update_glitch_cooldown(glitch_cooldown)
	ui.update_entities_panel(entities)

	# Sprint 12: Show spawn rates in Oracle panel
	var sr: Dictionary = weights.get("spawn_rates", {"GRUNT": 0.8, "AEGIS": 0.1, "FROST": 0.1})
	ui.update_spawn_rates(sr.get("GRUNT", 0.8), sr.get("AEGIS", 0.1), sr.get("FROST", 0.1))

func _add_log(msg: String) -> void:
	if ui:
		ui.add_log_entry(msg)
