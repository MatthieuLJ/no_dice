extends RigidBody3D

@export var ground: StaticBody3D

const R: float = 0.085 # Circumradius matching D6 size
static var VERTICES: Array[Vector3] = []

# Symmetric face specs: tri is 3D CCW outward; top, bl, br map to exact non-mirrored 2D UV corners
static var FACE_SPECS: Array = [
	{ "tri": Vector3i(0, 4, 2), "top": 2, "bl": 4, "br": 0 }, # Face 0 (Num 1: +X, +Y, +Z)
	{ "tri": Vector3i(0, 3, 4), "top": 0, "bl": 4, "br": 3 }, # Face 1 (Num 8: +X, -Y, +Z)
	{ "tri": Vector3i(0, 2, 5), "top": 2, "bl": 0, "br": 5 }, # Face 2 (Num 2: +X, +Y, -Z)
	{ "tri": Vector3i(0, 5, 3), "top": 0, "bl": 3, "br": 5 }, # Face 3 (Num 7: +X, -Y, -Z)
	{ "tri": Vector3i(1, 5, 2), "top": 2, "bl": 5, "br": 1 }, # Face 4 (Num 3: -X, +Y, -Z)
	{ "tri": Vector3i(1, 3, 5), "top": 1, "bl": 5, "br": 3 }, # Face 5 (Num 6: -X, -Y, -Z)
	{ "tri": Vector3i(1, 2, 4), "top": 2, "bl": 1, "br": 4 }, # Face 6 (Num 4: -X, +Y, +Z)
	{ "tri": Vector3i(1, 4, 3), "top": 1, "bl": 3, "br": 4 }  # Face 7 (Num 5: -X, -Y, +Z)
]

static func _static_init() -> void:
	VERTICES.clear()
	var raw_verts = [
		Vector3(R, 0.0, 0.0),  # V0 (+X)
		Vector3(-R, 0.0, 0.0), # V1 (-X)
		Vector3(0.0, R, 0.0),  # V2 (+Y Top Apex)
		Vector3(0.0, -R, 0.0), # V3 (-Y Bottom Apex)
		Vector3(0.0, 0.0, R),  # V4 (+Z Front)
		Vector3(0.0, 0.0, -R)  # V5 (-Z Back)
	]

	# Rotate octahedron so Face 1 rests flat on a horizontal face (bottom normal = 0,-1,0)
	# Normal of unrotated Face 1 is (1, -1, 1) / sqrt(3)
	var face_norm = Vector3(1.0, -1.0, 1.0).normalized()
	var target_norm = Vector3(0.0, -1.0, 0.0)
	var rot_axis = face_norm.cross(target_norm).normalized()
	var rot_angle = face_norm.angle_to(target_norm)
	var rot_basis = Basis(rot_axis, rot_angle)

	for v in raw_verts:
		VERTICES.append(rot_basis * v)

func _ready() -> void:
	inertia = Vector3(0.01, 0.01, 0.01)
	custom_integrator = false

	if not ground:
		var parent = get_parent()
		if parent:
			ground = parent.get_node_or_null("Enclosure/Ground")

	_build_octahedron_mesh_and_collider()

func _build_octahedron_mesh_and_collider() -> void:
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
		var tex = load("res://textures/d8_texture.png")
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = Color(0.1, 0.3, 0.8)
		mat.roughness = 0.4
		st.set_material(mat)

		# 8 Face UVs in 4x2 grid atlas
		for f_idx in range(FACE_SPECS.size()):
			var gx = f_idx % 4
			var gy = f_idx / 4
			var u0 = float(gx) * 0.25
			var u1 = float(gx + 1) * 0.25
			var v0 = float(gy) * 0.5
			var v1 = float(gy + 1) * 0.5

			# Texture UV anchor points for cell (matching 256,40; 40,460; 472,460 in 512x512 cell)
			var cell_uv_top = Vector2(u0 + 0.125, v0 + 0.039)
			var cell_uv_bl = Vector2(u0 + 0.020, v1 - 0.051)
			var cell_uv_br = Vector2(u1 - 0.020, v1 - 0.051)

			var spec = FACE_SPECS[f_idx]
			var tri: Vector3i = spec["tri"]
			var idx_top: int = spec["top"]
			var idx_bl: int = spec["bl"]
			var idx_br: int = spec["br"]

			var vA = VERTICES[tri.x]
			var vB = VERTICES[tri.y]
			var vC = VERTICES[tri.z]

			# Calculate exact flat face normal pointing OUTWARDS for sharp polyhedral edges & bright lighting
			var face_center = (vA + vB + vC) / 3.0
			var flat_normal = (vB - vA).cross(vC - vA).normalized()
			if flat_normal.dot(face_center) < 0.0:
				flat_normal = -flat_normal

			# Map UV anchor to matching vertex index
			var get_uv_for_idx = func(v_idx: int) -> Vector2:
				if v_idx == idx_top: return cell_uv_top
				if v_idx == idx_bl: return cell_uv_bl
				return cell_uv_br

			st.set_normal(flat_normal); st.set_uv(get_uv_for_idx.call(tri.x)); st.add_vertex(vA)
			st.set_normal(flat_normal); st.set_uv(get_uv_for_idx.call(tri.y)); st.add_vertex(vB)
			st.set_normal(flat_normal); st.set_uv(get_uv_for_idx.call(tri.z)); st.add_vertex(vC)

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

		if clamped_x != local_pos.x:
			state.linear_velocity.x = 0.0
		if clamped_y != local_pos.y:
			state.linear_velocity.y = 0.0
		if clamped_z != local_pos.z:
			state.linear_velocity.z = 0.0

	if local_pos.y < -2.0 or local_pos.length() > 10.0:
		var reset_transform = state.transform
		reset_transform.origin = ground.to_global(Vector3(0.0, 0.5, 0.0))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
