extends TBWObject
class_name CameraPreviewPoint

func _ready() -> void:
	if Global.get_world().get_current_map() is Editor:
		$Mesh.visible = true
	else:
		$Mesh.visible = false
