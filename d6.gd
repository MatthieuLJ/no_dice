extends BaseDie

func _get_die_half_size() -> float:
	return 0.05

func _get_faces() -> Array:
	return [
		{ "normal": Vector3(0, 1, 0), "value": 2 },
		{ "normal": Vector3(0, -1, 0), "value": 5 },
		{ "normal": Vector3(1, 0, 0), "value": 3 },
		{ "normal": Vector3(-1, 0, 0), "value": 4 },
		{ "normal": Vector3(0, 0, 1), "value": 1 },
		{ "normal": Vector3(0, 0, -1), "value": 6 }
	]

func get_upward_value() -> Dictionary:
	var res: Dictionary = super.get_upward_value()
	res["is_flat"] = (float(res["dot"]) >= 0.96)
	return res
