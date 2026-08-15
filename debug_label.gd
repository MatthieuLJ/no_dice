extends Label

func _process(_delta: float) -> void:
	if not visible:
		return

	var grav = Input.get_gravity()
	var accel = Input.get_accelerometer()

	var all_at_rest: bool = true
	var dice_count: int = 0
	var locked_count: int = 0
	var last_pick: String = "None"

	var tree = get_tree()
	if tree and tree.current_scene:
		if "last_pick_debug_info" in tree.current_scene:
			last_pick = str(tree.current_scene.get("last_pick_debug_info"))

		var dice = tree.current_scene.find_children("", "RigidBody3D", true, false)
		for d in dice:
			var body = d as RigidBody3D
			if body and is_instance_valid(body) and body.visible and body.process_mode != PROCESS_MODE_DISABLED:
				dice_count += 1
				if body.get_meta("is_user_locked", false):
					locked_count += 1
				if not body.sleeping and (body.linear_velocity.length() > 0.03 or body.angular_velocity.length() > 0.03):
					all_at_rest = false

	var rest_str: String = "YES" if (all_at_rest and dice_count > 0) else ("NO" if dice_count > 0 else "N/A")

	text = "At Rest: %s | Locked: %d/%d\nLast Pick: %s\nGrav: %s | Accel: %s" % [rest_str, locked_count, dice_count, last_pick, grav, accel]

