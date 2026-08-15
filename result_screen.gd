extends CanvasLayer

signal roll_again_requested
signal main_menu_requested

@onready var blur_rect: ColorRect = $BlurRect
@onready var title_label: Label = $CenterContainer/PanelContainer/VBox/TitleLabel
@onready var stats_label: Label = $CenterContainer/PanelContainer/VBox/StatsLabel
@onready var histogram_draw: Control = $CenterContainer/PanelContainer/VBox/HistogramContainer/HistogramDrawer
@onready var roll_again_btn: Button = $CenterContainer/PanelContainer/VBox/ButtonRow/RollAgainButton
@onready var main_menu_btn: Button = $CenterContainer/PanelContainer/VBox/ButtonRow/MainMenuButton

var is_active: bool = false

func _ready() -> void:
	visible = false
	if roll_again_btn:
		roll_again_btn.pressed.connect(_on_roll_again_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)

func show_result(active_dice: Array[RigidBody3D]) -> void:
	if active_dice.is_empty():
		return

	var total_sum: int = 0
	var is_broken: bool = false
	var dice_faces_list: Array[Array] = []

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

	var pmf: Dictionary = _calculate_pmf(dice_faces_list)

	if is_broken:
		if title_label:
			title_label.text = "BROKEN DIE"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		if stats_label:
			stats_label.text = "One or more dice came to rest leaning or cocked on an edge."
	else:
		if title_label:
			title_label.text = "Sum: %d" % total_sum
			title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))

		var prob_ge: float = 0.0
		for s_key in pmf.keys():
			if int(s_key) >= total_sum:
				prob_ge += float(pmf[s_key])

		var pct_ge: float = prob_ge * 100.0

		if stats_label:
			stats_label.text = "P(Sum ≥ %d): %.1f%%" % [total_sum, pct_ge]

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

func _on_main_menu_pressed() -> void:
	hide_result()
	main_menu_requested.emit()

func _get_die_face_outcomes(die: RigidBody3D) -> Array[int]:
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
