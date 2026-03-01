class_name MainEnemyAI
extends RefCounted

static func execute_turn(main) -> void:
	if main.game_over != "":
		return

	var player = main._get_player()
	if player == null:
		return

	var processing := true
	while processing:
		await main.get_tree().create_timer(0.3).timeout

		if main.game_over != "":
			break

		player = main._get_player()
		if player == null:
			break

		var active_enemy = null
		for e in main.entities:
			if not e.is_player and e.hp > 0 and e.ap > 0:
				active_enemy = e
				break

		if active_enemy == null:
			main._add_log("Enemy turn ended.")
			main._apply_hazard_damage()
			main.current_turn = "PLAYER"
			player = main._get_player()
			if player:
				player.ap = player.max_ap
				player.process_status_effects(main.telemetry)
			main.glitch_cooldown = maxi(0, main.glitch_cooldown - 1)
			main._update_ui()
			processing = false
			break

		var dist_to_player := main._manhattan(active_enemy.grid_pos, player.grid_pos)
		if dist_to_player == 1:
			player.take_damage(1, "MELEE")
			active_enemy.ap -= 1
			main._add_log(active_enemy.entity_name + " attacked Player for 1 damage.")
			main._remove_dead()
			main._check_game_over()
			main._update_ui()
			continue

		var dirs: Array[Vector2] = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
		var best_score: float = -INF
		var best_pos: Vector2 = active_enemy.grid_pos

		var other_enemies: Array = []
		for e in main.entities:
			if not e.is_player and e.hp > 0 and e != active_enemy:
				other_enemies.append(e)

		var aggression_val: float = main.weights.get("aggression", 0.5)

		for d in dirs:
			var nx: int = int(active_enemy.grid_pos.x + d.x)
			var ny: int = int(active_enemy.grid_pos.y + d.y)

			if nx < 0 or nx >= main.GRID_SIZE or ny < 0 or ny >= main.GRID_SIZE:
				continue
			if main._entity_at(Vector2(nx, ny)) != null:
				continue
			if main._is_wall(Vector2(nx, ny)):
				continue

			var d_player: float = main._manhattan(Vector2(nx, ny), player.grid_pos)
			var d_player_inv: float = 20.0 - d_player

			var d_other_enemies: float = 0.0
			for oe in other_enemies:
				d_other_enemies += main._manhattan(Vector2(nx, ny), oe.grid_pos)

			var score: float = (main.weights["aggression"] * d_player_inv) + (main.weights["cowardice"] * d_player) + (main.weights["flanking"] * d_other_enemies)

			if main._is_hazard(Vector2(nx, ny)):
				if aggression_val > 0.8:
					score -= 1.0
				else:
					score -= 5.0

			if score > best_score:
				best_score = score
				best_pos = Vector2(nx, ny)

		if best_score != -INF:
			active_enemy.move_to_grid(int(best_pos.x), int(best_pos.y))
			active_enemy.ap -= 1
			if main.audio_manager:
				main.audio_manager.play_sfx("SFX_Move")
			main._add_log(active_enemy.entity_name + " moved to (" + str(int(best_pos.x)) + ", " + str(int(best_pos.y)) + ").")
		else:
			active_enemy.ap = 0
			main._add_log(active_enemy.entity_name + " is stuck.")

		main._update_ui()
