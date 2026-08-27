class_name BaseDie
extends RigidBody3D

@export var ground: StaticBody3D

func _ready() -> void:
	DiceConfig.apply_to_die(self, scale.x)
	custom_integrator = false

	if not ground:
		var parent = get_parent()
		if parent:
			ground = parent.get_node_or_null("Enclosure/Ground")

	_build_mesh_and_collider()

func _build_mesh_and_collider() -> void:
	pass

func _setup_convex_collider(vertices: Array[Vector3]) -> void:
	var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape:
		var convex = ConvexPolygonShape3D.new()
		convex.points = PackedVector3Array(vertices)
		col_shape.shape = convex

func _create_die_material(texture_path: String, fallback_color: Color = Color.WHITE) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var tex = load(texture_path)
	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = fallback_color
	mat.roughness = 0.4
	mat.metallic = 0.0
	mat.metallic_specular = 0.5
	return mat

func _get_die_half_size() -> float:
	var s: float = float(get_meta("die_scale", 1.0))
	return 0.085 * s

func _get_faces() -> Array:
	return []

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not ground:
		return

	var current_transform: Transform3D = state.transform
	var local_pos: Vector3 = ground.to_local(current_transform.origin)

	# 1. Optional Software Clamping Guard (Only active if DiceConfig.ENABLE_SOFTWARE_CLAMPING = true)
	if DiceConfig.ENABLE_SOFTWARE_CLAMPING:
		var view_size: Vector2 = get_viewport().get_visible_rect().size
		var aspect_ratio: float = 1.0
		if view_size.x > 0:
			aspect_ratio = view_size.y / view_size.x

		var inset_factor: float = ground.get("base_inset_factor") if ground and "base_inset_factor" in ground else 1.0
		var half_size: float = _get_die_half_size()

		# X Bounds (East/West walls at +/- inset_factor at floor)
		var min_x: float = -inset_factor + half_size
		var max_x: float = inset_factor - half_size

		# Y Bounds (Floor at 0.0, Roof at 2.0 - allow physics solver to handle floor contact)
		var min_y: float = 0.0
		var max_y: float = 2.0 - half_size

		# Z Bounds (North/South walls at +/- aspect_ratio * inset_factor at floor)
		var min_z: float = -(aspect_ratio * inset_factor) + half_size
		var max_z: float = (aspect_ratio * inset_factor) - half_size

		var clamped_x: float = clampf(local_pos.x, min_x, max_x)
		var clamped_y: float = clampf(local_pos.y, min_y, max_y)
		var clamped_z: float = clampf(local_pos.z, min_z, max_z)

		if clamped_x != local_pos.x or clamped_y != local_pos.y or clamped_z != local_pos.z:
			var safe_local_pos: Vector3 = Vector3(clamped_x, clamped_y, clamped_z)
			current_transform.origin = ground.to_global(safe_local_pos)
			state.transform = current_transform

			if local_pos.x <= min_x:
				state.linear_velocity.x = maxf(0.0, state.linear_velocity.x)
			elif local_pos.x >= max_x:
				state.linear_velocity.x = minf(0.0, state.linear_velocity.x)

			if local_pos.y <= min_y:
				state.linear_velocity.y = maxf(0.0, state.linear_velocity.y)
			elif local_pos.y >= max_y:
				state.linear_velocity.y = minf(0.0, state.linear_velocity.y)

			if local_pos.z <= min_z:
				state.linear_velocity.z = maxf(0.0, state.linear_velocity.z)
			elif local_pos.z >= max_z:
				state.linear_velocity.z = minf(0.0, state.linear_velocity.z)

	# 2. Emergency fallback recovery if die clips far out of arena
	if local_pos.y < -2.0 or local_pos.length() > 30.0:
		var reset_transform: Transform3D = state.transform
		reset_transform.origin = ground.to_global(Vector3(-0.25, 0.5, 0.1))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

func get_upward_value() -> Dictionary:
	var up: Vector3 = Vector3.UP
	if ground:
		up = ground.global_transform.basis.y.normalized()

	var best_dot: float = -1.0
	var best_val: int = 1
	var b: Basis = global_transform.basis

	for f in _get_faces():
		var world_n: Vector3 = (b * f["normal"] as Vector3).normalized()
		var d: float = world_n.dot(up)
		if d > best_dot:
			best_dot = d
			best_val = int(f["value"])

	return { "value": best_val, "dot": best_dot }
