extends Node3D

@onready var die: RigidBody3D = $Die

# Tweak these to make the die feel heavier or lighter
@export var shake_multiplier: float = 50.0
@export var shake_threshold: float = 2.0 

func _physics_process(delta: float) -> void:
	var device_gravity = Input.get_gravity()
	var total_accel = Input.get_accelerometer()

	# Fallback for desktop testing
	if device_gravity.is_zero_approx():
		device_gravity = Vector3(0, -9.8, 0)
		total_accel = Vector3(0, -9.8, 0)

	# 1. Map Mobile Axes to Godot 3D Space
	# Android/iOS axes often need to be flipped or swapped to match Godot's Z-forward/Y-up.
	# You will likely need to tweak these negative signs based on your specific camera angle.
	var mapped_gravity = Vector3(device_gravity.x, device_gravity.y, device_gravity.z)
	
	# 2. Rotate the entire world's gravity
	# This automatically pulls the die towards the actual physical floor in your room
	var space_rid = get_viewport().find_world_3d().space
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, mapped_gravity.normalized())
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, mapped_gravity.length())

	# 3. Calculate the "Shake" (Pure physical movement)
	var pure_shake = total_accel - device_gravity

	# 4. Apply the shake as a physical force to the die
	if pure_shake.length() > shake_threshold:
		var mapped_shake = Vector3(pure_shake.x, pure_shake.y, pure_shake.z)
		
		# Apply the force over time (delta) so it scales cleanly with the physics frame rate
		die.apply_central_force(mapped_shake * shake_multiplier)
