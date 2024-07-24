extends Control
class_name ItemChooser

@onready var item_names_list : Array[String] = SpawnableObjects.get_editor_spawnable_objects_list()
@onready var item_chooser_button : PackedScene = preload("res://data/scene/ui/ItemChooserButton.tscn")
@onready var item_chooser_set : PackedScene = preload("res://data/scene/ui/ItemChooserSet.tscn")
@onready var list : VBoxContainer = $Menu/ScrollContainer/ItemList

func create_set(set_name : String) -> void:
	var set_i : Control = item_chooser_set.instantiate()
	# set the node's name
	set_i.name = set_name
	list.add_child(set_i)
	var title_text : Label = set_i.get_node_or_null("Title")
	if title_text != null:
		# set the visual name
		title_text.text = set_name

func add_to_set(set_name : String, what : Button) -> void:
	for item_set in list.get_children():
		if item_set.name == set_name:
			var grid : Control = item_set.get_node_or_null("ItemGrid")
			if grid != null:
				grid.add_child(what)

func _ready() -> void:
	# create sets
	create_set("Basic bricks")
	create_set("Objects")
	create_set("Special")
	for item in item_names_list:
		var item_button : Button = item_chooser_button.instantiate()
		# node name is internal name
		item_button.name = item
		item_button.text = JsonHandler.find_entry_in_file(str("tbw_objects/", item))
		# remove brick icon for non bricks
		if !item.begins_with("brick"):
			item_button.icon = null
		
		if item.begins_with("brick") && item != "brick_button":
			add_to_set("Basic bricks", item_button)
		elif item == "obj_lifter" || item == "obj_pickup" || item == "obj_spawnpoint" || item == "brick_button":
			add_to_set("Special", item_button)
		else:
			add_to_set("Objects", item_button)
		item_button.connect("pressed", _on_item_chosen.bind(item_button.name, item_button.text))

func _on_item_chosen(internal_name : String, display_name : String) -> void:
	var editor : Node = Global.get_world().get_current_map()
	if editor is Editor:
		editor.on_item_chosen(internal_name, display_name)
