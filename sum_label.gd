extends Label

func _ready() -> void:
	visible = DiceConfig.ENABLE_DEBUG_LABEL
	if not visible:
		set_process(false)

func _process(_delta: float) -> void:
	if not visible or not DiceConfig.ENABLE_DEBUG_LABEL:
		visible = false
		set_process(false)
		return

	var tree = get_tree()
	if not tree or not tree.current_scene:
		text = ""
		return

	var dice = tree.current_scene.find_children("", "RigidBody3D", true, false)
	var active_dice: Array[RigidBody3D] = []
	var all_at_rest: bool = true

	for d in dice:
		var body = d as RigidBody3D
		if body and is_instance_valid(body) and body.visible and body.process_mode != PROCESS_MODE_DISABLED:
			active_dice.append(body)
			if not body.sleeping and (body.linear_velocity.length() > 0.03 or body.angular_velocity.length() > 0.03):
				all_at_rest = false

	if active_dice.size() == 0 or not all_at_rest:
		text = ""
		return

	var sum_val: int = 0
	var is_broken: bool = false

	for body in active_dice:
		if body.has_method("get_upward_value"):
			var res = body.call("get_upward_value") as Dictionary
			var is_flat: bool = bool(res.get("is_flat", false))
			var val: int = int(res.get("value", 0))

			if not is_flat:
				is_broken = true
				break
			else:
				sum_val += val

	if is_broken:
		text = "broken die"
	else:
		text = "Sum: %d" % sum_val
