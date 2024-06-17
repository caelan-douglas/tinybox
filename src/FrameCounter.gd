extends Label

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	text = str("Fps: ", Engine.get_frames_per_second())
