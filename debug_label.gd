extends Label

func _process(_delta: float) -> void:
	if not visible:
		return

	var grav = Input.get_gravity()
	var accel = Input.get_accelerometer()
	var gyro = Input.get_gyroscope()

	var all_at_rest: bool = true
	var dice_count: int = 0
	var tree = get_tree()
	if tree and tree.current_scene:
		var dice = tree.current_scene.find_children("", "RigidBody3D", true, false)
		for d in dice:
			var body = d as RigidBody3D
			if body and is_instance_valid(body) and body.visible and body.process_mode != PROCESS_MODE_DISABLED:
				dice_count += 1
				if not body.sleeping and (body.linear_velocity.length() > 0.03 or body.angular_velocity.length() > 0.03):
					all_at_rest = false

	var rest_str: String = "YES" if (all_at_rest and dice_count > 0) else ("NO" if dice_count > 0 else "N/A")

	text = "Gravity: %s\nAccel: %s\nGyro: %s\nAt Rest: %s" % [grav, accel, gyro, rest_str]
