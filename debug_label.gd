extends Label

# Temporary debug code to add to pyramid_scale.gd or a main script:
func _process(_delta):
	var grav = Input.get_gravity()
	var accel = Input.get_accelerometer()
	var gyro = Input.get_gyroscope()
	
	# Assuming you have a Label node named "Label" in your scene
	if has_node("/root/Node3D/CanvasLayer/Label"): 
		get_node("/root/Node3D/CanvasLayer/Label").text = (
			"Gravity: " + str(grav) + "\n" +
			"Accel: " + str(accel) + "\n" +
			"Gyro: " + str(gyro)
		)
