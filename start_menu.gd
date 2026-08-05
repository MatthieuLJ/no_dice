extends CanvasLayer

signal menu_dismissed

@onready var blur_rect: ColorRect = $BlurRect
@onready var menu_container: Control = $MenuContainer
@onready var blink_label: Label = $MenuContainer/VBoxContainer/BlinkPrompt

var _is_active: bool = true
var _blink_timer: float = 0.0

func _ready() -> void:
	layer = 100
	process_mode = PROCESS_MODE_ALWAYS

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

	# Any key, mouse click, screen touch, or controller button starts game
	var is_trigger = false
	if event is InputEventKey and event.pressed and not event.echo:
		is_trigger = true
	elif event is InputEventMouseButton and event.pressed:
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
		menu_dismissed.emit()
		queue_free()
	)
