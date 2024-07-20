extends Brick

@onready var light : OmniLight3D = $Smoothing/OmniLight3D

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	super(new)
	if light != null:
		light.set("light_color", new)

@rpc("call_local")
func set_glued(new : bool, affect_others : bool = true) -> void:
	super(new, affect_others)
	if light != null:
		light.visible = false
