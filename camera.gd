extends Camera3D

# You can adjust this value directly in the Inspector
# The ground has a width of 2
# The camera has a field of view of 45° = π/4
# When we look at half, that does:
# tan(π/8) = 1/h = sqrt(2) - 1
# Therefore h = 1/(sqrt(2) - 1) = sqrt(2) + 1

@export var starting_height: float = 1.0 / tan(deg_to_rad(5.0)) # ~11.43m for 10-degree FOV

func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = 10.0
	position = Vector3(0.0, starting_height, 0.0)
	rotation_degrees = Vector3(-90.0, 0.0, 0.0)
