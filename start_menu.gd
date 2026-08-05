extends CanvasLayer

signal menu_dismissed(dice_count: int)

@export var dice_count: int = 1

@onready var blur_rect: ColorRect = $BlurRect
@onready var menu_container: Control = $MenuContainer
@onready var blink_label: Label = $MenuContainer/VBoxContainer/BlinkPrompt
@onready var count_label: Label = $MenuContainer/VBoxContainer/ConfigContainer/CountLabel
@onready var minus_button: Button = $MenuContainer/VBoxContainer/ConfigContainer/MinusButton
@onready var plus_button: Button = $MenuContainer/VBoxContainer/ConfigContainer/PlusButton

var _is_active: bool = true
var _blink_timer: float = 0.0

func _ready() -> void:
	layer = 100
	process_mode = PROCESS_MODE_ALWAYS
	_update_count_display()

	if minus_button:
		minus_button.pressed.connect(_on_minus_pressed)
	if plus_button:
		plus_button.pressed.connect(_on_plus_pressed)

func _update_count_display() -> void:
	if count_label:
		count_label.text = str(dice_count)

func _on_minus_pressed() -> void:
	if dice_count > 1:
		dice_count -= 1
		_update_count_display()

func _on_plus_pressed() -> void:
	dice_count += 1
	_update_count_display()

func _process(delta: float) -> void:
	if not _is_active:
		return

	# Blink 80s arcade prompt
	_blink_timer += delta * 3.0
	if is_instance_valid(blink_label):
		blink_label.modulate.a = 1.0 if fmod(_blink_timer, 2.0) < 1.0 else 0.25

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Decrement / Increment via keyboard Left/Right or -/+
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_LEFT or event.physical_keycode == KEY_MINUS:
			_on_minus_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.physical_keycode == KEY_RIGHT or event.physical_keycode == KEY_EQUAL or event.physical_keycode == KEY_KP_ADD:
			_on_plus_pressed()
			get_viewport().set_input_as_handled()
			return

	# Space bar, Enter, or Touch dismisses menu
	var is_trigger = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			is_trigger = true
	elif event is InputEventMouseButton and event.pressed:
		# Check if click was outside the plus/minus buttons
		var mouse_pos = event.position
		if minus_button and minus_button.get_global_rect().has_point(mouse_pos):
			return
		if plus_button and plus_button.get_global_rect().has_point(mouse_pos):
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
	_is_active = false

	# Smooth retro fade out transition
	var tween = create_tween().set_parallel(true)
	tween.tween_property(blur_rect, "modulate:a", 0.0, 0.35)
	tween.tween_property(menu_container, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		visible = false
		menu_dismissed.emit(dice_count)
		queue_free()
	)
