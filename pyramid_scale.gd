
extends StaticBody3D

@onready var wall_north: CollisionShape3D = $Wall_North
@onready var wall_south: CollisionShape3D = $Wall_South
@onready var wall_east: CollisionShape3D = $Wall_East
@onready var wall_west: CollisionShape3D = $Wall_West
@onready var floor_mesh: MeshInstance3D = $MeshInstance3D


# Camera is at Y = sqrt(2) + 1.0 = 2.4142. Apex is located just above the camera.
@export var camera_height: float = sqrt(2.0) + 1.0 # 2.4142m
@export var apex_margin_above_camera: float = 0.6 # Apex is at Y = 3.0142m
@export var base_inset_factor: float = 1.0 # Base position at viewport bounds (1.0)

var _last_view_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	_remove_wall_meshes()
	if has_node("Roof"):
		get_node("Roof").queue_free()
	get_viewport().size_changed.connect(_update_scale)
	_update_scale()

func _remove_wall_meshes() -> void:
	var walls = [wall_north, wall_south, wall_east, wall_west]
	for w in walls:
		if w and w.has_node("VisualMesh"):
			w.get_node("VisualMesh").queue_free()

func _process(_delta: float) -> void:
	var view_size = get_viewport().get_visible_rect().size
	if view_size != _last_view_size:
		_update_scale()

func _update_scale() -> void:
	var view_size = get_viewport().get_visible_rect().size
	if view_size.x == 0 or view_size.y == 0:
		return
	_last_view_size = view_size

	# aspect_ratio = viewport height / viewport width
	var aspect_ratio = view_size.y / view_size.x

	# Base inset bounds (walls placed at base_inset_factor of viewport bounds at floor Y=0)
	var base_x = base_inset_factor # 1.0
	var base_z = aspect_ratio * base_inset_factor # aspect_ratio * 1.0

	# Apex point directly above camera: (0, apex_y, 0)
	var apex_y = camera_height + apex_margin_above_camera # ~3.0142m
	var thickness = 0.1

	# Full slant lengths from floor base (Y=0) to apex (Y=apex_y)
	var slant_len_x = sqrt(base_x * base_x + apex_y * apex_y)
	var slant_len_z = sqrt(base_z * base_z + apex_y * apex_y)

	var y_mid = apex_y / 2.0 # Midpoint height

	# 1. East/West walls (base at X = +/- base_x at floor Y=0, meeting at X=0 at Y=apex_y)
	var theta_x = atan2(base_x, apex_y)
	var offset_x = (thickness / 2.0) * cos(theta_x)
	var offset_y_x = (thickness / 2.0) * sin(theta_x)

	wall_east.rotation = Vector3(0.0, 0.0, theta_x)
	wall_west.rotation = Vector3(0.0, 0.0, -theta_x)

	var x_mid = base_x / 2.0
	wall_east.position = Vector3(x_mid + offset_x, y_mid - offset_y_x, 0.0)
	wall_west.position = Vector3(-x_mid - offset_x, y_mid - offset_y_x, 0.0)

	# Scale wall height (Y) to span the full slant length from floor to apex
	wall_east.scale.y = slant_len_x * 1.1
	wall_west.scale.y = slant_len_x * 1.1

	wall_east.scale.z = maxf(2.0, aspect_ratio * 3.0)
	wall_west.scale.z = maxf(2.0, aspect_ratio * 3.0)

	# 2. North/South walls (base at Z = +/- base_z at floor Y=0, meeting at Z=0 at Y=apex_y)
	var theta_z = atan2(base_z, apex_y)
	var offset_z = (thickness / 2.0) * cos(theta_z)
	var offset_y_z = (thickness / 2.0) * sin(theta_z)

	wall_north.rotation = Vector3(theta_z, 0.0, 0.0)
	wall_south.rotation = Vector3(-theta_z, 0.0, 0.0)

	var z_mid = base_z / 2.0
	wall_north.position = Vector3(0.0, y_mid - offset_y_z, -z_mid - offset_z)
	wall_south.position = Vector3(0.0, y_mid - offset_y_z, z_mid + offset_z)

	# Scale wall height (Y) to span the full slant length from floor to apex
	wall_north.scale.y = slant_len_z * 1.1
	wall_south.scale.y = slant_len_z * 1.1

	wall_north.scale.x = maxf(2.0, (1.0 / aspect_ratio) * 3.0)
	wall_south.scale.x = maxf(2.0, (1.0 / aspect_ratio) * 3.0)

	# Scale floor mesh so green ground fills 100% of camera viewport
	floor_mesh.scale = Vector3(4.0, 1.0, 4.0 * maxf(1.0, aspect_ratio))
