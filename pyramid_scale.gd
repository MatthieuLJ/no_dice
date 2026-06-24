
extends AnimatableBody3D

# Reference the wall child nodes
@onready var wall_north: CollisionShape3D = $Wall_North
@onready var wall_south: CollisionShape3D = $Wall_South


func _ready() -> void:
	# Connect to viewport resize to update scale automatically
	get_viewport().size_changed.connect(_update_scale)
	# Initial call to set scale at startup
	_update_scale()

func _update_scale():
	var view_size = get_viewport().get_visible_rect().size
	if view_size.x == 0:
		return

	var aspect_ratio = view_size.y / view_size.x

	# Moving the walls to match the aspect ratio of the display
	wall_north.position = Vector3(0.0, 0.5, -aspect_ratio)
	wall_south.position = Vector3(0.0, 0.5, aspect_ratio)

@export_group("Tilt Settings")
@export var tilt_speed: float = 8.0         # How fast the box interpolates to the target angle
@export var shake_sensitivity: float = 1.5  # How strongly sudden phone jerks tilt the tray

func _physics_process(delta: float) -> void:
	# 1. Get the device's gravity vector (combines gyro + accelerometer)
	var gravity = Input.get_gravity()

	# Fallback to standard accelerometer if gravity sensor is unavailable
	if gravity.is_zero_approx():
		gravity = Input.get_accelerometer()

	var target_quat: Quaternion

	if not gravity.is_zero_approx():
		# Limit gravity components to standard earth gravity (9.8 m/s^2)
		var g_x = clampf(gravity.x, -9.8, 9.8)
		var g_y = clampf(gravity.y, -9.8, 9.8)


		# Map device coordinate tilt to 3D space Euler angles
		var target_pitch = -g_y / 9.8 * (PI / 4.0)
		var target_roll = -g_x / 9.8 * (PI / 4.0)

		target_quat = Quaternion.from_euler(Vector3(target_pitch, 0.0, target_roll))
	else:
		# --- DESKTOP KEYBOARD FALLBACK ---
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var target_euler = Vector3(
			input_dir.y * PI / 3.0,
			0.0,
			-input_dir.x * PI / 3.0
		)
		target_quat = Quaternion.from_euler(target_euler)

	# 2. Incorporate Gyroscope for sharp "jerks" / shakes
	var gyro = Input.get_gyroscope()
	if not gyro.is_zero_approx():
		var gyro_impulse = Quaternion.from_euler(gyro * delta * shake_sensitivity)
		target_quat = target_quat * gyro_impulse

	# 3. Smoothly rotate without scale distortion
	var current_quat = transform.basis.orthonormalized().get_rotation_quaternion()
	var next_quat = current_quat.slerp(target_quat, tilt_speed * delta)

	# Apply rotation cleanly with standard 1.0 scale
	transform.basis = Basis(next_quat)
