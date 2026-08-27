extends CanvasLayer

signal menu_dismissed(dice_counts: Dictionary)
signal selection_changed(dice_counts: Dictionary)

var dice_counts: Dictionary = {
	"d4": 0,
	"d6": 1,
	"d8": 0,
	"d10": 0,
	"d12": 0,
	"d20": 0,
	"d100": 0,
	"d10_mode": "low_0"
}

var is_d10_high_10: bool = false

@onready var blur_rect: ColorRect = get_node_or_null("BlurRect") as ColorRect
@onready var menu_container: Control = get_node_or_null("MenuContainer") as Control
@onready var blink_label: Label = find_child("BlinkPrompt", true, false) as Label

@onready var label_d4: Label = _find_sub_node("RowD4", "CountLabel") as Label
@onready var minus_d4: Button = _find_sub_node("RowD4", "MinusButton") as Button
@onready var plus_d4: Button = _find_sub_node("RowD4", "PlusButton") as Button

@onready var label_d6: Label = _find_sub_node("RowD6", "CountLabel") as Label
@onready var minus_d6: Button = _find_sub_node("RowD6", "MinusButton") as Button
@onready var plus_d6: Button = _find_sub_node("RowD6", "PlusButton") as Button

@onready var label_d8: Label = _find_sub_node("RowD8", "CountLabel") as Label
@onready var minus_d8: Button = _find_sub_node("RowD8", "MinusButton") as Button
@onready var plus_d8: Button = _find_sub_node("RowD8", "PlusButton") as Button

@onready var label_d10: Label = _find_sub_node("RowD10", "CountLabel") as Label
@onready var minus_d10: Button = _find_sub_node("RowD10", "MinusButton") as Button
@onready var plus_d10: Button = _find_sub_node("RowD10", "PlusButton") as Button

@onready var d10_mode_button: Button = find_child("D10ModeButton", true, false) as Button

@onready var label_d12: Label = _find_sub_node("RowD12", "CountLabel") as Label
@onready var minus_d12: Button = _find_sub_node("RowD12", "MinusButton") as Button
@onready var plus_d12: Button = _find_sub_node("RowD12", "PlusButton") as Button

@onready var label_d20: Label = _find_sub_node("RowD20", "CountLabel") as Label
@onready var minus_d20: Button = _find_sub_node("RowD20", "MinusButton") as Button
@onready var plus_d20: Button = _find_sub_node("RowD20", "PlusButton") as Button

@onready var label_d100: Label = _find_sub_node("RowD100", "CountLabel") as Label
@onready var minus_d100: Button = _find_sub_node("RowD100", "MinusButton") as Button
@onready var plus_d100: Button = _find_sub_node("RowD100", "PlusButton") as Button

func _find_sub_node(row_name: String, node_name: String) -> Node:
	var row = find_child(row_name, true, false)
	if row:
		return row.get_node_or_null(node_name)
	return null

var _is_active: bool = true
var _blink_timer: float = 0.0

func _ready() -> void:
	layer = 100
	process_mode = PROCESS_MODE_ALWAYS
	_update_all_displays()

	_connect_row("d4", minus_d4, plus_d4)
	_connect_row("d6", minus_d6, plus_d6)
	_connect_row("d8", minus_d8, plus_d8)
	_connect_row("d10", minus_d10, plus_d10)
	_connect_row("d12", minus_d12, plus_d12)
	_connect_row("d20", minus_d20, plus_d20)
	_connect_row("d100", minus_d100, plus_d100)

	if d10_mode_button:
		d10_mode_button.pressed.connect(_on_d10_mode_pressed)

func _on_d10_mode_pressed() -> void:
	is_d10_high_10 = !is_d10_high_10
	dice_counts["d10_mode"] = "high_10" if is_d10_high_10 else "low_0"
	if d10_mode_button:
		d10_mode_button.text = "High 10" if is_d10_high_10 else "Low 0"
	selection_changed.emit(dice_counts)

func _connect_row(type_key: String, minus_btn: Button, plus_btn: Button) -> void:
	if minus_btn:
		minus_btn.pressed.connect(func(): _on_count_change(type_key, -1))
	if plus_btn:
		plus_btn.pressed.connect(func(): _on_count_change(type_key, 1))

func _on_count_change(type_key: String, delta: int) -> void:
	var current: int = int(dice_counts.get(type_key, 0))
	if delta > 0:
		var current_total: int = get_total_count()
		if current_total >= 30:
			return
		var new_val: int = min(30 - (current_total - current), current + delta)
		dice_counts[type_key] = new_val
	else:
		var new_val: int = max(0, current + delta)
		dice_counts[type_key] = new_val

	_update_all_displays()
	selection_changed.emit(dice_counts)

func sync_from_dice(active_dice: Array) -> void:
	var counts: Dictionary = {
		"d4": 0, "d6": 0, "d8": 0, "d10": 0, "d12": 0, "d20": 0, "d100": 0, "d10_mode": "low_0"
	}
	var d10_tens_count: int = 0
	var d10_single_count: int = 0

	for d in active_dice:
		if not is_instance_valid(d) or not d.visible or d.process_mode == PROCESS_MODE_DISABLED:
			continue
		var script_path = d.get_script().resource_path.to_lower() if d.get_script() else ""
		if "d4.gd" in script_path: counts["d4"] += 1
		elif "d6.gd" in script_path: counts["d6"] += 1
		elif "d8.gd" in script_path: counts["d8"] += 1
		elif "d12.gd" in script_path: counts["d12"] += 1
		elif "d20.gd" in script_path: counts["d20"] += 1
		elif "d10.gd" in script_path:
			var mode: String = str(d.get("current_mode")) if "current_mode" in d else "low_0"
			if mode == "tens":
				d10_tens_count += 1
			else:
				if mode == "high_10":
					counts["d10_mode"] = "high_10"
				d10_single_count += 1

	var d100_pairs: int = min(d10_tens_count, d10_single_count)
	counts["d100"] = d100_pairs
	counts["d10"] = d10_single_count - d100_pairs

	is_d10_high_10 = (counts["d10_mode"] == "high_10")
	dice_counts = counts
	_update_all_displays()

func _update_all_displays() -> void:
	if label_d4: label_d4.text = str(dice_counts.get("d4", 0))
	if label_d6: label_d6.text = str(dice_counts.get("d6", 0))
	if label_d8: label_d8.text = str(dice_counts.get("d8", 0))
	if label_d10: label_d10.text = str(dice_counts.get("d10", 0))
	if label_d12: label_d12.text = str(dice_counts.get("d12", 0))
	if label_d20: label_d20.text = str(dice_counts.get("d20", 0))
	if label_d100: label_d100.text = str(dice_counts.get("d100", 0))
	if d10_mode_button:
		d10_mode_button.text = "High 10" if is_d10_high_10 else "Low 0"

	var total: int = get_total_count()
	var at_max: bool = (total >= 30)

	var plus_buttons: Array = [plus_d4, plus_d6, plus_d8, plus_d10, plus_d12, plus_d20, plus_d100]
	for btn in plus_buttons:
		if btn:
			btn.disabled = at_max

	var minus_map: Dictionary = {
		"d4": minus_d4, "d6": minus_d6, "d8": minus_d8,
		"d10": minus_d10, "d12": minus_d12, "d20": minus_d20, "d100": minus_d100
	}
	for key in minus_map.keys():
		var btn = minus_map[key] as Button
		if btn:
			btn.disabled = (int(dice_counts.get(key, 0)) <= 0)

	if is_instance_valid(blink_label):
		if total == 0:
			blink_label.text = "SELECT AT LEAST 1 DIE"
			blink_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		elif at_max:
			blink_label.text = "TAP TO ROLL (MAX 30 DICE)"
			blink_label.remove_theme_color_override("font_color")
		else:
			blink_label.text = "TAP TO ROLL"
			blink_label.remove_theme_color_override("font_color")

func get_total_count() -> int:
	var total: int = 0
	for key in ["d4", "d6", "d8", "d10", "d12", "d20", "d100"]:
		total += int(dice_counts.get(key, 0))
	return total

func _process(delta: float) -> void:
	if not _is_active:
		return

	_blink_timer += delta * 3.0
	if is_instance_valid(blink_label):
		blink_label.modulate.a = 1.0 if fmod(_blink_timer, 2.0) < 1.0 else 0.25

func _input(event: InputEvent) -> void:
	if not _is_active or not visible:
		return

	var is_press: bool = false
	var press_pos: Vector2 = Vector2.ZERO

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = true
		press_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		is_press = true
		press_pos = event.position

	if is_press:
		var buttons: Array[Button] = [
			minus_d4, plus_d4,
			minus_d6, plus_d6,
			minus_d8, plus_d8,
			minus_d10, plus_d10,
			d10_mode_button,
			minus_d12, plus_d12,
			minus_d20, plus_d20,
			minus_d100, plus_d100
		]

		for btn in buttons:
			if btn and is_instance_valid(btn) and btn.visible and btn.get_global_rect().has_point(press_pos):
				return # Keep menu open while adjusting configuration

		var blink = find_child("BlinkPrompt", true, false) as Control
		var is_on_blink: bool = false
		if blink and is_instance_valid(blink):
			# Expand touch rect by 40px padding for easy, forgiving tapping on "TAP TO ROLL"
			var blink_rect = blink.get_global_rect().grow(40.0)
			is_on_blink = blink_rect.has_point(press_pos)

		var panel = find_child("PanelContainer", true, false) as Control
		if panel and is_instance_valid(panel):
			var panel_rect = panel.get_global_rect()
			var is_outside = not panel_rect.has_point(press_pos)

			if is_outside or is_on_blink:
				dismiss_menu()
				get_viewport().set_input_as_handled()
				return

func dismiss_menu() -> void:
	if not _is_active:
		return
	if get_total_count() == 0:
		# Block exiting main menu when zero dice are selected
		_update_all_displays()
		return

	_is_active = false
	dice_counts["d10_mode"] = "high_10" if is_d10_high_10 else "low_0"

	var tween = create_tween().set_parallel(true)
	tween.tween_property(blur_rect, "modulate:a", 0.0, 0.35)
	tween.tween_property(menu_container, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		visible = false
		menu_dismissed.emit(dice_counts)
	)

func show_menu() -> void:
	visible = true
	_is_active = true
	if blur_rect:
		blur_rect.modulate.a = 1.0
	if menu_container:
		menu_container.modulate.a = 1.0
	selection_changed.emit(dice_counts)
