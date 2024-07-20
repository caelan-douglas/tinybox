extends OptionButton


func _ready() -> void:
	# add built-in worlds
	add_separator("Built-in worlds")
	add_item("Frozen Field.tbw")
	# add user worlds to list
	add_separator("Your worlds")
	for map : String in Global.get_user_tbw_names():
		var image : Image = Global.get_world().get_tbw_image(map.split(".")[0])
		if image != null:
			image.resize(80, 64)
			var tex : ImageTexture = ImageTexture.create_from_image(image)
			add_icon_item(tex, map)
		else:
			add_item(map)
