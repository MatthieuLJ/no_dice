extends CanvasLayer

signal menu_dismissed(dice_counts: Dictionary)

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

@onready var blur_rect: ColorRect = $BlurRect
@onready var menu_container: Control = $MenuContainer
@onready var blink_label: Label = $MenuContainer/VBoxContainer/BlinkPrompt

@onready var label_d4: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD4/CountLabel")
@onready var minus_d4: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD4/MinusButton")
@onready var plus_d4: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD4/PlusButton")

@onready var label_d6: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD6/CountLabel")
@onready var minus_d6: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD6/MinusButton")
@onready var plus_d6: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD6/PlusButton")

@onready var label_d8: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD8/CountLabel")
@onready var minus_d8: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD8/MinusButton")
@onready var plus_d8: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD8/PlusButton")

@onready var label_d10: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD10/CountLabel")
@onready var minus_d10: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD10/MinusButton")
@onready var plus_d10: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD10/PlusButton")

@onready var d10_mode_button: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/D10ModeRow/D10ModeButton")

@onready var label_d12: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD12/CountLabel")
@onready var minus_d12: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD12/MinusButton")
@onready var plus_d12: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD12/PlusButton")

@onready var label_d20: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD20/CountLabel")
@onready var minus_d20: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD20/MinusButton")
@onready var plus_d20: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD20/PlusButton")

@onready var label_d100: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD100/CountLabel")
@onready var minus_d100: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD100/MinusButton")
@onready var plus_d100: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD100/PlusButton")

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
		if at_max:
			blink_label.text = "TAP TO ROLL (MAX 30 DICE)"
		else:
			blink_label.text = "PRESS SPACE OR TAP TO ROLL"

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

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			dismiss_menu()
			get_viewport().set_input_as_handled()
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

		var vbox = get_node_or_null("MenuContainer/VBoxContainer") as Control
		if vbox and is_instance_valid(vbox):
			var menu_rect = vbox.get_global_rect()
			var is_outside = not menu_rect.has_point(press_pos)

			var blink = get_node_or_null("MenuContainer/VBoxContainer/BlinkPrompt") as Control
			var is_on_blink = blink and is_instance_valid(blink) and blink.get_global_rect().has_point(press_pos)

			if is_outside or is_on_blink:
				dismiss_menu()
				get_viewport().set_input_as_handled()
				return

func dismiss_menu() -> void:
	if not _is_active:
		return
	if get_total_count() == 0:
		dice_counts["d6"] = 1
		_update_all_displays()

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
