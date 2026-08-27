extends BaseDie

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

func _build_mesh_and_collider() -> void:
	_setup_convex_collider(VERTICES)

	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		var mat = _create_die_material("res://textures/d4_texture.png", Color(0.9, 0.35, 0.15))
		st.set_material(mat)
		mesh_inst.material_override = mat

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
