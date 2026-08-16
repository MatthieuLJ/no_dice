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
@export var shake_multiplier: float = 6.0
@export var shake_threshold: float = 2.5
@export var max_keyboard_tilt: float = PI / 4.0
@export var at_rest_delay: float = 1.0

var simulated_gravity: Vector3 = Vector3(0, -9.8, 0)
var shake_cooldown: float = 0.0
var roll_grace_timer: float = 0.0
var at_rest_settle_timer: float = 0.0
var dice: Array[RigidBody3D] = []
var has_shown_result_for_current_roll: bool = false
var has_left_rest: bool = false
var halo_material: StandardMaterial3D = null
var last_pick_debug_info: String = "None"

var dragging_die: RigidBody3D = null
var drag_start_pos: Vector2 = Vector2.ZERO
var is_drag_active: bool = false
var drag_threshold: float = 8.0

@onready var result_screen: CanvasLayer = get_node_or_null("ResultScreen")

func _get_halo_material() -> StandardMaterial3D:
	if not halo_material:
		halo_material = StandardMaterial3D.new()
		halo_material.cull_mode = BaseMaterial3D.CULL_FRONT
		halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_material.albedo_color = Color(1.0, 0.85, 0.0, 1.0)
		halo_material.grow = true
		halo_material.grow_amount = 0.008
	return halo_material

func _toggle_die_user_lock(die: RigidBody3D) -> void:
	var is_locked: bool = bool(die.get_meta("is_user_locked", false))
	if is_locked:
		_set_die_user_lock(die, false)
	else:
		var is_at_rest: bool = die.sleeping or (die.linear_velocity.length() <= 0.03 and die.angular_velocity.length() <= 0.03)
		if is_at_rest:
			_set_die_user_lock(die, true)
		else:
			print("[DICE LOCK DEBUG] Cannot lock %s: die is currently moving!" % die.name)
			last_pick_debug_info = "Cannot Lock: %s moving" % die.name

func _set_die_user_lock(die: RigidBody3D, locked: bool) -> void:
	die.set_meta("is_user_locked", locked)
	die.freeze = locked
	if locked:
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO

	var mesh_inst = die.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		mesh_inst.material_overlay = _get_halo_material() if locked else null

	print("[DICE LOCK DEBUG] Set lock on %s -> %s" % [die.name, locked])

func _clear_all_user_locks() -> void:
	for d in dice:
		if is_instance_valid(d):
			_set_die_user_lock(d, false)

func _slide_die_to_position(die: RigidBody3D, target_3d: Vector3) -> void:
	var pos_y = maxf(0.05, die.position.y)
	var clamped_x = clampf(target_3d.x, -0.75, 0.75)
	var clamped_z = clampf(target_3d.z, -0.75, 0.75)
	var target_pos = Vector3(clamped_x, pos_y, clamped_z)

	# Ensure dragged die does NOT overlap or pass through locked dice
	for other in dice:
		if is_instance_valid(other) and other != die:
			if bool(other.get_meta("is_user_locked", false)) or other.freeze:
				var diff = target_pos - other.position
				diff.y = 0.0
				var min_dist = 0.11 # minimum spacing between 0.1m die centers
				if diff.length() < min_dist:
					if diff.is_zero_approx():
						diff = Vector3(0.01, 0.0, 0.01)
					target_pos = other.position + diff.normalized() * min_dist
					target_pos.y = pos_y

	die.global_position = target_pos
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO

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

	if result_screen:
		if result_screen.has_signal("roll_again_requested"):
			result_screen.connect("roll_again_requested", _on_roll_again_requested)
		if result_screen.has_signal("lock_flat_and_reroll_requested"):
			result_screen.connect("lock_flat_and_reroll_requested", _on_lock_flat_and_reroll_requested)
		if result_screen.has_signal("main_menu_requested"):
			result_screen.connect("main_menu_requested", _on_main_menu_requested)

func _on_start_menu_dismissed(param: Variant) -> void:
	if result_screen and result_screen.has_method("hide_result"):
		result_screen.hide_result()
	_clear_all_user_locks()
	_unlock_world()
	has_shown_result_for_current_roll = false
	has_left_rest = true
	roll_grace_timer = 0.6
	at_rest_settle_timer = 0.0
	if param is Dictionary:
		set_multi_dice_counts(param)
	elif param is int:
		set_dice_count(param)
	_apply_strong_random_impulse()

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

	var d10_mode_str: String = counts.get("d10_mode", "low_0")
	var d100_count: int = int(counts.get("d100", 0))

	# Hide template base dice by default
	for base in [d4, d6, d8, d10, d12, d20]:
		if is_instance_valid(base):
			base.visible = false
			base.process_mode = PROCESS_MODE_DISABLED

	var spawn_idx: int = 0

	# Spawn standard dice (D4, D6, D8, D10, D12, D20)
	for type_key in ["d4", "d6", "d8", "d10", "d12", "d20"]:
		var req_count: int = int(counts.get(type_key, 0))
		var base_die = dice_map.get(type_key) as RigidBody3D
		if not is_instance_valid(base_die):
			continue

		for i in range(req_count):
			var mode_param: String = d10_mode_str if type_key == "d10" else ""
			_spawn_die_instance(base_die, mode_param, spawn_idx)
			spawn_idx += 1

	# Spawn D100 dice (pair of D10 Tens + D10 Low 0)
	if d100_count > 0 and is_instance_valid(d10):
		for i in range(d100_count):
			# 1. D10 Tens die (00..90)
			_spawn_die_instance(d10, "tens", spawn_idx)
			spawn_idx += 1

			# 2. D10 Units die (0..9)
			_spawn_die_instance(d10, "low_0", spawn_idx)
			spawn_idx += 1

func _spawn_die_instance(base_die: RigidBody3D, mode_param: String, spawn_idx: int) -> RigidBody3D:
	var die_to_use: RigidBody3D = base_die
	if base_die.get_parent() != null and base_die.visible:
		die_to_use = base_die.duplicate() as RigidBody3D
		add_child(die_to_use)

	die_to_use.visible = true
	die_to_use.process_mode = PROCESS_MODE_INHERIT
	die_to_use.freeze = false
	die_to_use.linear_velocity = Vector3.ZERO
	die_to_use.angular_velocity = Vector3.ZERO

	if not mode_param.is_empty() and die_to_use.has_method("set_d10_mode"):
		die_to_use.call("set_d10_mode", mode_param)

	var col_x = float(spawn_idx % 5) * 0.12 - 0.24
	var row_z = floorf(float(spawn_idx) / 5.0) * 0.12 - 0.24
	var spawn_y = 0.15 + (randf() * 0.15)

	die_to_use.position = Vector3(col_x + randf_range(-0.02, 0.02), spawn_y, row_z + randf_range(-0.02, 0.02))
	die_to_use.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
	dice.append(die_to_use)
	return die_to_use

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
			new_die.freeze = false
			dice.append(new_die)

func _lock_world(active_dice: Array[RigidBody3D]) -> void:
	for d in active_dice:
		if is_instance_valid(d):
			d.linear_velocity = Vector3.ZERO
			d.angular_velocity = Vector3.ZERO
			d.freeze = true
	if gravity_area:
		gravity_area.gravity_direction = Vector3.DOWN
		gravity_area.gravity = 9.8

func _unlock_world() -> void:
	at_rest_settle_timer = 0.0
	for d in dice:
		if is_instance_valid(d):
			var user_locked = bool(d.get_meta("is_user_locked", false))
			d.freeze = user_locked

func _physics_process(delta: float) -> void:
	if result_screen and result_screen.visible:
		return

	if roll_grace_timer > 0.0:
		roll_grace_timer -= delta

	if shake_cooldown > 0.0:
		shake_cooldown -= delta

	var target_gravity_dir = Vector3.ZERO

	# 1. Check for Mobile Sensors
	var device_gravity = Input.get_gravity()

	if not device_gravity.is_zero_approx():
		# --- MOBILE MODE ---
		var mapped_gravity = Vector3(
			device_gravity.x,  # Left/Right stays on X
			device_gravity.z, # Hardware Z (in/out of screen) becomes Godot's Up/Down
			-device_gravity.y   # Hardware Y (top/bottom of phone) becomes Godot's Forward/Back
		)

		target_gravity_dir = mapped_gravity

		# Calculate dynamic physical shake with upward launch boost and rotation spin
		var total_accel = Input.get_accelerometer()
		var pure_shake = total_accel - device_gravity
		var shake_mag = pure_shake.length()

		if shake_cooldown <= 0.0 and shake_mag > maxf(2.5, shake_threshold):
			shake_cooldown = 0.12 # Fast responsive cooldown for continuous shaking
			has_left_rest = true

			# Map hardware shake axes to 3D world space
			var mapped_shake = Vector3(
				pure_shake.x,
				pure_shake.z,
				-pure_shake.y
			)

			# Give a strong vertical kick so dice launch up into the air when shaken strongly
			var upward_kick = maxf(1.5, shake_mag * 0.25)
			mapped_shake.y += upward_kick

			# Scale impulse so strong phone shakes make dice fly across the tray
			var impulse_scale = shake_multiplier * 0.35

			for d in dice:
				if is_instance_valid(d):
					if bool(d.get_meta("is_user_locked", false)):
						continue

					var die_impulse = mapped_shake * impulse_scale
					# Add slight random directional variation per die so dice scatter dynamically
					die_impulse += Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5))

					d.apply_central_impulse(die_impulse)

					# Strong dynamic torque spin so dice tumble mid-air
					var spin_power = randf_range(0.3, 0.8) * shake_multiplier
					var random_spin = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * spin_power
					d.apply_torque_impulse(random_spin)

	else:
		# --- DESKTOP TESTING MODE (Arrow Keys) ---
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		if input_dir.is_zero_approx():
			simulated_gravity = simulated_gravity.lerp(Vector3(0, -9.8, 0), 5.0 * delta)
		else:
			has_left_rest = true
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

	# 3. Check for at-rest state transition to trigger ResultScreen
	_check_at_rest_transition(delta)

func _check_at_rest_transition(delta: float) -> void:
	var start_menu = get_node_or_null("StartMenu")
	if start_menu and start_menu.visible:
		at_rest_settle_timer = 0.0
		return

	if roll_grace_timer > 0.0:
		at_rest_settle_timer = 0.0
		return

	var active_dice: Array[RigidBody3D] = []
	var all_at_rest: bool = true

	for d in dice:
		if is_instance_valid(d) and d.visible and d.process_mode != PROCESS_MODE_DISABLED:
			active_dice.append(d)
			if not d.sleeping and (d.linear_velocity.length() > 0.03 or d.angular_velocity.length() > 0.03):
				all_at_rest = false

	if active_dice.is_empty():
		at_rest_settle_timer = 0.0
		return

	if not all_at_rest:
		# Dice are actively moving! Mark that they have left rest state (unless movement is manual dragging)
		if not is_drag_active and dragging_die == null:
			has_left_rest = true
		at_rest_settle_timer = 0.0
		if not (result_screen and result_screen.visible):
			has_shown_result_for_current_roll = false
			if result_screen and result_screen.visible:
				result_screen.hide_result()
	else:
		# Dice are all at rest. Only trigger result screen if they have moved via rolling (has_left_rest) and haven't shown result yet
		if has_left_rest and not has_shown_result_for_current_roll:
			at_rest_settle_timer += delta
			if at_rest_settle_timer >= at_rest_delay:
				has_shown_result_for_current_roll = true
				_lock_world(active_dice)
				if result_screen:
					result_screen.show_result(active_dice)

func _on_roll_again_requested() -> void:
	_unlock_world()
	has_shown_result_for_current_roll = false
	has_left_rest = false
	at_rest_settle_timer = 0.0
	roll_grace_timer = 0.0

func _on_lock_flat_and_reroll_requested() -> void:
	for d in dice:
		if is_instance_valid(d) and d.visible and d.process_mode != PROCESS_MODE_DISABLED:
			if d.has_method("get_upward_value"):
				var res = d.call("get_upward_value") as Dictionary
				var is_flat: bool = bool(res.get("is_flat", false))
				_set_die_user_lock(d, is_flat)
			else:
				_set_die_user_lock(d, true)

	has_shown_result_for_current_roll = false
	has_left_rest = false
	at_rest_settle_timer = 0.0
	roll_grace_timer = 0.0

func _on_main_menu_requested() -> void:
	_clear_all_user_locks()
	_unlock_world()
	has_shown_result_for_current_roll = false
	has_left_rest = false
	var start_menu = get_node_or_null("StartMenu")
	if start_menu and start_menu.has_method("show_menu"):
		start_menu.call("show_menu")
	elif start_menu:
		start_menu.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if result_screen and result_screen.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_R:
				if result_screen.has_method("hide_result"):
					result_screen.hide_result()
				_on_roll_again_requested()
				get_viewport().set_input_as_handled()
		return

	var start_menu = get_node_or_null("StartMenu")
	var is_menu_open = start_menu and start_menu.visible
	var is_result_open = result_screen and result_screen.visible

	# --- 3D RAYCAST DIE SELECTION & GROUND DRAGGING ---
	if not is_menu_open and not is_result_open:

		# 1. MOUSE / TOUCH PRESS DOWN -> Pick Die
		var is_press = false
		var press_pos = Vector2.ZERO

		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press_pos = event.position
			is_press = true
		elif event is InputEventScreenTouch and event.pressed:
			press_pos = event.position
			is_press = true

		if is_press:
			var camera = get_viewport().get_camera_3d()
			if camera:
				var from = camera.project_ray_origin(press_pos)
				var to = from + camera.project_ray_normal(press_pos) * 100.0
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(from, to)

				var exclude_list: Array[RID] = []
				var hit_die: RigidBody3D = null
				var hit_info_str: String = "No Hit"

				while true:
					query.exclude = exclude_list
					var result = space_state.intersect_ray(query)
					if not result or not result.has("collider"):
						break

					var collider = result["collider"]
					if collider in dice or (collider is RigidBody3D and collider.get_parent() == self):
						hit_die = collider as RigidBody3D
						hit_info_str = "Hit Die: %s" % collider.name
						break
					else:
						if "rid" in result:
							exclude_list.append(result["rid"] as RID)
						hit_info_str = "Bypassed: %s" % collider.name

				last_pick_debug_info = hit_info_str

				if hit_die:
					dragging_die = hit_die
					drag_start_pos = press_pos
					is_drag_active = false
					get_viewport().set_input_as_handled()
					return

		# 2. MOUSE MOTION / SCREEN DRAG -> Slide Die across floor
		if dragging_die and is_instance_valid(dragging_die):
			var motion_pos = Vector2.ZERO
			var has_motion = false

			if event is InputEventMouseMotion:
				motion_pos = event.position
				has_motion = true
			elif event is InputEventScreenDrag:
				motion_pos = event.position
				has_motion = true

			if has_motion:
				if not is_drag_active and (motion_pos - drag_start_pos).length() >= drag_threshold:
					is_drag_active = true

				if is_drag_active:
					var camera = get_viewport().get_camera_3d()
					if camera:
						var ray_origin = camera.project_ray_origin(motion_pos)
						var ray_dir = camera.project_ray_normal(motion_pos)
						if absf(ray_dir.y) > 0.0001:
							var ground_y = maxf(0.05, dragging_die.position.y)
							var t = (ground_y - ray_origin.y) / ray_dir.y
							var target_pos = ray_origin + ray_dir * t
							_slide_die_to_position(dragging_die, target_pos)
							last_pick_debug_info = "Dragging %s" % dragging_die.name
							get_viewport().set_input_as_handled()
							return

		# 3. MOUSE / TOUCH RELEASE -> Finish Drag or Quick Tap Toggle
		var is_release = false
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_release = true
		elif event is InputEventScreenTouch and not event.pressed:
			is_release = true

		if is_release and dragging_die and is_instance_valid(dragging_die):
			if not is_drag_active:
				_toggle_die_user_lock(dragging_die)
			else:
				if not bool(dragging_die.get_meta("is_user_locked", false)):
					dragging_die.linear_velocity = Vector3.ZERO
					dragging_die.angular_velocity = Vector3.ZERO

			dragging_die = null
			is_drag_active = false
			get_viewport().set_input_as_handled()
			return

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
	_unlock_world()
	has_left_rest = true
	roll_grace_timer = 0.6
	for d in dice:
		if not is_instance_valid(d):
			continue
		if bool(d.get_meta("is_user_locked", false)):
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
	_unlock_world()
	has_left_rest = true
	roll_grace_timer = 0.3
	for d in dice:
		if not is_instance_valid(d):
			continue
		if bool(d.get_meta("is_user_locked", false)):
			continue
		var random_jerk = base_direction * randf_range(0.8, 1.2) * (shake_multiplier * 0.1)
		random_jerk.y += randf_range(0.3, 0.6) * (shake_multiplier * 0.1)

		d.apply_central_impulse(random_jerk)

		var random_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.05
		d.apply_torque_impulse(random_spin)

func _reset_die() -> void:
	_unlock_world()
	has_left_rest = true
	roll_grace_timer = 0.6
	for i in range(dice.size()):
		var d = dice[i]
		if is_instance_valid(d):
			if bool(d.get_meta("is_user_locked", false)):
				continue
			d.global_position = Vector3(randf_range(-0.2, 0.2), 0.5 + (i * 0.12), randf_range(-0.2, 0.2))
			d.linear_velocity = Vector3.ZERO
			d.angular_velocity = Vector3.ZERO
