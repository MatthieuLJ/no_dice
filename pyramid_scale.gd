extends Node3D

# Store the target scale so it isn't lost during rotation calculations
var target_scale: Vector3 = Vector3.ONE

@export_group("Tilt Settings")
@export var tilt_speed: float = 8.0         # How fast the box interpolates to the target angle
@export var shake_sensitivity: float = 1.5  # How strongly sudden phone jerks tilt the tray

func _ready():
	# Connect to viewport resize to update scale automatically
	get_viewport().size_changed.connect(_update_scale)
	# Initial call to set scale at startup
	_update_scale()

func _update_scale():
	var view_size = get_viewport().get_visible_rect().size
	# Prevent division by zero if view_size is not fully initialized
	if view_size.x == 0:
		return

	var aspect_ratio = view_size.y / view_size.x
	
	# Keep X and Y at default, apply aspect ratio scale to Z
	target_scale = Vector3(1.0, 1.0, aspect_ratio)

	# Apply scale immediately
	transform.basis = transform.basis.orthonormalized().scaled(target_scale)
	print("Current Aspect Ratio: ", aspect_ratio, " | Target Scale: ", target_scale)

func _physics_process(delta: float) -> void:
	# 1. Get the device's gravity vector (combines gyro + accelerometer)
	var gravity = Input.get_gravity()

	# Fallback to standard accelerometer if gravity sensor is unavailable
	if gravity.is_zero_approx():
		gravity = Input.get_accelerometer()

	var target_quat: Quaternion

	if not gravity.is_zero_approx():
		var physical_up = -gravity.normalized()
		target_quat = Quaternion(Vector3.UP, physical_up)
	else:
		# --- DESKTOP KEYBOARD FALLBACK ---
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var target_euler = Vector3(
			input_dir.y * PI / 2.0,
			0.0,
			-input_dir.x * PI / 2.0
		)
		target_quat = Quaternion.from_euler(target_euler)

	# 2. Incorporate Gyroscope for sharp "jerks" / shakes
	var gyro = Input.get_gyroscope()
	if not gyro.is_zero_approx():
		var gyro_impulse = Quaternion(gyro * delta * shake_sensitivity)
		target_quat = target_quat * gyro_impulse

	# 3. Smoothly rotate and apply the preserved scale
	# We use get_rotation_quaternion() to bypass scale distorting the rotation query
	var current_quat = transform.basis.get_rotation_quaternion()
	var next_quat = current_quat.slerp(target_quat, tilt_speed * delta)

	# Build a clean rotation basis and apply our target scale to it
	transform.basis = Basis(next_quat).scaled(target_scale)
