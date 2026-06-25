extends Node3D

@onready var die: RigidBody3D = $Die
# Add the reference to your new Area3D
@onready var gravity_area: Area3D = $Enclosure/GravityArea
@onready var gravity_debugger: MeshInstance3D = $Enclosure/GravityDebugger

@export_group("Physics Settings")
@export var shake_multiplier: float = 4.0
@export var shake_threshold: float = 2.0 
@export var max_keyboard_tilt: float = PI / 4.0

var simulated_gravity: Vector3 = Vector3(0, -9.8, 0)

func _physics_process(delta: float) -> void:
	var target_gravity_dir = Vector3.ZERO

	# 1. Check for Mobile Sensors
	var device_gravity = Input.get_gravity()

	if not device_gravity.is_zero_approx():
		# --- MOBILE MODE ---
		var mapped_gravity = Vector3(
			device_gravity.x,  # Left/Right usually stays on X
			device_gravity.z, # Hardware Z (in/out of screen) becomes Godot's Up/Down
			-device_gravity.y   # Hardware Y (top/bottom of phone) becomes Godot's Forward/Back
		)

		target_gravity_dir = mapped_gravity

		# Calculate continuous physical shake
		var total_accel = Input.get_accelerometer()
		var pure_shake = total_accel - device_gravity

		if pure_shake.length() > shake_threshold:
			var mapped_shake = Vector3(
				pure_shake.x,
				pure_shake.z,
				-pure_shake.y
			)
			die.apply_central_force(mapped_shake * shake_multiplier)

	else:
		# --- DESKTOP TESTING MODE (Arrow Keys) ---
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		if input_dir.is_zero_approx():
			simulated_gravity = simulated_gravity.lerp(Vector3(0, -9.8, 0), 5.0 * delta)
		else:
			var tilt_x = input_dir.x * sin(max_keyboard_tilt) * 9.8
			var tilt_z = input_dir.y * sin(max_keyboard_tilt) * 9.8
			var tilt_y = -cos(max_keyboard_tilt) * 9.8 

			var target_grav = Vector3(tilt_x, tilt_y, tilt_z)
			simulated_gravity = simulated_gravity.lerp(target_grav, 8.0 * delta)

		target_gravity_dir = simulated_gravity

	# 2. Apply the calculated gravity to the Area3D
	# Area3D splits gravity into a normalized direction vector and a scalar magnitude
	if target_gravity_dir.length() > 0.001:
		gravity_area.gravity_direction = target_gravity_dir.normalized()
		gravity_area.gravity = target_gravity_dir.length()

		# --- DRAW THE DEBUG LINE ---
		gravity_debugger.draw_gravity_vector(target_gravity_dir)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:

		# --- RESET DIE (R Key) ---
		if event.physical_keycode == KEY_R:
			_reset_die()
			get_viewport().set_input_as_handled()
			return

		# --- DESKTOP SHAKE JERKS (W, A, S, D) ---
		var jerk_dir = Vector3.ZERO

		if event.physical_keycode == KEY_W: jerk_dir = Vector3(0, 0, -1)
		elif event.physical_keycode == KEY_S: jerk_dir = Vector3(0, 0, 1)
		elif event.physical_keycode == KEY_A: jerk_dir = Vector3(-1, 0, 0)
		elif event.physical_keycode == KEY_D: jerk_dir = Vector3(1, 0, 0)

		if jerk_dir != Vector3.ZERO:
			_apply_randomized_jerk(jerk_dir)
			get_viewport().set_input_as_handled()

func _apply_randomized_jerk(base_direction: Vector3) -> void:
	var random_jerk = base_direction * randf_range(0.8, 1.2) * (shake_multiplier * 0.1)
	random_jerk.y += randf_range(0.3, 0.6) * (shake_multiplier * 0.1)

	die.apply_central_impulse(random_jerk)

	var random_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.05
	die.apply_torque_impulse(random_spin)

func _reset_die() -> void:
	die.global_position = Vector3(0, 1.0, 0)
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
