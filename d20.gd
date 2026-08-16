extends RigidBody3D

@export var ground: StaticBody3D

const R: float = 0.085 # Circumradius matching polyhedral suite size
static var VERTICES: Array[Vector3] = []
static var FACES: Array[Array] = []

static func _static_init() -> void:
	VERTICES.clear()
	FACES.clear()

	var phi: float = (1.0 + sqrt(5.0)) / 2.0 # Golden Ratio ~1.618034
	var s: float = R / sqrt(phi + 2.0)       # Scale factor so circumradius = R

	# 12 Vertices of Regular Icosahedron
	VERTICES.append(Vector3(-1.0, -phi, 0.0) * s)  # V0
	VERTICES.append(Vector3(-1.0,  phi, 0.0) * s)  # V1
	VERTICES.append(Vector3( 1.0, -phi, 0.0) * s)  # V2
	VERTICES.append(Vector3( 1.0,  phi, 0.0) * s)  # V3
	VERTICES.append(Vector3(0.0, -1.0, -phi) * s)  # V4
	VERTICES.append(Vector3(0.0, -1.0,  phi) * s)  # V5
	VERTICES.append(Vector3(0.0,  1.0, -phi) * s)  # V6
	VERTICES.append(Vector3(0.0,  1.0,  phi) * s)  # V7
	VERTICES.append(Vector3(-phi, 0.0, -1.0) * s)  # V8
	VERTICES.append(Vector3(-phi, 0.0,  1.0) * s)  # V9
	VERTICES.append(Vector3( phi, 0.0, -1.0) * s)  # V10
	VERTICES.append(Vector3( phi, 0.0,  1.0) * s)  # V11

	# 20 Triangular Face Index Loops (100% 3D CCW Outward Winding)
	FACES = [
		[0, 4, 2], [0, 2, 5], [0, 8, 4], [0, 5, 9], [0, 9, 8],
		[1, 3, 6], [1, 7, 3], [1, 6, 8], [1, 9, 7], [1, 8, 9],
		[2, 4, 10], [2, 11, 5], [2, 10, 11], [3, 10, 6], [3, 7, 11],
		[3, 11, 10], [4, 8, 6], [4, 6, 10], [5, 7, 9], [5, 11, 7]
	]

func _ready() -> void:
	DiceConfig.apply_to_die(self)
	custom_integrator = false
	can_sleep = true

	if not ground:
		var parent = get_parent()
		if parent:
			ground = parent.get_node_or_null("Enclosure/Ground")

	_build_icosahedron_mesh_and_collider()

func _build_icosahedron_mesh_and_collider() -> void:
	# 1. Collider
	var col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape:
		var convex = ConvexPolygonShape3D.new()
		convex.points = PackedVector3Array(VERTICES)
		col_shape.shape = convex

	# 2. Mesh & UV Mapping
	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		var mat = StandardMaterial3D.new()
		var tex = load("res://textures/d20_texture.png")
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = Color(0.2, 0.3, 0.8)
		mat.roughness = 0.4
		mat.metallic = 0.0
		mat.metallic_specular = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		st.set_material(mat)
		mesh_inst.material_override = mat

		# 20 Triangular Faces (5x4 grid in atlas)
		for f_idx in range(FACES.size()):
			var gx = f_idx % 5
			var gy = int(floorf(float(f_idx) / 5.0))
			var u0 = float(gx) * 0.20
			var u1 = float(gx + 1) * 0.20
			var v0 = float(gy) * 0.25
			var v1 = float(gy + 1) * 0.25

			var cx = (u0 + u1) * 0.5
			var cy = (v0 + v1) * 0.5
			var rx = (u1 - u0) * 0.42
			var ry = (v1 - v0) * 0.42

			var tri_uvs: Array[Vector2] = []
			for i in range(3):
				var angle = deg_to_rad(i * 120.0 - 90.0)
				tri_uvs.append(Vector2(cx + rx * cos(angle), cy + ry * sin(angle)))

			var tri = FACES[f_idx]
			var v0_pos = VERTICES[tri[0]]
			var v1_pos = VERTICES[tri[1]]
			var v2_pos = VERTICES[tri[2]]

			var face_center = (v0_pos + v1_pos + v2_pos) / 3.0
			var raw_normal = (v1_pos - v0_pos).cross(v2_pos - v0_pos)
			if raw_normal.dot(face_center) < 0.0:
				var tmp_v = v1_pos; v1_pos = v2_pos; v2_pos = tmp_v
				var tmp_uv = tri_uvs[1]; tri_uvs[1] = tri_uvs[2]; tri_uvs[2] = tmp_uv
				raw_normal = -raw_normal

			var flat_normal = raw_normal.normalized()

			# Add 3D CCW Outward Triangle
			st.set_normal(flat_normal); st.set_uv(tri_uvs[0]); st.add_vertex(v0_pos)
			st.set_normal(flat_normal); st.set_uv(tri_uvs[1]); st.add_vertex(v1_pos)
			st.set_normal(flat_normal); st.set_uv(tri_uvs[2]); st.add_vertex(v2_pos)

		mesh_inst.mesh = st.commit()

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

	var inset_factor = ground.get("base_inset_factor") if ground and "base_inset_factor" in ground else 1.0
	var half_size = R

	# X, Y, Z Bounds
	# X Bounds (East/West walls at +/- inset_factor at floor)
	var min_x = -inset_factor + half_size
	var max_x = inset_factor - half_size

	# Y Bounds (Floor at 0.0, Roof at 2.0 - allow physics solver to handle floor contact)
	var min_y = 0.0
	var max_y = 2.0 - half_size

	# Z Bounds (North/South walls at +/- aspect_ratio * inset_factor at floor)
	var min_z = -(aspect_ratio * inset_factor) + half_size
	var max_z = (aspect_ratio * inset_factor) - half_size

	var clamped_x = clampf(local_pos.x, min_x, max_x)
	var clamped_y = clampf(local_pos.y, min_y, max_y)
	var clamped_z = clampf(local_pos.z, min_z, max_z)

	if clamped_x != local_pos.x or clamped_y != local_pos.y or clamped_z != local_pos.z:
		var safe_local_pos = Vector3(clamped_x, clamped_y, clamped_z)
		current_transform.origin = ground.to_global(safe_local_pos)
		state.transform = current_transform
		sleeping = false

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

	# Emergency fallback recovery if die clips far out of arena
	if local_pos.y < -2.0 or local_pos.length() > 10.0:
		var reset_transform = state.transform
		reset_transform.origin = ground.to_global(Vector3(0.0, 0.5, 0.0))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

	# Settlement dampening when near rest on floor so near-spherical D20 settles into sleeping state
	if local_pos.y < 0.12 and state.linear_velocity.length() < 0.08 and state.angular_velocity.length() < 0.08:
		state.linear_velocity = state.linear_velocity.move_toward(Vector3.ZERO, 0.02)
		state.angular_velocity = state.angular_velocity.move_toward(Vector3.ZERO, 0.02)
		if state.linear_velocity.length() < 0.02 and state.angular_velocity.length() < 0.02:
			state.sleeping = true

func get_upward_value() -> Dictionary:
	var up: Vector3 = Vector3.UP
	if ground:
		up = ground.global_transform.basis.y.normalized()

	var d20_vals: Array[int] = [1, 2, 3, 4, 5, 19, 20, 6, 7, 8, 14, 15, 13, 17, 18, 16, 9, 10, 11, 12]
	var best_dot: float = -1.0
	var best_val: int = 1
	var b: Basis = global_transform.basis

	for idx in range(FACES.size()):
		var tri = FACES[idx] as Array
		var v0 = VERTICES[int(tri[0])]
		var v1 = VERTICES[int(tri[1])]
		var v2 = VERTICES[int(tri[2])]
		var center = (v0 + v1 + v2) / 3.0
		var n = (v1 - v0).cross(v2 - v0).normalized()
		if n.dot(center) < 0:
			n = -n

		var world_n: Vector3 = (b * n).normalized()
		var d: float = world_n.dot(up)
		if d > best_dot:
			best_dot = d
			best_val = d20_vals[idx]

	var is_flat: bool = (best_dot >= 0.96)
	return { "value": best_val, "is_flat": is_flat }
