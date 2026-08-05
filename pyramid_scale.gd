
extends AnimatableBody3D

@onready var wall_north: CollisionShape3D = $Wall_North
@onready var wall_south: CollisionShape3D = $Wall_South
@onready var wall_east: CollisionShape3D = $Wall_East
@onready var wall_west: CollisionShape3D = $Wall_West
@onready var floor_mesh: MeshInstance3D = $MeshInstance3D
@onready var roof: CollisionShape3D = $Roof


func _ready() -> void:
	# Connect to viewport resize to update scale automatically
	get_viewport().size_changed.connect(_update_scale)
	# Initial call to set scale at startup
	_update_scale()

func _update_scale() -> void:
	var view_size = get_viewport().get_visible_rect().size
	if view_size.x == 0:
		return

	var aspect_ratio = maxf(1.0, view_size.y / view_size.x)

	# Moving the walls to match the aspect ratio of the display
	wall_north.position = Vector3(0.0, 0.5, -aspect_ratio)
	wall_south.position = Vector3(0.0, 0.5, aspect_ratio)

	# Scale East and West side walls along Z to fill the gap to North/South walls
	wall_east.scale.z = aspect_ratio
	wall_west.scale.z = aspect_ratio

	# Scale floor mesh and roof to cover the entire area
	floor_mesh.scale.z = aspect_ratio
	roof.scale.z = aspect_ratio
