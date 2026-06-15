extends CSGCombiner3D

func _ready():
	# Connect to viewport resize to update scale automatically
	get_viewport().size_changed.connect(_update_pyramid_scale)
	# Initial call to set scale at startup
	_update_pyramid_scale()

func _update_pyramid_scale():
	var view_size = get_viewport().get_visible_rect().size
	var aspect_ratio = view_size.y / view_size.x
	
	# Apply scale to the X-axis to flatten/widen the pyramid
	self.scale.x = aspect_ratio
