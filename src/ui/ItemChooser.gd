# Tinybox
# Copyright (C) 2023-present Caelan Douglas
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

extends Control
class_name ItemChooser
signal item_picked

# more options in editor mode
@export var editor_mode : bool = true

@onready var item_names_list : Array[String] = SpawnableObjects.get_editor_spawnable_objects_list()
@onready var item_chooser_button : PackedScene = preload("res://data/scene/ui/ItemChooserButton.tscn")
@onready var item_chooser_set : PackedScene = preload("res://data/scene/ui/ItemChooserSet.tscn")
@onready var list : VBoxContainer = $"Bricks & Objects/ScrollContainer/ItemList"
@onready var saved_list : VBoxContainer = $"Saved Stuff/ScrollContainer/ItemList"

func create_set(set_name : String, tab : int = 0, grid_cols : int = 2) -> void:
	var set_i : Control = item_chooser_set.instantiate()
	# set the node's name
	set_i.name = set_name
	if tab == 0:
		list.add_child(set_i)
	else:
		saved_list.add_child(set_i)
	# set item grid columns
	var grid : GridContainer = set_i.get_node("ItemGrid")
	grid.columns = grid_cols
	var title_text : Label = set_i.get_node_or_null("Title")
	if title_text != null:
		# set the visual name
		title_text.text = set_name

func add_to_set(set_name : String, what : Button, tab : int = 0) -> void:
	var tab_list : VBoxContainer
	if tab == 0:
		tab_list = list
	else:
		tab_list = saved_list
	
	for item_set in tab_list.get_children():
		if item_set.name == set_name:
			var grid : Control = item_set.get_node_or_null("ItemGrid")
			if grid != null:
				grid.add_child(what)
	what.connect("pressed", _on_item_chosen.bind(what.name, what.text))

func _ready() -> void:
	# create sets for bricks and objects
	create_set("Basic bricks")
	if editor_mode:
		create_set("Objects")
		create_set("Track pieces")
		create_set("Special")
	else:
		create_set("More object types are available in the World Editor.")
	for item in item_names_list:
		var item_button : Button = item_chooser_button.instantiate()
		# node name is internal name
		item_button.name = item
		item_button.text = JsonHandler.find_entry_in_file(str("tbw_objects/", item))
		item_button.tooltip_text = JsonHandler.find_entry_in_file(str("tbw_objects/tooltips/", item))
		if editor_mode:
			# remove brick icon for non bricks
			if item.begins_with("obj_camera"):
				item_button.set_button_icon(load("res://data/textures/editor_icons/camera.png") as Texture2D)
			elif !item.begins_with("brick"):
				item_button.icon = null
			# add item
			if item.begins_with("brick"):
				add_to_set("Basic bricks", item_button)
			elif item.begins_with("obj_track"):
				add_to_set("Track pieces", item_button)
			elif item == "obj_lifter" || item == "obj_pickup" || item == "obj_spawnpoint" || item == "obj_camera_preview_point":
				add_to_set("Special", item_button)
			else:
				add_to_set("Objects", item_button)
		else:
			if item.begins_with("brick"):
				add_to_set("Basic bricks", item_button)
	
	# create sets for saved items, in tab 1, 1 column wide
	create_set("Built-in stuff", 1, 1)
	create_set("Your saved stuff", 1, 1)
	# load the users buildings into the set
	populate_saved_stuff(true)
	populate_saved_stuff(false)

func populate_saved_stuff(internal : bool = false) -> void:
	var load_dir : DirAccess = null
	var file_name := "null"
	if !load_dir:
		if internal:
			load_dir = DirAccess.open("res://data/building")
		else:
			load_dir = DirAccess.open("user://building")
	if load_dir:
		load_dir.list_dir_begin()
		while file_name != "":
			file_name = load_dir.get_next()
			if file_name != "":
				var item_button : Button = item_chooser_button.instantiate()
				# node name is internal name
				item_button.name = str("building;", file_name)
				item_button.text = file_name
				if internal:
					item_button.tooltip_text = "This is from the built-in set."
				else:
					item_button.tooltip_text = "This is one of your saved buildings."
				var user_img_dir := "res://data/building_scr"
				if !internal:
					user_img_dir = "user://building_scr"
				# load image
				var scrdir := DirAccess.open(user_img_dir)
				if scrdir:
					var image := Image.load_from_file(str(user_img_dir, "/", file_name.split(".")[0], ".jpg"))
					if image != null:
						# 16:9
						image.resize(113, 64);
						var texture := ImageTexture.create_from_image(image)
						item_button.icon = texture
				if internal:
					add_to_set("Built-in stuff", item_button, 1)
				else:
					add_to_set("Your saved stuff", item_button, 1)

func _on_item_chosen(internal_name : String, display_name : String) -> void:
	emit_signal("item_picked", internal_name, display_name)

func show_item_chooser() -> void:
	list.visible = true
	saved_list.visible = true

func hide_item_chooser() -> void:
	list.visible = false
	saved_list.visible = false

func get_item_chooser_visible() -> bool:
	return list.visible
