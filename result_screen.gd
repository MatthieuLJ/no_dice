extends CanvasLayer

signal roll_again_requested
signal main_menu_requested
signal lock_flat_and_reroll_requested

@onready var blur_rect: ColorRect = get_node_or_null("BlurRect") as ColorRect
@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var counts_label: Label = find_child("CountsLabel", true, false) as Label
@onready var stats_label: Label = find_child("StatsLabel", true, false) as Label
@onready var histogram_draw: Control = find_child("HistogramDrawer", true, false) as Control
@onready var roll_again_btn: Button = find_child("RollAgainButton", true, false) as Button
@onready var lock_flat_btn: Button = find_child("LockFlatButton", true, false) as Button
@onready var main_menu_btn: Button = find_child("MainMenuButton", true, false) as Button

var is_active: bool = false

func _ready() -> void:
	visible = false
	if roll_again_btn:
		roll_again_btn.pressed.connect(_on_roll_again_pressed)
	if lock_flat_btn:
		lock_flat_btn.pressed.connect(_on_lock_flat_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)

func show_result(active_dice: Array[RigidBody3D]) -> void:
	if active_dice.is_empty():
		return

	var total_sum: int = 0
	var is_broken: bool = false
	var dice_faces_list: Array[Array] = []
	var value_counts: Dictionary = {}

	for die in active_dice:
		if not is_instance_valid(die):
			continue

		var faces: Array[int] = _get_die_face_outcomes(die)
		dice_faces_list.append(faces)

		if die.has_method("get_upward_value"):
			var res = die.call("get_upward_value") as Dictionary
			var is_flat: bool = bool(res.get("is_flat", false))
			var val: int = int(res.get("value", 0))

			if not is_flat:
				is_broken = true
			else:
				total_sum += val
				value_counts[val] = int(value_counts.get(val, 0)) + 1

	var pmf: Dictionary = _calculate_pmf(dice_faces_list)

	# Build value breakdown count string
	var count_parts: Array[String] = []
	var sorted_vals = value_counts.keys()
	sorted_vals.sort()
	sorted_vals.reverse() # Show highest face values first

	for val in sorted_vals:
		var cnt: int = int(value_counts[val])
		count_parts.append("%ds: %d" % [val, cnt])

	var counts_text: String = ""
	if count_parts.size() == 1:
		counts_text = "Count of " + count_parts[0]
	elif count_parts.size() > 1:
		if count_parts.size() > 5:
			var mid: int = int(ceil(count_parts.size() / 2.0))
			var line1: String = ", ".join(count_parts.slice(0, mid))
			var line2: String = ", ".join(count_parts.slice(mid))
			counts_text = "Counts: " + line1 + "\n" + line2
		else:
			counts_text = "Counts: " + ", ".join(count_parts)

	if counts_label:
		counts_label.text = counts_text
		counts_label.visible = not counts_text.is_empty()

	if is_broken:
		if title_label:
			title_label.text = "BROKEN DIE"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		if stats_label:
			stats_label.text = "One or more dice came to rest leaning or cocked on an edge."
		if lock_flat_btn:
			lock_flat_btn.visible = true
	else:
		if title_label:
			title_label.text = "Sum: %d" % total_sum
			title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		if lock_flat_btn:
			lock_flat_btn.visible = false

		var prob_ge: float = 0.0
		for s_key in pmf.keys():
			if int(s_key) >= total_sum:
				prob_ge += float(pmf[s_key])

		var pct_ge: float = prob_ge * 100.0
		var prob_str: String = ""

		if prob_ge >= 1.0 - 0.000001:
			prob_str = "100.0%"
		elif prob_ge > 0.999:
			prob_str = "> 99.9%"
		elif prob_ge <= 0.000001:
			prob_str = "0.0%"
		elif prob_ge < 0.001:
			prob_str = "< 0.1%"
		else:
			prob_str = "%.1f%%" % pct_ge

		if stats_label:
			stats_label.text = "P(Sum ≥ %d): %s" % [total_sum, prob_str]

	if histogram_draw:
		histogram_draw.call("set_data", pmf, total_sum, is_broken)

	visible = true
	is_active = true

func hide_result() -> void:
	visible = false
	is_active = false

func _on_roll_again_pressed() -> void:
	hide_result()
	roll_again_requested.emit()

func _on_lock_flat_pressed() -> void:
	hide_result()
	lock_flat_and_reroll_requested.emit()

func _on_main_menu_pressed() -> void:
	hide_result()
	main_menu_requested.emit()

func _get_die_face_outcomes(die: RigidBody3D) -> Array[int]:
	if die.has_method("_get_faces"):
		var faces_info: Array = die.call("_get_faces") as Array
		var vals: Array[int] = []
		for f in faces_info:
			if f is Dictionary and "value" in f:
				vals.append(int(f["value"]))
		if not vals.is_empty():
			return vals

	var script_path = die.get_script().resource_path if die.get_script() else ""

	if "d4.gd" in script_path:
		return [1, 2, 3, 4]
	elif "d6.gd" in script_path:
		return [1, 2, 3, 4, 5, 6]
	elif "d8.gd" in script_path:
		return [1, 2, 3, 4, 5, 6, 7, 8]
	elif "d10.gd" in script_path:
		var mode: String = "low_0"
		if "current_mode" in die:
			mode = str(die.get("current_mode"))

		if mode == "high_10":
			return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
		elif mode == "tens":
			return [0, 10, 20, 30, 40, 50, 60, 70, 80, 90]
		else:
			return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	elif "d12.gd" in script_path:
		return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	elif "d20.gd" in script_path:
		return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

	return [1, 2, 3, 4, 5, 6]

func _calculate_pmf(dice_faces_list: Array[Array]) -> Dictionary:
	if dice_faces_list.is_empty():
		return {}

	var dp: Dictionary = { 0: 1.0 }

	for die_faces in dice_faces_list:
		var next_dp: Dictionary = {}
		var face_prob: float = 1.0 / float(die_faces.size())

		for current_sum in dp.keys():
			var base_prob: float = float(dp[current_sum])
			for val in die_faces:
				var s: int = int(current_sum) + int(val)
				next_dp[s] = float(next_dp.get(s, 0.0)) + base_prob * face_prob

		dp = next_dp

	return dp
