extends RigidBody3D

# Drag and drop the Ground node here in the inspector, or let it auto-find
@export var ground: AnimatableBody3D

func _ready() -> void:
	# Fallback auto-detection if not set in the inspector
	if not ground:
		ground = get_node_or_null("../Enclosure/Ground")

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not ground:
		return

	# Emergency fallback recovery if the die clips out of the world
	var local_pos = ground.to_local(state.transform.origin)
	if local_pos.y < -2.0 or local_pos.length() > 10.0:
		var reset_transform = state.transform
		reset_transform.origin = ground.to_global(Vector3(0, 0.5, 0))
		state.transform = reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

