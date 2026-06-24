extends RigidBody3D

# Threshold to determine if the shake is strong enough
const SHAKE_THRESHOLD = 25.0 

func _process(delta):
	# 1. Check for physical sensor input (Mobile)
	var accel = Input.get_accelerometer()
	if accel.length() > SHAKE_THRESHOLD:
		roll_die()
		
	# 2. Check for debug input (PC)
	# This triggers if you click the left mouse button
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		roll_die()

func roll_die():
	# Apply a random impulse to make the die tumble
	# We use a random vector to ensure it doesn't roll the same way twice
	var random_impulse = Vector3(
		randf_range(-0.1, 0.1),
		randf_range(.2, 0.7),
		randf_range(-0.4, 0.4)
	)
	
	# Apply the force to the center of the die
	apply_central_impulse(random_impulse)
	
	# Optional: Add random torque for extra spin
	apply_torque_impulse(Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5)
	))

func _input(event):
	# Press 'R' to reset the die position
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		global_position = Vector3(0, 0.55, 0)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
