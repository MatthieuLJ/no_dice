extends Label

func _process(_delta: float) -> void:
	if not visible:
		return

	var grav = Input.get_gravity()
	var accel = Input.get_accelerometer()
	var gyro = Input.get_gyroscope()

	text = "Gravity: %s\nAccel: %s\nGyro: %s" % [grav, accel, gyro]
