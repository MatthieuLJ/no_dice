extends Node3D

@onready var die: RigidBody3D = $Die

@export_group("Physics Settings")
@export var shake_multiplier: float = 50.0
@export var shake_threshold: float = 2.0 
@export var max_keyboard_tilt: float = PI / 4.0 # 45 degrees max tilt for arrow keys

# Used to smoothly interpolate keyboard tilt
var simulated_gravity: Vector3 = Vector3(0, -9.8, 0)

func _physics_process(delta: float) -> void:
	var target_gravity_dir = Vector3.ZERO

	# 1. Check for Mobile Sensors
	var device_gravity = Input.get_gravity()

	if not device_gravity.is_zero_approx():
		# --- MOBILE MODE ---
		target_gravity_dir = device_gravity

		# Calculate continuous physical shake
		var total_accel = Input.get_accelerometer()
		var pure_shake = total_accel - device_gravity

		if pure_shake.length() > shake_threshold:
			# Apply physical shake directly as a force
			die.apply_central_force(pure_shake * shake_multiplier)

	else:
		# --- DESKTOP TESTING MODE (Arrow Keys) ---
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		if input_dir.is_zero_approx():
			# Slowly return gravity to straight down when keys are released
			simulated_gravity = simulated_gravity.lerp(Vector3(0, -9.8, 0), 5.0 * delta)
		else:
			# Map arrow keys to a gravity vector
			# Pressing right pulls gravity +X (simulating tilting the tray right)
			var tilt_x = input_dir.x * sin(max_keyboard_tilt) * 9.8
			var tilt_z = input_dir.y * sin(max_keyboard_tilt) * 9.8
			var tilt_y = -cos(max_keyboard_tilt) * 9.8 

			var target_grav = Vector3(tilt_x, tilt_y, tilt_z)
			simulated_gravity = simulated_gravity.lerp(target_grav, 8.0 * delta)

		target_gravity_dir = simulated_gravity

	# 2. Apply the calculated gravity to the entire 3D Space
	var space_rid = get_viewport().find_world_3d().space
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, target_gravity_dir.normalized())
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, target_gravity_dir.length())


func _unhandled_input(event: InputEvent) -> void:
	# Only trigger on key down, ignore holding the key
	if event is InputEventKey and event.pressed and not event.echo:

		# --- RESET DIE (R Key) ---
		if event.physical_keycode == KEY_R:
			_reset_die()
			get_viewport().set_input_as_handled()
			return

		# --- DESKTOP SHAKE JERKS (W, A, S, D) ---
		var jerk_dir = Vector3.ZERO

		if event.physical_keycode == KEY_W: jerk_dir = Vector3(0, 0, -1)   # Push Forward
		elif event.physical_keycode == KEY_S: jerk_dir = Vector3(0, 0, 1)  # Push Backward
		elif event.physical_keycode == KEY_A: jerk_dir = Vector3(-1, 0, 0) # Push Left
		elif event.physical_keycode == KEY_D: jerk_dir = Vector3(1, 0, 0)  # Push Right

		if jerk_dir != Vector3.ZERO:
			_apply_randomized_jerk(jerk_dir)
			get_viewport().set_input_as_handled()

func _apply_randomized_jerk(base_direction: Vector3) -> void:
	# 1. Add slight randomness to the user's directional input
	var random_jerk = base_direction * randf_range(0.8, 1.2) * (shake_multiplier * 0.1)

	# 2. Add an upward "pop" so the die leaves the floor
	random_jerk.y += randf_range(0.3, 0.6) * (shake_multiplier * 0.1)

	# 3. Apply the impulse
	die.apply_central_impulse(random_jerk)

	# 4. Apply a random torque so the die spins wildly in the air
	var random_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.05
	die.apply_torque_impulse(random_spin)

func _reset_die() -> void:
	# Drop the die exactly in the center, slightly above the floor
	die.global_position = Vector3(0, 1.0, 0)

	# Kill all existing momentum
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO

	print("Resetting die")
