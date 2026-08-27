class_name PhysicsTuner
extends CanvasLayer

@onready var panel: PanelContainer = $Control/PanelContainer
@onready var toggle_btn: Button = $Control/ToggleBtn

@onready var friction_slider: HSlider = $Control/PanelContainer/VBox/FrictionRow/Slider
@onready var friction_val: Label = $Control/PanelContainer/VBox/FrictionRow/Value

@onready var linear_damp_slider: HSlider = $Control/PanelContainer/VBox/LinearDampRow/Slider
@onready var linear_damp_val: Label = $Control/PanelContainer/VBox/LinearDampRow/Value

@onready var angular_damp_slider: HSlider = $Control/PanelContainer/VBox/AngularDampRow/Slider
@onready var angular_damp_val: Label = $Control/PanelContainer/VBox/AngularDampRow/Value

@onready var lateral_gain_slider: HSlider = $Control/PanelContainer/VBox/LateralGainRow/Slider
@onready var lateral_gain_val: Label = $Control/PanelContainer/VBox/LateralGainRow/Value

@onready var mass_slider: HSlider = $Control/PanelContainer/VBox/MassRow/Slider
@onready var mass_val: Label = $Control/PanelContainer/VBox/MassRow/Value

@onready var inertia_slider: HSlider = $Control/PanelContainer/VBox/InertiaRow/Slider
@onready var inertia_val: Label = $Control/PanelContainer/VBox/InertiaRow/Value

@onready var spin_slider: HSlider = $Control/PanelContainer/VBox/SpinRow/Slider
@onready var spin_val: Label = $Control/PanelContainer/VBox/SpinRow/Value

@onready var eval_label: Label = $Control/PanelContainer/VBox/EvalLabel

var world_physics: Node3D = null

func _ready() -> void:
	toggle_btn.pressed.connect(_on_toggle_pressed)
	
	friction_slider.value_changed.connect(_on_friction_changed)
	linear_damp_slider.value_changed.connect(_on_linear_damp_changed)
	angular_damp_slider.value_changed.connect(_on_angular_damp_changed)
	lateral_gain_slider.value_changed.connect(_on_lateral_gain_changed)
	mass_slider.value_changed.connect(_on_mass_changed)
	inertia_slider.value_changed.connect(_on_inertia_changed)
	spin_slider.value_changed.connect(_on_spin_changed)

	# Set initial values from current DiceConfig
	friction_slider.value = DiceConfig.FRICTION
	linear_damp_slider.value = DiceConfig.LINEAR_DAMP
	angular_damp_slider.value = DiceConfig.ANGULAR_DAMP
	lateral_gain_slider.value = DiceConfig.LATERAL_ACCEL_GAIN
	mass_slider.value = DiceConfig.MASS_MULTIPLIER
	inertia_slider.value = DiceConfig.INERTIA_MULTIPLIER
	spin_slider.value = DiceConfig.TABLE_SPIN_TORQUE

	_update_labels()

func setup(world: Node3D) -> void:
	world_physics = world

func _on_toggle_pressed() -> void:
	panel.visible = not panel.visible
	toggle_btn.text = "TUNER" if not panel.visible else "HIDE"

func _on_friction_changed(val: float) -> void:
	DiceConfig.FRICTION = val
	friction_val.text = "%.2f" % val
	if is_instance_valid(world_physics) and world_physics.has_method("apply_realtime_friction"):
		world_physics.call("apply_realtime_friction", val)

func _on_linear_damp_changed(val: float) -> void:
	DiceConfig.LINEAR_DAMP = val
	linear_damp_val.text = "%.2f" % val
	if is_instance_valid(world_physics) and world_physics.has_method("apply_realtime_linear_damp"):
		world_physics.call("apply_realtime_linear_damp", val)

func _on_angular_damp_changed(val: float) -> void:
	DiceConfig.ANGULAR_DAMP = val
	angular_damp_val.text = "%.2f" % val
	if is_instance_valid(world_physics) and world_physics.has_method("apply_realtime_angular_damp"):
		world_physics.call("apply_realtime_angular_damp", val)

func _on_lateral_gain_changed(val: float) -> void:
	DiceConfig.LATERAL_ACCEL_GAIN = val
	lateral_gain_val.text = "%.1f" % val

func _on_mass_changed(val: float) -> void:
	DiceConfig.MASS_MULTIPLIER = val
	mass_val.text = "%.1fx" % val
	if is_instance_valid(world_physics) and world_physics.has_method("apply_realtime_mass_multiplier"):
		world_physics.call("apply_realtime_mass_multiplier", val)

func _on_inertia_changed(val: float) -> void:
	DiceConfig.INERTIA_MULTIPLIER = val
	inertia_val.text = "%.1fx" % val
	if is_instance_valid(world_physics) and world_physics.has_method("apply_realtime_inertia_multiplier"):
		world_physics.call("apply_realtime_inertia_multiplier", val)

func _on_spin_changed(val: float) -> void:
	DiceConfig.TABLE_SPIN_TORQUE = val
	spin_val.text = "%.2f" % val

func _update_labels() -> void:
	friction_val.text = "%.2f" % DiceConfig.FRICTION
	linear_damp_val.text = "%.2f" % DiceConfig.LINEAR_DAMP
	angular_damp_val.text = "%.2f" % DiceConfig.ANGULAR_DAMP
	lateral_gain_val.text = "%.1f" % DiceConfig.LATERAL_ACCEL_GAIN
	mass_val.text = "%.1fx" % DiceConfig.MASS_MULTIPLIER
	inertia_val.text = "%.1fx" % DiceConfig.INERTIA_MULTIPLIER
	spin_val.text = "%.2f" % DiceConfig.TABLE_SPIN_TORQUE

func _process(_delta: float) -> void:
	if not panel.visible or not is_instance_valid(world_physics):
		return

	var dice = world_physics.get("dice") as Array
	if not dice:
		return

	var max_v: float = 0.0
	var max_w: float = 0.0

	for d in dice:
		if is_instance_valid(d) and d.visible and not d.sleeping:
			var v = d.linear_velocity.length()
			var w = d.angular_velocity.length()
			if v > max_v:
				max_v = v
			if w > max_w:
				max_w = w

	if max_v < 0.1:
		eval_label.text = "STATE: REST"
		eval_label.modulate = Color(0.7, 0.7, 0.7)
	else:
		var ratio = max_w / max_v
		if ratio < 1.0:
			eval_label.text = "SLIDING (R=%.1f)" % ratio
			eval_label.modulate = Color(1.0, 0.3, 0.3)
		elif ratio > 4.5:
			eval_label.text = "STICKING (R=%.1f)" % ratio
			eval_label.modulate = Color(1.0, 0.9, 0.2)
		else:
			eval_label.text = "ROLLING 3D (R=%.1f)" % ratio
			eval_label.modulate = Color(0.2, 1.0, 0.4)
