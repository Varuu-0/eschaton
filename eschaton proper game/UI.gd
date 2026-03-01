extends CanvasLayer
const SDB = preload("res://SkillDB.gd")

signal upgrade_selected(choice: int)

# Node references
@onready var turn_label: Label = $PanelContainer/VBoxContainer/TurnLabel
@onready var player_hp_label: Label = $PanelContainer/VBoxContainer/PlayerHPLabel
@onready var player_ap_label: Label = $PanelContainer/VBoxContainer/PlayerAPLabel
@onready var aggression_bar: ProgressBar = $PanelContainer/VBoxContainer/OracleSection/AggressionBar
@onready var cowardice_bar: ProgressBar = $PanelContainer/VBoxContainer/OracleSection/CowardiceBar
@onready var flanking_bar: ProgressBar = $PanelContainer/VBoxContainer/OracleSection/FlankingBar
@onready var aggression_value: Label = $PanelContainer/VBoxContainer/OracleSection/AggressionValue
@onready var cowardice_value: Label = $PanelContainer/VBoxContainer/OracleSection/CowardiceValue
@onready var flanking_value: Label = $PanelContainer/VBoxContainer/OracleSection/FlankingValue
@onready var skill_move: Label = $PanelContainer/VBoxContainer/AbilitiesSection/SkillMove
@onready var skill_thermal: Label = $PanelContainer/VBoxContainer/AbilitiesSection/SkillThermal
@onready var skill_cryo: Label = $PanelContainer/VBoxContainer/AbilitiesSection/SkillCryo
@onready var skill_glitch: Label = $PanelContainer/VBoxContainer/AbilitiesSection/SkillGlitch
@onready var glitch_cooldown_label: Label = $PanelContainer/VBoxContainer/AbilitiesSection/GlitchCooldownLabel
@onready var action_log: RichTextLabel = $PanelContainer/VBoxContainer/LogSection/ActionLog
@onready var game_over_overlay: Panel = $GameOverOverlay
@onready var game_over_label: Label = $GameOverOverlay/VBoxContainer/GameOverLabel
@onready var game_over_sub: Label = $GameOverOverlay/VBoxContainer/GameOverSub
@onready var restart_button: Button = $GameOverOverlay/VBoxContainer/RestartButton
@onready var entities_container: VBoxContainer = $PanelContainer/VBoxContainer/EntitiesSection/EntitiesContainer

# Sprint 12: Spawn rate labels in Oracle panel
@onready var grunt_rate_label: Label = $PanelContainer/VBoxContainer/OracleSection/GruntRateLabel
@onready var aegis_rate_label: Label = $PanelContainer/VBoxContainer/OracleSection/AegisRateLabel
@onready var frost_rate_label: Label = $PanelContainer/VBoxContainer/OracleSection/FrostRateLabel

# Sprint 14: Armory Upgrades
@onready var upgrade_menu: Panel = $UpgradeMenu
@onready var btn_overclock: Button = $UpgradeMenu/VBoxContainer/BtnOverclock
@onready var btn_armor: Button = $UpgradeMenu/VBoxContainer/BtnArmor
@onready var btn_coolant: Button = $UpgradeMenu/VBoxContainer/BtnCoolant

func _ready() -> void:
	game_over_overlay.visible = false
	upgrade_menu.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	
	btn_overclock.pressed.connect(func(): upgrade_selected.emit(0))
	btn_armor.pressed.connect(func(): upgrade_selected.emit(1))
	btn_coolant.pressed.connect(func(): upgrade_selected.emit(2))

func update_turn(turn: String) -> void:
	turn_label.text = "TURN: " + turn
	if turn == "PLAYER":
		turn_label.add_theme_color_override("font_color", Color(0.231, 0.510, 0.965))
	else:
		turn_label.add_theme_color_override("font_color", Color(0.937, 0.267, 0.267))

func update_floor(floor_num: int) -> void:
	var floor_label = $PanelContainer/VBoxContainer/FloorLabel
	if floor_label:
		floor_label.text = "FLOOR: " + str(floor_num)

func update_player_stats(hp: int, max_hp: int, ap: int, max_ap: int) -> void:
	player_hp_label.text = "HP: " + str(hp) + "/" + str(max_hp)
	player_ap_label.text = "AP: " + str(ap) + "/" + str(max_ap)

func update_oracle(aggression: float, cowardice: float, flanking: float) -> void:
	aggression_bar.value = aggression * 100.0
	cowardice_bar.value = cowardice * 100.0
	flanking_bar.value = flanking * 100.0
	aggression_value.text = "%.1f" % aggression
	cowardice_value.text = "%.1f" % cowardice
	flanking_value.text = "%.1f" % flanking

func update_spawn_rates(grunt: float, aegis: float, frost: float) -> void:
	## Sprint 12: Display enemy spawn rates in the ORACLE panel.
	if grunt_rate_label:
		grunt_rate_label.text = "GRUNT: %d%%" % int(grunt * 100)
	if aegis_rate_label:
		aegis_rate_label.text = "AEGIS: %d%%" % int(aegis * 100)
	if frost_rate_label:
		frost_rate_label.text = "FROST: %d%%" % int(frost * 100)

func update_active_skill(selected_idx: int, loadout: Array) -> void:
	var default_color := Color(0.6, 0.6, 0.6, 1.0)
	var active_color := Color(0.855, 0.647, 0.125, 1.0) # Gold/yellow
	
	skill_move.text = ("1: " + str(SDB.DATA[loadout[0]]["name"])) if loadout.size() > 0 else "1: NONE"
	skill_thermal.text = ("2: " + str(SDB.DATA[loadout[1]]["name"])) if loadout.size() > 1 else "2: NONE"
	skill_cryo.text = ("3: " + str(SDB.DATA[loadout[2]]["name"])) if loadout.size() > 2 else "3: NONE"
	
	skill_move.add_theme_color_override("font_color", active_color if selected_idx == 0 else default_color)
	skill_thermal.add_theme_color_override("font_color", active_color if selected_idx == 1 else default_color)
	skill_cryo.add_theme_color_override("font_color", active_color if selected_idx == 2 else default_color)

func update_glitch_cooldown(cooldown: int) -> void:
	if cooldown > 0:
		glitch_cooldown_label.text = "Cooldown: " + str(cooldown) + " turns"
		glitch_cooldown_label.visible = true
		skill_glitch.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		glitch_cooldown_label.visible = false
		skill_glitch.add_theme_color_override("font_color", Color(0.0, 0.8, 0.85))

func add_log_entry(msg: String) -> void:
	action_log.append_text(msg + "\n")
	# Keep only last 10 lines
	var text := action_log.get_parsed_text()
	var lines := text.split("\n")
	if lines.size() > 11: # account for trailing newline
		action_log.clear()
		var start := lines.size() - 11
		for i in range(start, lines.size()):
			if lines[i] != "":
				action_log.append_text(lines[i] + "\n")

func clear_log() -> void:
	action_log.clear()

func show_game_over(result: String) -> void:
	game_over_overlay.visible = true
	if result == "Win":
		game_over_label.text = "VICTORY"
	else:
		game_over_label.text = "DEFEAT"
	game_over_sub.text = "Telemetry Saved to run_data.json"

func update_entities_panel(entities: Array) -> void:
	# Clear existing children
	for child in entities_container.get_children():
		child.queue_free()

	# Add a panel for each entity
	for entity in entities:
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.15)
		sb.border_color = Color(0.3, 0.3, 0.3)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", sb)

		var vbox := VBoxContainer.new()

		var name_label := Label.new()
		name_label.text = entity.entity_name
		name_label.add_theme_color_override("font_color", entity.entity_color)
		name_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(name_label)

		var stats_label := Label.new()
		var variant_tag: String = ""
		if not entity.is_player and entity.variant != "GRUNT":
			variant_tag = " [" + entity.variant + "]"
		stats_label.text = "HP: " + str(entity.hp) + "/" + str(entity.max_hp) + "  AP: " + str(entity.ap) + "/" + str(entity.max_ap) + variant_tag
		stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		stats_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(stats_label)

		# HP Bar
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(0, 6)
		hp_bar.max_value = entity.max_hp
		hp_bar.value = entity.hp
		hp_bar.show_percentage = false
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.1, 0.1, 0.1)
		bar_bg.set_corner_radius_all(3)
		hp_bar.add_theme_stylebox_override("background", bar_bg)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = entity.entity_color
		bar_fill.set_corner_radius_all(3)
		hp_bar.add_theme_stylebox_override("fill", bar_fill)
		vbox.add_child(hp_bar)

		panel.add_child(vbox)
		entities_container.add_child(panel)

func show_upgrade_menu() -> void:
	var main = get_tree().root.get_node("Main")
	if main and main.has_method("get_random_upgrades"):
		var upgrades = main.get_random_upgrades()
		btn_overclock.text = "KEEP LOADOUT (Heal 50%)"
		
		# Assume size >= 2 based on get_random_upgrades
		var s1 = SDB.DATA.get(upgrades[0], {"name": "Unknown"})
		var s2 = SDB.DATA.get(upgrades[1], {"name": "Unknown"})
		
		btn_armor.text = "REPLACE SLOT 2\n" + str(s1.get("name", "Unknown"))
		btn_coolant.text = "REPLACE SLOT 3\n" + str(s2.get("name", "Unknown"))
		
	upgrade_menu.visible = true

func hide_upgrade_menu() -> void:
	upgrade_menu.visible = false

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
