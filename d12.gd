extends RigidBody3D

@export var ground: StaticBody3D

const R: float = 0.085 # Circumradius matching D6 size
static var VERTICES: Array[Vector3] = []
static var PENTAGONS: Array[Array] = []

static func _static_init() -> void:
	VERTICES.clear()
	PENTAGONS.clear()

	var phi: float = (1.0 + sqrt(5.0)) / 2.0 # Golden ratio ~1.618
	var s: float = R / sqrt(3.0) # Scale factor so max vertex radius = R

	var inv_phi: float = 1.0 / phi

	# 8 Cube Vertices (V0..V7)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				VERTICES.append(Vector3(x, y, z) * s)

	# 4 Vertices on Y-Z plane (V8..V11)
	for y in [-phi, phi]:
		for z in [-inv_phi, inv_phi]:
			VERTICES.append(Vector3(0.0, y, z) * s)

	# 4 Vertices on X-Z plane (V12..V15)
	for x in [-inv_phi, inv_phi]:
		for z in [-phi, phi]:
			VERTICES.append(Vector3(x, 0.0, z) * s)

	# 4 Vertices on X-Y plane (V16..V19)
	for x in [-phi, phi]:
		for y in [-inv_phi, inv_phi]:
			VERTICES.append(Vector3(x, y, 0.0) * s)

	# 12 Pentagonal Face Index Lists (5 vertices per face in 100% CCW exterior perimeter order)
	PENTAGONS = [
		[14, 12, 0, 8, 4],   # Face 0 (Num 1)
		[9, 8, 0, 16, 1],    # Face 1 (Num 12)
		[17, 16, 0, 12, 2],  # Face 2 (Num 2)
		[5, 9, 1, 13, 15],   # Face 3 (Num 11)
		[3, 13, 1, 16, 17],  # Face 4 (Num 3)
		[6, 10, 2, 12, 14],  # Face 5 (Num 10)
		[3, 17, 2, 10, 11],  # Face 6 (Num 4)
		[15, 13, 3, 11, 7],  # Face 7 (Num 9)
		[5, 18, 4, 8, 9],    # Face 8 (Num 5)
		[6, 14, 4, 18, 19],  # Face 9 (Num 8)
		[19, 18, 5, 15, 7],  # Face 10 (Num 6)
		[11, 10, 6, 19, 7]   # Face 11 (Num 7)
	]

func _ready() -> void:
	custom_integrator = false

	if not ground:
		var parent = get_parent()
		if parent:
			ground = parent.get_node_or_null("Enclosure/Ground")

	_build_dodecahedron_mesh_and_collider()

func _build_dodecahedron_mesh_and_collider() -> void:
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
		var tex = load("res://textures/d12_texture.png")
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = Color(0.6, 0.2, 0.8)
		mat.roughness = 0.4
		mat.metallic = 0.0
		mat.metallic_specular = 0.5
		st.set_material(mat)

		# 12 Pentagonal Faces (built from 3 triangles each: 0-1-2, 0-2-3, 0-3-4)
		for p_idx in range(PENTAGONS.size()):
			var gx = p_idx % 4
			var gy = int(floorf(float(p_idx) / 4.0))
			var u0 = float(gx) * 0.25
			var v0 = float(gy) * 0.3333

			var cx = u0 + 0.125
			var cy = v0 + 0.16667
			var rx = 145.0 / 2048.0
			var ry = 145.0 / 1024.0

			var pent_uvs: Array[Vector2] = []
			for i in range(5):
				var angle = deg_to_rad(i * 72.0 - 90.0)
				pent_uvs.append(Vector2(cx + rx * cos(angle), cy + ry * sin(angle)))

			var pent = PENTAGONS[p_idx]
			var v0_pos = VERTICES[pent[0]]
			var v1_pos = VERTICES[pent[1]]
			var v2_pos = VERTICES[pent[2]]
			var v3_pos = VERTICES[pent[3]]
			var v4_pos = VERTICES[pent[4]]

			var face_center = (v0_pos + v1_pos + v2_pos + v3_pos + v4_pos) / 5.0

			var flat_normal = (v1_pos - v0_pos).cross(v2_pos - v0_pos).normalized()
			if flat_normal.dot(face_center) < 0.0:
				flat_normal = -flat_normal

			# Tri 1: (v0, v1, v2)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[0]); st.add_vertex(v0_pos)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[1]); st.add_vertex(v1_pos)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[2]); st.add_vertex(v2_pos)

			# Tri 2: (v0, v2, v3)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[0]); st.add_vertex(v0_pos)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[2]); st.add_vertex(v2_pos)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[3]); st.add_vertex(v3_pos)

			# Tri 3: (v0, v3, v4)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[0]); st.add_vertex(v0_pos)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[3]); st.add_vertex(v3_pos)
			st.set_normal(flat_normal); st.set_uv(pent_uvs[4]); st.add_vertex(v4_pos)

		mesh_inst.mesh = st.commit()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not ground:
		return

	var current_transform = state.transform
	var local_pos = ground.to_local(current_transform.origin)
	var view_size = get_viewport().get_visible_rect().size
	var aspect_ratio = 1.0
	if view_size.x > 0:
		aspect_ratio = view_size.y / view_size.x

	var inset_factor = ground.get("base_inset_factor") if ground and "base_inset_factor" in ground else 1.0
	var half_size = R

	var min_x = -inset_factor + half_size
	var max_x = inset_factor - half_size
	var min_y = 0.0
	var max_y = 2.0 - half_size
	var min_z = -(aspect_ratio * inset_factor) + half_size
	var max_z = (aspect_ratio * inset_factor) - half_size

	var clamped_x = clampf(local_pos.x, min_x, max_x)
	var clamped_y = clampf(local_pos.y, min_y, max_y)
	var clamped_z = clampf(local_pos.z, min_z, max_z)

	if clamped_x != local_pos.x or clamped_y != local_pos.y or clamped_z != local_pos.z:
		var safe_local_pos = Vector3(clamped_x, clamped_y, clamped_z)
		current_transform.origin = ground.to_global(safe_local_pos)
		state.transform = current_transform

		if clamped_x != local_pos.x and signf(state.linear_velocity.x) == signf(local_pos.x):
			state.linear_velocity.x = 0.0
		if clamped_y != local_pos.y and signf(state.linear_velocity.y) == signf(local_pos.y):
			state.linear_velocity.y = 0.0
		if clamped_z != local_pos.z and signf(state.linear_velocity.z) == signf(local_pos.z):
			state.linear_velocity.z = 0.0

	if local_pos.y < -2.0 or local_pos.length() > 10.0:
		var reset_transform = state.transform
		reset_transform.origin = ground.to_global(Vector3(0.0, 0.5, 0.0))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

func get_upward_value() -> Dictionary:
	var up: Vector3 = Vector3.UP
	if ground:
		up = ground.global_transform.basis.y.normalized()

	var d12_vals: Array[int] = [1, 2, 3, 4, 5, 9, 6, 12, 7, 8, 10, 11]
	var best_dot: float = -1.0
	var best_val: int = 1
	var b: Basis = global_transform.basis

	for idx in range(PENTAGONS.size()):
		var pent = PENTAGONS[idx] as Array
		var center: Vector3 = Vector3.ZERO
		for vi in pent:
			center += VERTICES[int(vi)]
		center /= float(pent.size())

		var v0 = VERTICES[int(pent[0])]
		var v1 = VERTICES[int(pent[1])]
		var v2 = VERTICES[int(pent[2])]
		var n = (v1 - v0).cross(v2 - v0).normalized()
		if n.dot(center) < 0:
			n = -n

		var world_n: Vector3 = (b * n).normalized()
		var d: float = world_n.dot(up)
		if d > best_dot:
			best_dot = d
			best_val = d12_vals[idx]

	var is_flat: bool = (best_dot >= 0.96)
	return { "value": best_val, "is_flat": is_flat }
