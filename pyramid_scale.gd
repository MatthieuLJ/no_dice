
extends AnimatableBody3D

# Reference the wall child nodes
@onready var wall_north: CollisionShape3D = $Wall_North
@onready var wall_south: CollisionShape3D = $Wall_South


func _ready() -> void:
	# Connect to viewport resize to update scale automatically
	get_viewport().size_changed.connect(_update_scale)
	# Initial call to set scale at startup
	_update_scale()

func _update_scale():
	var view_size = get_viewport().get_visible_rect().size
	if view_size.x == 0:
		return

	var aspect_ratio = view_size.y / view_size.x

	# Moving the walls to match the aspect ratio of the display
	wall_north.position = Vector3(0.0, 0.5, -aspect_ratio)
	wall_south.position = Vector3(0.0, 0.5, aspect_ratio)
