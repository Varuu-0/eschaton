class_name MainTelemetry
extends RefCounted

static func load_weights(main) -> void:
	var file := FileAccess.open("res://weights.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		if err == OK:
			main.weights = json.data
			main._add_log("Loaded weights.json")
		else:
			main._add_log("Failed to parse weights.json, using defaults")
		file.close()
	else:
		main._add_log("Failed to load weights.json, using defaults")

static func generate_telemetry(main) -> void:
	var avg_dist: float = 0.0
	var dist_arr: Array = main.telemetry["distances_to_enemies"]
	if dist_arr.size() > 0:
		var total: float = 0.0
		for d in dist_arr:
			total += d
		avg_dist = total / dist_arr.size()

	var run_data: Dictionary = {
		"total_moves": main.telemetry["total_moves"],
		"total_attacks": main.telemetry["total_attacks"],
		"glitches_used": main.telemetry.get("glitch_attacks_used", 0) + main.telemetry.get("glitches_used", 0),
		"thermal_attacks_used": main.telemetry.get("thermal_attacks_used", 0),
		"cryo_attacks_used": main.telemetry.get("cryo_attacks_used", 0),
		"burn_damage_dealt": main.telemetry["burn_damage_dealt"],
		"turns_enemies_frozen": main.telemetry["turns_enemies_frozen"],
		"avg_distance_from_enemies": avg_dist,
		"highest_floor_reached": main.current_floor,
		"result": main.game_over,
	}

	var json_string := JSON.stringify(run_data, "  ")
	var file := FileAccess.open("res://run_data.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		var abs_path := ProjectSettings.globalize_path("res://run_data.json")
		print("Telemetry saved to: " + abs_path)
		main._add_log("Saved: " + abs_path)
	else:
		print("ERROR: Could not save telemetry.")
		main._add_log("ERROR: Could not save telemetry.")

static func run_learning_server(main) -> void:
	var script_path := ProjectSettings.globalize_path("res://server_learning.py")
	var output := []
	var exit_code := OS.execute("python", [script_path], output, true)
	for line in output:
		print(line)
		main._add_log(str(line))
	if exit_code == 0:
		main._add_log("AI weights updated successfully.")
		load_weights(main)
		main._update_ui()
	else:
		main._add_log("ERROR: Learning server failed (exit code " + str(exit_code) + ").")
