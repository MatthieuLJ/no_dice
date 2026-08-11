@tool
extends RigidBody3D

# Drag and drop the Ground node here in the inspector, or let it auto-find
@export var ground: StaticBody3D

func _ready() -> void:
	# Fallback auto-detection if not set in the inspector
	if not ground:
		ground = get_node_or_null("../Enclosure/Ground")
	_setup_d6_mesh()

func _setup_d6_mesh() -> void:
	var mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_instance:
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var h = 0.05 # half-size for 0.1m die
	var col_w = 1.0 / 3.0
	var row_h = 1.0 / 2.0

	var add_face = func(col: int, row: int, normal: Vector3, tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3):
		var u0 = col * col_w
		var u1 = (col + 1) * col_w
		var v0 = row * row_h
		var v1 = (row + 1) * row_h

		# Triangle 1
		st.set_normal(normal)
		st.set_uv(Vector2(u0, v0)); st.add_vertex(tl)
		st.set_normal(normal)
		st.set_uv(Vector2(u1, v0)); st.add_vertex(tr)
		st.set_normal(normal)
		st.set_uv(Vector2(u1, v1)); st.add_vertex(br)

		# Triangle 2
		st.set_normal(normal)
		st.set_uv(Vector2(u0, v0)); st.add_vertex(tl)
		st.set_normal(normal)
		st.set_uv(Vector2(u1, v1)); st.add_vertex(br)
		st.set_normal(normal)
		st.set_uv(Vector2(u0, v1)); st.add_vertex(bl)

	# 1: Front (+Z)
	add_face.call(0, 0, Vector3(0, 0, 1),   Vector3(-h, h, h),  Vector3(h, h, h),   Vector3(h, -h, h),  Vector3(-h, -h, h))
	# 6: Back (-Z)
	add_face.call(2, 1, Vector3(0, 0, -1),  Vector3(h, h, -h),  Vector3(-h, h, -h), Vector3(-h, -h, -h),Vector3(h, -h, -h))
	# 2: Top (+Y)
	add_face.call(1, 0, Vector3(0, 1, 0),   Vector3(-h, h, -h), Vector3(h, h, -h),  Vector3(h, h, h),   Vector3(-h, h, h))
	# 5: Bottom (-Y)
	add_face.call(1, 1, Vector3(0, -1, 0),  Vector3(-h, -h, h), Vector3(h, -h, h),  Vector3(h, -h, -h), Vector3(-h, -h, -h))
	# 3: Right (+X)
	add_face.call(2, 0, Vector3(1, 0, 0),   Vector3(h, h, h),   Vector3(h, h, -h),  Vector3(h, -h, -h), Vector3(h, -h, h))
	# 4: Left (-X)
	add_face.call(0, 1, Vector3(-1, 0, 0),  Vector3(-h, h, -h), Vector3(-h, h, h),  Vector3(-h, -h, h), Vector3(-h, -h, -h))

	var array_mesh = st.commit()

	var mat = StandardMaterial3D.new()
	var texture_path = "res://textures/d6_texture.png"
	if ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	mat.roughness = 0.85
	mat.metallic = 0.0

	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = mat

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Engine.is_editor_hint():
		return
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

		# Zero out velocity on clamped axis to prevent clipping loop acceleration
		if clamped_x != local_pos.x:
			state.linear_velocity.x = 0.0
		if clamped_y != local_pos.y:
			state.linear_velocity.y = 0.0
		if clamped_z != local_pos.z:
			state.linear_velocity.z = 0.0

	# Emergency fallback recovery if the die clips far out of the world
	if local_pos.y < -2.0 or local_pos.length() > 10.0:
		var reset_transform = state.transform
		reset_transform.origin = ground.to_global(Vector3(0, 0.5, 0))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
