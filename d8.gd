extends BaseDie

const R: float = 0.085 # Circumradius matching D6 size
static var VERTICES: Array[Vector3] = []

# Symmetric face specs: tri is 3D CCW outward; top, bl, br map to exact non-mirrored 2D UV corners
# Opposite face pairs sum to constant 9 (1+8, 2+7, 3+6, 4+5)
static var FACE_SPECS: Array = [
	{ "tri": Vector3i(0, 4, 2), "top": 2, "bl": 4, "br": 0 }, # Face 0 (Num 1: +X, +Y, +Z)
	{ "tri": Vector3i(0, 2, 5), "top": 2, "bl": 0, "br": 5 }, # Face 1 (Num 2: +X, +Y, -Z)
	{ "tri": Vector3i(1, 2, 4), "top": 2, "bl": 1, "br": 4 }, # Face 2 (Num 3: -X, +Y, +Z)
	{ "tri": Vector3i(1, 5, 2), "top": 2, "bl": 5, "br": 1 }, # Face 3 (Num 4: -X, +Y, -Z)
	{ "tri": Vector3i(0, 3, 4), "top": 0, "bl": 4, "br": 3 }, # Face 4 (Num 5: +X, -Y, +Z, opposite Face 3 = 4)
	{ "tri": Vector3i(0, 5, 3), "top": 0, "bl": 3, "br": 5 }, # Face 5 (Num 6: +X, -Y, -Z, opposite Face 2 = 3)
	{ "tri": Vector3i(1, 4, 3), "top": 1, "bl": 3, "br": 4 }, # Face 6 (Num 7: -X, -Y, +Z, opposite Face 1 = 2)
	{ "tri": Vector3i(1, 3, 5), "top": 1, "bl": 5, "br": 3 }  # Face 7 (Num 8: -X, -Y, -Z, opposite Face 0 = 1)
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

func _get_die_half_size() -> float:
	return R

func _build_mesh_and_collider() -> void:
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
			var gy = int(floorf(float(f_idx) / 4.0))
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

func _get_faces() -> Array:
	var faces: Array = []
	var d8_vals: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
	for idx in range(FACE_SPECS.size()):
		var spec = FACE_SPECS[idx]
		var tri = spec["tri"] as Vector3i
		var v0 = VERTICES[tri.x]
		var v1 = VERTICES[tri.y]
		var v2 = VERTICES[tri.z]
		var n = (v1 - v0).cross(v2 - v0).normalized()
		var center = (v0 + v1 + v2) / 3.0
		if n.dot(center) < 0:
			n = -n
		faces.append({ "normal": n, "value": d8_vals[idx] })
	return faces

func get_upward_value() -> Dictionary:
	var res: Dictionary = super.get_upward_value()
	res["is_flat"] = (float(res["dot"]) >= 0.96)
	return res
