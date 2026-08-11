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
		dice_count = dice.size()
		for d in dice:
			var body = d as RigidBody3D
			if body and is_instance_valid(body):
				if not body.sleeping and (body.linear_velocity.length() > 0.01 or body.angular_velocity.length() > 0.01):
					all_at_rest = false
					break

	var rest_str: String = "YES" if (all_at_rest and dice_count > 0) else ("NO" if dice_count > 0 else "N/A")

	text = "Gravity: %s\nAccel: %s\nGyro: %s\nAt Rest: %s" % [grav, accel, gyro, rest_str]
