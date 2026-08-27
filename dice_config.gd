class_name DiceConfig
extends RefCounted

# Mass in kilograms for each polyhedral die type (5g to 10g depending on size/volume)
const DIE_WEIGHTS: Dictionary = {
	"D4": 0.005,   # 5.0 grams
	"D6": 0.006,   # 6.0 grams
	"D8": 0.0065,  # 6.5 grams
	"D10": 0.0075, # 7.5 grams
	"D12": 0.0085, # 8.5 grams
	"D20": 0.010   # 10.0 grams
}

static var LINEAR_DAMP: float = 0.65
static var ANGULAR_DAMP: float = 0.36
static var FRICTION: float = 1.45
static var BOUNCE: float = 0.45
static var LATERAL_ACCEL_GAIN: float = 4.5
static var MASS_MULTIPLIER: float = 1.0
static var INERTIA_MULTIPLIER: float = 1.0
static var TABLE_SPIN_TORQUE: float = 0.05

# Toggle real-time physics tuner HUD overlay (default: false)
const ENABLE_PHYSICS_TUNER: bool = false

# Toggle software position/velocity clamping boundary guards (default: false)
const ENABLE_SOFTWARE_CLAMPING: bool = false

# Toggle real-time telemetry debug label overlay (default: false)
const ENABLE_DEBUG_LABEL: bool = false

# Toggle high-precision sensor & 3D dice trajectory file logging (default: true)
const ENABLE_TELEMETRY_LOGGING: bool = true

static func get_mass_for_die(die: RigidBody3D) -> float:
	if not is_instance_valid(die):
		return 0.007
	var d_name: String = die.name.to_upper()
	if d_name.contains("D4"):
		return 0.005
	elif d_name.contains("D20"):
		return 0.010
	elif d_name.contains("D12"):
		return 0.0085
	elif d_name.contains("D10"):
		return 0.0075
	elif d_name.contains("D8"):
		return 0.0065
	elif d_name.contains("D6"):
		return 0.006
	return 0.007

static func get_scale_for_count(count: int) -> float:
	var clamped_count: int = clampi(count, 1, 30)
	if clamped_count == 30:
		return 1.0
	elif clamped_count == 1:
		return 2.5
	# Linear interpolation from 2.5 at N=1 down to 1.0 at N=30
	return 2.5 - float(clamped_count - 1) * (1.5 / 29.0)

static func apply_to_die(die: RigidBody3D, scale_factor: float = 1.0) -> void:
	if not is_instance_valid(die):
		return

	die.set_meta("die_scale", scale_factor)

	var col_shape = die.get_node_or_null("CollisionShape3D") as Node3D
	if col_shape:
		col_shape.scale = Vector3(scale_factor, scale_factor, scale_factor)

	var mesh_inst = die.get_node_or_null("MeshInstance3D") as Node3D
	if mesh_inst:
		mesh_inst.scale = Vector3(scale_factor, scale_factor, scale_factor)

	var base_m: float = get_mass_for_die(die)
	var m: float = base_m * (1.0 + (scale_factor - 1.0) * 0.75) * MASS_MULTIPLIER
	die.mass = m

	# Scale rotational inertia proportionally with mass and radius squared (scale_factor^2)
	var in_val: float = m * 0.004 * INERTIA_MULTIPLIER * scale_factor * scale_factor
	die.inertia = Vector3(in_val, in_val, in_val)
	die.linear_damp = LINEAR_DAMP
	die.angular_damp = ANGULAR_DAMP
	if die.physics_material_override:
		die.physics_material_override.friction = FRICTION
		die.physics_material_override.bounce = BOUNCE
