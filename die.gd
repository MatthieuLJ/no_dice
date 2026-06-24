extends RigidBody3D

# Drag and drop the Ground node here in the inspector, or let it auto-find
@export var ground: AnimatableBody3D

# Half-size of your die (since starting Y is 0.05, half-size is likely 0.05)
@export var half_size: float = 0.04

func _ready() -> void:
	# Fallback auto-detection if not set in the inspector
	if not ground:
		ground = get_node_or_null("../Enclosure/Ground")

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not ground:
		return

	# 1. Get current position from the physics engine state
	var current_transform = state.transform
	var global_pos = current_transform.origin

	# 2. Convert global position to the Ground's local space
	# This handles any rotations/tilting automatically!
	var local_pos = ground.to_local(global_pos)

	# 3. Calculate dynamic boundaries matching Pyramid Scale.gd
	var view_size = get_viewport().get_visible_rect().size
	var aspect_ratio = 1.0
	if view_size.x > 0:
		aspect_ratio = view_size.y / view_size.x

	# X Bounds (East/West walls at -1.0 and 1.0)
	var min_x = -1.0 + half_size
	var max_x = 1.0 - half_size

	# Y Bounds (Floor is at 0.0, Roof is at 1.0)
	var min_y = 0.0 + half_size
	var max_y = 1.0 - half_size

	# Z Bounds (North/South walls scale dynamically based on aspect ratio)
	var min_z = -aspect_ratio + half_size
	var max_z = aspect_ratio - half_size

	# 4. Check if we have slipped outside the boundaries
	var clamped_x = clampf(local_pos.x, min_x, max_x)
	var clamped_y = clampf(local_pos.y, min_y, max_y)
	var clamped_z = clampf(local_pos.z, min_z, max_z)

	if clamped_x != local_pos.x or clamped_y != local_pos.y or clamped_z != local_pos.z:
		if clamped_x != local_pos.x:
			print("clamped x ! ",clamped_x," vs ",local_pos.x)
		elif clamped_y != local_pos.y:
			print("clamped y ! ",clamped_y," vs ",local_pos.y)
		elif clamped_z != local_pos.z:
			print("clamped z ! ",clamped_z," vs ",local_pos.z)
		# We escaped! Teleport back inside safely
		var safe_local_pos = Vector3(clamped_x, clamped_y, clamped_z)
		current_transform.origin = ground.to_global(safe_local_pos)

		# Apply the corrected position to the physics state
		state.transform = current_transform

		# Zero out velocity to prevent clipping loop acceleration
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
