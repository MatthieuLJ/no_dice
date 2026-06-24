extends Camera3D

# You can adjust this value directly in the Inspector
# The ground has a width of 2
# The camera has a field of view of 45° = π/4
# When we look at half, that does:
# tan(π/8) = 1/h = sqrt(2) - 1
# Therefore h = 1/(sqrt(2) - 1) = sqrt(2) + 1

@export var starting_height: float = sqrt(2) + 1.2

func _ready() -> void:
	# Change only the Y position (height)
	position.y = starting_height
