extends Label

@export var enabled: bool = true

func _ready() -> void:
	visible = enabled and DiceConfig.ENABLE_DEBUG_LABEL
	if not visible:
		set_process(false)

func _process(_delta: float) -> void:
	if not (enabled and DiceConfig.ENABLE_DEBUG_LABEL and visible):
		visible = false
		set_process(false)
		return

	var grav = Input.get_gravity()
	var accel = Input.get_accelerometer()

	var all_at_rest: bool = true
	var dice_count: int = 0
	var locked_count: int = 0
	var last_pick: String = "None"
	var die_lines: Array[String] = []

	var tree = get_tree()
	if tree and tree.current_scene:
		if "last_pick_debug_info" in tree.current_scene:
			last_pick = str(tree.current_scene.get("last_pick_debug_info"))

		var dice = tree.current_scene.find_children("", "RigidBody3D", true, false)
		for d in dice:
			var body = d as RigidBody3D
			if body and is_instance_valid(body) and body.visible and body.process_mode != PROCESS_MODE_DISABLED:
				dice_count += 1
				var is_locked = bool(body.get_meta("is_user_locked", false))
				if is_locked:
					locked_count += 1

				var lin_speed = body.linear_velocity.length()
				var ang_speed = body.angular_velocity.length()
				var is_sleeping = body.sleeping
				var is_frozen = body.freeze

				if not is_sleeping and (lin_speed > 0.03 or ang_speed > 0.03):
					all_at_rest = false

				var status = "MOVING" if lin_speed >= 0.05 else "STATIONARY"
				if is_sleeping:
					status += " (SLEEPING)"
				if is_frozen:
					status += " (FROZEN)"
				if is_locked:
					status += " [LOCKED]"

				var pos = body.position
				die_lines.append("▸ %-4s: %-22s | v:%.2fm/s w:%.2fr/s | Pos:(%.2f,%.2f,%.2f)" % [
					body.name, status, lin_speed, ang_speed, pos.x, pos.y, pos.z
				])

	var rest_str: String = "YES" if (all_at_rest and dice_count > 0) else ("NO" if dice_count > 0 else "N/A")

	var header = "At Rest: %s | Locked: %d/%d | Pick: %s\nGrav: (%.1f,%.1f,%.1f) | Accel: (%.1f,%.1f,%.1f)" % [
		rest_str, locked_count, dice_count, last_pick,
		grav.x, grav.y, grav.z, accel.x, accel.y, accel.z
	]

	text = header + "\n" + "\n".join(die_lines)
