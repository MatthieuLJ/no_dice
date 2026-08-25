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

const LINEAR_DAMP: float = 0.5
const ANGULAR_DAMP: float = 1.0
const FRICTION: float = 0.05

# Toggle software position/velocity clamping boundary guards (default: false)
const ENABLE_SOFTWARE_CLAMPING: bool = false

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

static func apply_to_die(die: RigidBody3D) -> void:
	if not is_instance_valid(die):
		return
	var m: float = get_mass_for_die(die)
	die.mass = m

	# Scale rotational inertia proportionally with mass (0.00008 for D4 -> 0.00016 for D20)
	var in_val: float = m * 0.016
	die.inertia = Vector3(in_val, in_val, in_val)
	die.linear_damp = LINEAR_DAMP
	die.angular_damp = ANGULAR_DAMP
	if die.physics_material_override:
		die.physics_material_override.friction = FRICTION
