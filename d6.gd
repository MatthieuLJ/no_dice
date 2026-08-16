extends RigidBody3D

@export var ground: StaticBody3D

func _ready() -> void:
	DiceConfig.apply_to_die(self)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not ground:
		return

	# Calculate dynamic boundaries matching view frustum and pyramid_scale.gd
	var current_transform = state.transform
	var local_pos = ground.to_local(current_transform.origin)
	var view_size = get_viewport().get_visible_rect().size
	var aspect_ratio = 1.0
	if view_size.x > 0:
		aspect_ratio = view_size.y / view_size.x

	# Read base_inset_factor from ground script if available
	var inset_factor = ground.get("base_inset_factor") if ground and "base_inset_factor" in ground else 1.0
	var half_size = 0.05 # Half size of 0.1m die

	# X Bounds (East/West walls at +/- inset_factor at floor)
	var min_x = -inset_factor + half_size
	var max_x = inset_factor - half_size

	# Y Bounds (Floor at 0.0, Roof at 2.0)
	var min_y = 0.0 + half_size
	var max_y = 2.0 - half_size

	# Z Bounds (North/South walls at +/- aspect_ratio * inset_factor at floor)
	var min_z = -(aspect_ratio * inset_factor) + half_size
	var max_z = (aspect_ratio * inset_factor) - half_size

	# Check if slipped outside the camera view boundaries
	var clamped_x = clampf(local_pos.x, min_x, max_x)
	var clamped_y = clampf(local_pos.y, min_y, max_y)
	var clamped_z = clampf(local_pos.z, min_z, max_z)

	if clamped_x != local_pos.x or clamped_y != local_pos.y or clamped_z != local_pos.z:
		var safe_local_pos = Vector3(clamped_x, clamped_y, clamped_z)
		current_transform.origin = ground.to_global(safe_local_pos)
		state.transform = current_transform

		# Zero out velocity on clamped axis only if moving toward boundary to prevent clipping loop acceleration
		if clamped_x != local_pos.x and signf(state.linear_velocity.x) == signf(local_pos.x):
			state.linear_velocity.x = 0.0
		if clamped_y != local_pos.y and signf(state.linear_velocity.y) == signf(local_pos.y):
			state.linear_velocity.y = 0.0
		if clamped_z != local_pos.z and signf(state.linear_velocity.z) == signf(local_pos.z):
			state.linear_velocity.z = 0.0

	# Emergency fallback recovery if the die clips far out of the world
	if local_pos.y < -2.0 or local_pos.length() > 10.0:
		var reset_transform = state.transform
		reset_transform.origin = ground.to_global(Vector3(-0.25, 0.5, 0.1))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

func get_upward_value() -> Dictionary:
	var up: Vector3 = Vector3.UP
	if ground:
		up = ground.global_transform.basis.y.normalized()

	var faces = [
		{ "normal": Vector3(0, 1, 0), "value": 2 },
		{ "normal": Vector3(0, -1, 0), "value": 5 },
		{ "normal": Vector3(1, 0, 0), "value": 3 },
		{ "normal": Vector3(-1, 0, 0), "value": 4 },
		{ "normal": Vector3(0, 0, 1), "value": 1 },
		{ "normal": Vector3(0, 0, -1), "value": 6 }
	]

	var best_dot: float = -1.0
	var best_val: int = 1
	var b: Basis = global_transform.basis

	for f in faces:
		var world_n: Vector3 = (b * f["normal"] as Vector3).normalized()
		var d: float = world_n.dot(up)
		if d > best_dot:
			best_dot = d
			best_val = int(f["value"])

	var is_flat: bool = (best_dot >= 0.96)
	return { "value": best_val, "is_flat": is_flat }
