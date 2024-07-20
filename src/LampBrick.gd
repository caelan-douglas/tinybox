extends Brick

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	super(new)
	$Smoothing/OmniLight3D.set("light_color", new)
