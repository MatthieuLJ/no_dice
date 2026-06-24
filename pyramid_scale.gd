extends CSGCombiner3D

func _ready():
	# Connect to viewport resize to update scale automatically
	get_viewport().size_changed.connect(_update_pyramid_scale)
	# Initial call to set scale at startup
	_update_pyramid_scale()

func _update_pyramid_scale():
	var view_size = get_viewport().get_visible_rect().size
	var aspect_ratio = view_size.y / view_size.x
	
	# Apply scale to the X-axis to flatten/widen the pyramid
	self.scale.x = aspect_ratio

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
		# The gravity vector points DOWN in phone space.
		# To tilt the box to match the phone, we align the box's local UP (+Y)
		# with the physical UP direction relative to the screen (-gravity).
		var physical_up = -gravity.normalized()

		# Create a rotation that maps world UP (Vector3.UP) to our physical UP
		target_quat = Quaternion(Vector3.UP, physical_up)

	else:
		# --- DESKTOP KEYBOARD FALLBACK (For testing in editor) ---
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		# Unlimited tilt using keyboard inputs
		var target_euler = Vector3(
			input_dir.y * PI / 2.0, # Tilts forward/backward up to 90 degrees
			0.0,
			-input_dir.x * PI / 2.0 # Tilts left/right up to 90 degrees
		)
		target_quat = Quaternion.from_euler(target_euler)

	# 2. Incorporate Gyroscope for sharp "jerks" / shakes
	var gyro = Input.get_gyroscope()
	if not gyro.is_zero_approx():
		# Create a small instantaneous rotation based on gyro velocity
		var gyro_impulse = Quaternion(gyro * delta * shake_sensitivity)
		target_quat = target_quat * gyro_impulse

	# 3. Smoothly rotate the physical enclosure (Slerp)
	var current_quat = Quaternion(transform.basis)
	var next_quat = current_quat.slerp(target_quat, tilt_speed * delta)

	transform.basis = Basis(next_quat)
