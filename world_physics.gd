extends Node3D

@onready var d6: RigidBody3D = get_node_or_null("D6")
@onready var d4: RigidBody3D = get_node_or_null("D4")
@onready var d8: RigidBody3D = get_node_or_null("D8")
@onready var d10: RigidBody3D = get_node_or_null("D10")
@onready var d12: RigidBody3D = get_node_or_null("D12")
@onready var d20: RigidBody3D = get_node_or_null("D20")
@onready var gravity_area: Area3D = $Enclosure/GravityArea
@onready var gravity_debugger: MeshInstance3D = $Enclosure/GravityDebugger

@export_group("Physics Settings")
@export var shake_multiplier: float = 4.0
@export var shake_threshold: float = 2.0 
@export var max_keyboard_tilt: float = PI / 4.0

var simulated_gravity: Vector3 = Vector3(0, -9.8, 0)
var shake_cooldown: float = 0.0
var dice: Array[RigidBody3D] = []

func _ready() -> void:
	if d6: dice.append(d6)
	if d4: dice.append(d4)
	if d8: dice.append(d8)
	if d10: dice.append(d10)
	if d12: dice.append(d12)
	if d20: dice.append(d20)

	var start_menu = get_node_or_null("StartMenu")
	if start_menu and start_menu.has_signal("menu_dismissed"):
		start_menu.menu_dismissed.connect(_on_start_menu_dismissed)

func _on_start_menu_dismissed(param: Variant) -> void:
	if param is Dictionary:
		set_multi_dice_counts(param)
	elif param is int:
		set_dice_count(param)

func set_multi_dice_counts(counts: Dictionary) -> void:
	# Clear previous extra spawned dice
	for i in range(dice.size() - 1, -1, -1):
		if is_instance_valid(dice[i]):
			var node = dice[i]
			if node != d4 and node != d6 and node != d8 and node != d10 and node != d12 and node != d20:
				node.queue_free()
	dice.clear()

	var dice_map: Dictionary = {
		"d4": d4,
		"d6": d6,
		"d8": d8,
		"d10": d10,
		"d12": d12,
		"d20": d20
	}

	var is_d10_high: bool = (counts.get("d10_mode", "low_0") == "high_10")

	var spawn_idx: int = 0
	for type_key in ["d4", "d6", "d8", "d10", "d12", "d20"]:
		var req_count: int = int(counts.get(type_key, 0))
		var base_die = dice_map.get(type_key) as RigidBody3D
		if not is_instance_valid(base_die):
			continue

		if type_key == "d10" and base_die.has_method("set_d10_mode"):
			base_die.call("set_d10_mode", is_d10_high)

		if req_count > 0:
			base_die.visible = true
			base_die.process_mode = PROCESS_MODE_INHERIT
			dice.append(base_die)
			
			var col_x = (spawn_idx % 5) * 0.12 - 0.24
			var row_z = (spawn_idx / 5) * 0.12 - 0.24
			var spawn_y = 0.15 + (randf() * 0.15)

			base_die.position = Vector3(col_x + randf_range(-0.02, 0.02), spawn_y, row_z + randf_range(-0.02, 0.02))
			base_die.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
			spawn_idx += 1

			for i in range(1, req_count):
				var extra_die = base_die.duplicate() as RigidBody3D
				if type_key == "d10" and extra_die.has_method("set_d10_mode"):
					extra_die.call("set_d10_mode", is_d10_high)
				add_child(extra_die)
				extra_die.visible = true
				
				col_x = (spawn_idx % 5) * 0.12 - 0.24
				row_z = (spawn_idx / 5) * 0.12 - 0.24
				spawn_y = 0.15 + (randf() * 0.15)

				extra_die.position = Vector3(col_x + randf_range(-0.02, 0.02), spawn_y, row_z + randf_range(-0.02, 0.02))
				extra_die.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
				dice.append(extra_die)
				spawn_idx += 1
		else:
			base_die.visible = false
			base_die.process_mode = PROCESS_MODE_DISABLED

func set_dice_count(count: int) -> void:
	count = max(1, count)

	# Remove extra dice
	for i in range(dice.size() - 1, 0, -1):
		if is_instance_valid(dice[i]):
			dice[i].queue_free()
	dice.resize(1)

	# Reset original die position
	_reset_die()

	# Spawn additional dice
	var base_die: RigidBody3D = d6 if d6 else (d10 if d10 else (d8 if d8 else d4))
	if base_die:
		for i in range(1, count):
			var new_die = base_die.duplicate() as RigidBody3D
			add_child(new_die)
			new_die.position = Vector3(
				randf_range(-0.3, 0.3),
				0.1 + (i * 0.12),
				randf_range(-0.3, 0.3)
			)
			new_die.rotation = Vector3(
				randf_range(0, TAU),
				randf_range(0, TAU),
				randf_range(0, TAU)
			)
			dice.append(new_die)

func _physics_process(delta: float) -> void:
	var target_gravity_dir = Vector3.ZERO

	if shake_cooldown > 0.0:
		shake_cooldown -= delta

	# 1. Check for Mobile Sensors
	var device_gravity = Input.get_gravity()

	if not device_gravity.is_zero_approx():
		# --- MOBILE MODE ---
		var mapped_gravity = Vector3(
			device_gravity.x,  # Left/Right usually stays on X
			device_gravity.z, # Hardware Z (in/out of screen) becomes Godot's Up/Down
			-device_gravity.y   # Hardware Y (top/bottom of phone) becomes Godot's Forward/Back
		)

		target_gravity_dir = mapped_gravity

		# Calculate dynamic physical shake with noise filtering and cooldown
		var total_accel = Input.get_accelerometer()
		var pure_shake = total_accel - device_gravity

		if shake_cooldown <= 0.0 and pure_shake.length() > maxf(8.0, shake_threshold):
			shake_cooldown = 0.3 # Cooldown prevents per-frame impulse spam
			var mapped_shake = Vector3(
				pure_shake.x,
				pure_shake.z,
				-pure_shake.y
			)
			for d in dice:
				if is_instance_valid(d):
					d.apply_central_impulse(mapped_shake * (shake_multiplier * 0.05))
					var random_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02
					d.apply_torque_impulse(random_spin)

	else:
		# --- DESKTOP TESTING MODE (Arrow Keys) ---
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		if input_dir.is_zero_approx():
			simulated_gravity = simulated_gravity.lerp(Vector3(0, -9.8, 0), 5.0 * delta)
		else:
			var tilt_x = input_dir.x * sin(max_keyboard_tilt) * 9.8
			var tilt_z = input_dir.y * sin(max_keyboard_tilt) * 9.8
			var tilt_y = -cos(max_keyboard_tilt) * 9.8 

			var target_grav = Vector3(tilt_x, tilt_y, tilt_z)
			simulated_gravity = simulated_gravity.lerp(target_grav, 8.0 * delta)

		target_gravity_dir = simulated_gravity

	# 2. Apply the calculated gravity to the Area3D
	if target_gravity_dir.length() > 0.001:
		gravity_area.gravity_direction = target_gravity_dir.normalized()
		gravity_area.gravity = 9.8
		gravity_debugger.draw_gravity_vector(target_gravity_dir)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:

		# --- RESET DIE (R Key) ---
		if event.physical_keycode == KEY_R:
			_reset_die()
			get_viewport().set_input_as_handled()
			return

		# --- DESKTOP SHAKE JERKS (W, A, S, D or Space) ---
		if event.physical_keycode == KEY_SPACE:
			_apply_strong_random_impulse()
			get_viewport().set_input_as_handled()
			return

		var jerk_dir = Vector3.ZERO

		if event.physical_keycode == KEY_W: jerk_dir = Vector3(0, 0, -1)
		elif event.physical_keycode == KEY_S: jerk_dir = Vector3(0, 0, 1)
		elif event.physical_keycode == KEY_A: jerk_dir = Vector3(-1, 0, 0)
		elif event.physical_keycode == KEY_D: jerk_dir = Vector3(1, 0, 0)

		if jerk_dir != Vector3.ZERO:
			_apply_randomized_jerk(jerk_dir)
			get_viewport().set_input_as_handled()

func _apply_strong_random_impulse() -> void:
	for d in dice:
		if not is_instance_valid(d):
			continue
		var horiz_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		if horiz_dir.is_zero_approx():
			horiz_dir = Vector3.FORWARD

		var impulse = horiz_dir * randf_range(1.5, 3.0) * (shake_multiplier * 0.25)
		impulse.y += randf_range(1.0, 2.5) * (shake_multiplier * 0.25)

		d.apply_central_impulse(impulse)

		var random_spin = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(0.2, 0.5)
		d.apply_torque_impulse(random_spin)

func _apply_randomized_jerk(base_direction: Vector3) -> void:
	for d in dice:
		if not is_instance_valid(d):
			continue
		var random_jerk = base_direction * randf_range(0.8, 1.2) * (shake_multiplier * 0.1)
		random_jerk.y += randf_range(0.3, 0.6) * (shake_multiplier * 0.1)

		d.apply_central_impulse(random_jerk)

		var random_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.05
		d.apply_torque_impulse(random_spin)

func _reset_die() -> void:
	for i in range(dice.size()):
		var d = dice[i]
		if is_instance_valid(d):
			d.global_position = Vector3(randf_range(-0.2, 0.2), 0.5 + (i * 0.12), randf_range(-0.2, 0.2))
			d.linear_velocity = Vector3.ZERO
			d.angular_velocity = Vector3.ZERO
