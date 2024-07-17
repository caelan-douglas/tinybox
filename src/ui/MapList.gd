extends OptionButton


func _ready() -> void:
	# add built-in worlds
	add_separator("Built-in worlds")
	add_item("Frozen Field.tbw")
	# add user worlds to list
	add_separator("Your worlds")
	for map : String in Global.get_user_tbw_names():
		add_item(map)
