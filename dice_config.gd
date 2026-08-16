class_name DiceConfig
extends RefCounted

const MASS: float = 0.05
const INERTIA: Vector3 = Vector3(0.0001, 0.0001, 0.0001)
const LINEAR_DAMP: float = 0.5
const ANGULAR_DAMP: float = 1.0
const FRICTION: float = 0.2

static func apply_to_die(die: RigidBody3D) -> void:
	if not is_instance_valid(die):
		return
	die.mass = MASS
	die.inertia = INERTIA
	die.linear_damp = LINEAR_DAMP
	die.angular_damp = ANGULAR_DAMP
