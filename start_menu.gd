extends CanvasLayer

signal menu_dismissed(dice_counts: Dictionary)

var dice_counts: Dictionary = {
	"d4": 0,
	"d6": 1,
	"d8": 0,
	"d10": 0,
	"d12": 0
}

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

@onready var label_d12: Label = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD12/CountLabel")
@onready var minus_d12: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD12/MinusButton")
@onready var plus_d12: Button = get_node_or_null("MenuContainer/VBoxContainer/ConfigContainer/RowD12/PlusButton")

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

func _connect_row(type_key: String, minus_btn: Button, plus_btn: Button) -> void:
	if minus_btn:
		minus_btn.pressed.connect(func(): _on_count_change(type_key, -1))
	if plus_btn:
		plus_btn.pressed.connect(func(): _on_count_change(type_key, 1))

func _on_count_change(type_key: String, delta: int) -> void:
	var current: int = dice_counts.get(type_key, 0)
	var new_val: int = max(0, min(10, current + delta))
	dice_counts[type_key] = new_val
	_update_all_displays()

func _update_all_displays() -> void:
	if label_d4: label_d4.text = str(dice_counts.get("d4", 0))
	if label_d6: label_d6.text = str(dice_counts.get("d6", 0))
	if label_d8: label_d8.text = str(dice_counts.get("d8", 0))
	if label_d10: label_d10.text = str(dice_counts.get("d10", 0))
	if label_d12: label_d12.text = str(dice_counts.get("d12", 0))

func get_total_count() -> int:
	var total: int = 0
	for val in dice_counts.values():
		total += int(val)
	return total

func _process(delta: float) -> void:
	if not _is_active:
		return

	_blink_timer += delta * 3.0
	if is_instance_valid(blink_label):
		blink_label.modulate.a = 1.0 if fmod(_blink_timer, 2.0) < 1.0 else 0.25

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	var is_trigger: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			is_trigger = true
	elif event is InputEventMouseButton and event.pressed:
		var mouse_pos = event.position
		var buttons: Array[Button] = [
			minus_d4, plus_d4,
			minus_d6, plus_d6,
			minus_d8, plus_d8,
			minus_d10, plus_d10,
			minus_d12, plus_d12
		]
		for btn in buttons:
			if btn and btn.get_global_rect().has_point(mouse_pos):
				return
		is_trigger = true
	elif event is InputEventScreenTouch and event.pressed:
		is_trigger = true

	if is_trigger:
		dismiss_menu()
		get_viewport().set_input_as_handled()

func dismiss_menu() -> void:
	if not _is_active:
		return
	if get_total_count() == 0:
		dice_counts["d6"] = 1
		_update_all_displays()

	_is_active = false

	var tween = create_tween().set_parallel(true)
	tween.tween_property(blur_rect, "modulate:a", 0.0, 0.35)
	tween.tween_property(menu_container, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		visible = false
		menu_dismissed.emit(dice_counts)
		queue_free()
	)
