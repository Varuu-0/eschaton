extends Node2D

func spawn_laser(start_pos: Vector2, end_pos: Vector2, parent: Node) -> void:
	var line = Line2D.new()
	line.width = 5.0
	line.default_color = Color(3.0, 1.0, 0.0) # Bright Yellow/Orange
	line.points = PackedVector2Array([start_pos, end_pos])
	# Need a material to glow? No, WorldEnvironment glows Raw colors > 1
	parent.add_child(line)

	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)

func spawn_explosion(pos: Vector2, parent: Node) -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 100.0
	particles.color = Color(0.0, 2.0, 2.0) # Cyan scale to raw values
	particles.amount = 30 # A reasonable amount of particles
	
	# Scale curve: Big to Small
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	
	particles.position = pos
	parent.add_child(particles)
	
	particles.emitting = true
	
	# Auto-destroy after 1.0 second
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
