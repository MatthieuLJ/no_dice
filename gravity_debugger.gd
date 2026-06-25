extends MeshInstance3D

var debug_mesh: ImmediateMesh
var material: StandardMaterial3D

func _ready() -> void:
	# Create the dynamic mesh
	debug_mesh = ImmediateMesh.new()
	mesh = debug_mesh
	
	# Make it a bright, unshaded red so it's easy to see
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.RED
	material_override = material

# We will call this from the main controller every frame
func draw_gravity_vector(direction: Vector3) -> void:
	debug_mesh.clear_surfaces()
	if direction.is_zero_approx():
		return
		
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Start point (Center of the tray)
	debug_mesh.surface_add_vertex(Vector3.ZERO)
	
	# End point (Point in the direction of gravity)
	# Multiply by 3.0 to make the line long enough to see easily
	debug_mesh.surface_add_vertex(direction.normalized() * 3.0) 
	
	debug_mesh.surface_end()
