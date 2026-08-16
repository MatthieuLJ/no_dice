extends RigidBody3D

@export var ground: StaticBody3D

const R: float = 0.085 # Circumradius matching D6 size
static var VERTICES: Array[Vector3] = [
	Vector3(0.0, R, 0.0),                                         # V0 (Apex)
	Vector3(R * (2.0 * sqrt(2.0) / 3.0), -R / 3.0, 0.0),         # V1
	Vector3(-R * (sqrt(2.0) / 3.0), -R / 3.0, R * sqrt(2.0/3.0)), # V2
	Vector3(-R * (sqrt(2.0) / 3.0), -R / 3.0, -R * sqrt(2.0/3.0)) # V3
]

static var TRIANGLES: Array[Vector3i] = [
	Vector3i(1, 3, 2), # Base (bottom face opposite V0)
	Vector3i(0, 2, 3), # Face opposite V1
	Vector3i(0, 3, 1), # Face opposite V2
	Vector3i(0, 1, 2)  # Face opposite V3
]

func _ready() -> void:
	DiceConfig.apply_to_die(self)
	custom_integrator = false

	if not ground:
		var parent = get_parent()
		if parent:
			ground = parent.get_node_or_null("Enclosure/Ground")

	_build_tetrahedron_mesh_and_collider()

func _build_tetrahedron_mesh_and_collider() -> void:
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
		var tex = load("res://textures/d4_texture.png")
		if tex:
			mat.albedo_texture = tex
		else:
			mat.albedo_color = Color(0.9, 0.35, 0.15)
		mat.roughness = 0.85
		st.set_material(mat)

		# Face UV coordinates for 2x2 atlas (Top, Bottom-Left, Bottom-Right)
		var face_uvs = [
			# Face 0 (Grid 0,0)
			[Vector2(0.25, 0.0586), Vector2(0.0586, 0.4297), Vector2(0.4414, 0.4297)],
			# Face 1 (Grid 1,0)
			[Vector2(0.75, 0.0586), Vector2(0.5586, 0.4297), Vector2(0.9414, 0.4297)],
			# Face 2 (Grid 0,1)
			[Vector2(0.25, 0.5586), Vector2(0.0586, 0.9297), Vector2(0.4414, 0.9297)],
			# Face 3 (Grid 1,1)
			[Vector2(0.75, 0.5586), Vector2(0.5586, 0.9297), Vector2(0.9414, 0.9297)]
		]

		for f_idx in range(TRIANGLES.size()):
			var tri = TRIANGLES[f_idx]
			var uvs = face_uvs[f_idx]

			var vA = VERTICES[tri.x]
			var vB = VERTICES[tri.y]
			var vC = VERTICES[tri.z]
			var normal = (vB - vA).cross(vC - vA).normalized()
			var face_center = (vA + vB + vC) / 3.0
			if normal.dot(face_center) < 0.0:
				normal = -normal

			st.set_normal(normal)
			st.set_uv(uvs[0])
			st.add_vertex(vA)

			st.set_normal(normal)
			st.set_uv(uvs[1])
			st.add_vertex(vB)

			st.set_normal(normal)
			st.set_uv(uvs[2])
			st.add_vertex(vC)

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
	var min_y = 0.0 # Allow physics engine to resolve ground contact naturally without position jitter
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

	# Emergency fallback recovery if die clips far out of arena
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

	var best_dot: float = -1.0
	var best_idx: int = 0
	var b: Basis = global_transform.basis

	for i in range(VERTICES.size()):
		var world_v: Vector3 = (b * VERTICES[i]).normalized()
		var d: float = world_v.dot(up)
		if d > best_dot:
			best_dot = d
			best_idx = i

	var val: int = [4, 1, 2, 3][best_idx]
	var is_flat: bool = (best_dot >= 0.96)
	return { "value": val, "is_flat": is_flat }
