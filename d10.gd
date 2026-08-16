extends RigidBody3D

@export var ground: StaticBody3D
@export var is_high_10: bool = false

const R: float = 0.085 # Circumradius matching D6 size
static var VERTICES: Array[Vector3] = []
static var KITES: Array[Array] = []

static func _static_init() -> void:
	VERTICES.clear()
	KITES.clear()

	# Proportional D10 Pentagonal Trapezohedron with 100% Planar Coplanar Kite Faces
	# Exact mathematical condition for 100% coplanar flat kite faces: H = Yeq * (1 + cos36) / (1 - cos36)
	var Yeq: float = R * 0.115
	var Req: float = R * 0.85
	var cos36: float = (1.0 + sqrt(5.0)) / 4.0
	var H: float = Yeq * (1.0 + cos36) / (1.0 - cos36)

	# V0: Top Apex, V1: Bottom Apex
	VERTICES.append(Vector3(0.0, H, 0.0))
	VERTICES.append(Vector3(0.0, -H, 0.0))

	# 5 Upper equatorial vertices (V2..V6)
	for i in range(5):
		var angle = deg_to_rad(i * 72.0)
		VERTICES.append(Vector3(cos(angle) * Req, Yeq, sin(angle) * Req))

	# 5 Lower equatorial vertices (V7..V11)
	for i in range(5):
		var angle = deg_to_rad(i * 72.0 + 36.0)
		VERTICES.append(Vector3(cos(angle) * Req, -Yeq, sin(angle) * Req))

	# 5 Top Kites: (V0, Upper_i, Lower_i, Upper_(i+1))
	for i in range(5):
		var u_curr = 2 + i
		var u_next = 2 + ((i + 1) % 5)
		var l_curr = 7 + i
		KITES.append([0, u_curr, l_curr, u_next])

	# 5 Bottom Kites: (V1, Lower_i, Upper_(i+1), Lower_(i+1))
	for i in range(5):
		var l_curr = 7 + i
		var l_next = 7 + ((i + 1) % 5)
		var u_next = 2 + ((i + 1) % 5)
		KITES.append([1, l_curr, u_next, l_next])

func _ready() -> void:
	DiceConfig.apply_to_die(self)
	custom_integrator = false

	if not ground:
		var parent = get_parent()
		if parent:
			ground = parent.get_node_or_null("Enclosure/Ground")

	_build_trapezohedron_mesh_and_collider()

func _build_trapezohedron_mesh_and_collider() -> void:
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
		var tex_path = "res://textures/d10_high_texture.png" if is_high_10 else "res://textures/d10_texture.png"
		var tex = load(tex_path)
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = Color(0.1, 0.7, 0.3)
		mat.roughness = 0.4
		mat.metallic = 0.0
		mat.metallic_specular = 0.5
		st.set_material(mat)
		mesh_inst.material_override = mat

		# 10 Kite Faces
		for k_idx in range(KITES.size()):
			var gx = k_idx % 5
			var gy = int(floorf(float(k_idx) / 5.0))
			var u0 = float(gx) * 0.2
			var u1 = float(gx + 1) * 0.2
			var v0 = float(gy) * 0.5
			var v1 = float(gy + 1) * 0.5

			var uv_top = Vector2(u0 + 0.100, v0 + 0.010)
			var uv_right = Vector2(u1 - 0.018, v0 + 0.398)
			var uv_bot = Vector2(u0 + 0.100, v1 - 0.010)
			var uv_left = Vector2(u0 + 0.018, v0 + 0.398)

			var kite = KITES[k_idx]
			var vA = VERTICES[kite[0]]
			var vB = VERTICES[kite[1]]
			var vC = VERTICES[kite[2]]
			var vD = VERTICES[kite[3]]

			var face_center = (vA + vB + vC + vD) / 4.0

			# Calculate exact 100% planar flat face normal pointing OUTWARDS
			var flat_normal = (vB - vA).cross(vC - vA).normalized()
			if flat_normal.dot(face_center) < 0.0:
				flat_normal = -flat_normal

			# Top kites (0..4) have apex vA at top (V0). Bottom kites (5..9) have apex vA at bottom (V1).
			# 100% Outward CCW Winding Order so CULL_BACK never culls top or bottom faces
			if k_idx < 5:
				# Triangle 1 (CCW Outward): (vA, vB, vC)
				st.set_normal(flat_normal); st.set_uv(uv_top); st.add_vertex(vA)
				st.set_normal(flat_normal); st.set_uv(uv_right); st.add_vertex(vB)
				st.set_normal(flat_normal); st.set_uv(uv_bot); st.add_vertex(vC)

				# Triangle 2 (CCW Outward): (vA, vC, vD)
				st.set_normal(flat_normal); st.set_uv(uv_top); st.add_vertex(vA)
				st.set_normal(flat_normal); st.set_uv(uv_bot); st.add_vertex(vC)
				st.set_normal(flat_normal); st.set_uv(uv_left); st.add_vertex(vD)
			else:
				# Triangle 1 (CCW Outward): (vA, vC, vB)
				st.set_normal(flat_normal); st.set_uv(uv_top); st.add_vertex(vA)
				st.set_normal(flat_normal); st.set_uv(uv_bot); st.add_vertex(vC)
				st.set_normal(flat_normal); st.set_uv(uv_right); st.add_vertex(vB)

				# Triangle 2 (CCW Outward): (vA, vD, vC)
				st.set_normal(flat_normal); st.set_uv(uv_top); st.add_vertex(vA)
				st.set_normal(flat_normal); st.set_uv(uv_left); st.add_vertex(vD)
				st.set_normal(flat_normal); st.set_uv(uv_bot); st.add_vertex(vC)

		mesh_inst.mesh = st.commit()

var current_mode: String = "low_0"

func set_d10_mode(param: Variant) -> void:
	var mode_str: String = "low_0"
	if param is bool:
		is_high_10 = param
		mode_str = "high_10" if param else "low_0"
	elif param is String:
		mode_str = param
		is_high_10 = (param == "high_10")

	current_mode = mode_str

	var tex_path: String = "res://textures/d10_texture.png"
	if mode_str == "high_10":
		tex_path = "res://textures/d10_high_texture.png"
	elif mode_str == "tens":
		tex_path = "res://textures/d10_tens_texture.png"

	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var tex = load(tex_path)
		if tex:
			if not mesh_inst.material_override:
				var mat = StandardMaterial3D.new()
				mat.roughness = 0.4
				mat.metallic = 0.0
				mat.metallic_specular = 0.5
				mat.albedo_color = Color.WHITE
				mesh_inst.material_override = mat
			(mesh_inst.material_override as StandardMaterial3D).albedo_texture = tex

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

	if local_pos.y < -2.0 or local_pos.length() > 10.0:
		var reset_transform = state.transform
		reset_transform.origin = ground.to_global(Vector3(0.0, 0.5, 0.0))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

	# Unstable apex tip correction: ONLY if D10 is stationary but caught balancing high on an apex (local_pos.y > 0.075m), apply a subtle micro-torque to tip onto a flat face
	if local_pos.y > 0.075 and state.linear_velocity.length() < 0.02 and state.angular_velocity.length() < 0.02:
		var nudge_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		if nudge_dir.is_zero_approx():
			nudge_dir = Vector3.RIGHT
		state.apply_torque_impulse(nudge_dir * 0.003)

func get_upward_value() -> Dictionary:
	var up: Vector3 = Vector3.UP
	if ground:
		up = ground.global_transform.basis.y.normalized()

	var face_values: Array[int] = [0, 1, 2, 3, 4, 6, 5, 9, 8, 7]
	if current_mode == "high_10":
		face_values = [1, 2, 3, 4, 5, 7, 6, 10, 9, 8]
	elif current_mode == "tens":
		face_values = [0, 10, 20, 30, 40, 60, 50, 90, 80, 70]

	var best_dot: float = -1.0
	var best_val: int = face_values[0]
	var b: Basis = global_transform.basis

	for k_idx in range(KITES.size()):
		var kite: Array = KITES[k_idx]
		var vA: Vector3 = VERTICES[int(kite[0])]
		var vB: Vector3 = VERTICES[int(kite[1])]
		var vC: Vector3 = VERTICES[int(kite[2])]
		var vD: Vector3 = VERTICES[int(kite[3])]

		var center: Vector3 = (vA + vB + vC + vD) * 0.25
		var n: Vector3 = (vB - vA).cross(vD - vA).normalized()
		if n.dot(center) < 0:
			n = -n

		var world_n: Vector3 = (b * n).normalized()
		var d: float = world_n.dot(up)
		if d > best_dot:
			best_dot = d
			best_val = face_values[k_idx]

	var is_flat: bool = (best_dot >= 0.96)
	return { "value": best_val, "is_flat": is_flat }
