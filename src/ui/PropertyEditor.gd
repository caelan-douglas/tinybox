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
class_name PropertyEditor
signal property_updated(properties : Dictionary)

var selected_item_properties : Dictionary = {}
var properties_from_tool : Node = null

@onready var editor_props_list : VBoxContainer = get_node("Menu")

## Lists an object's properties
func list_object_properties(instance : Node, _properties_from_tool : Node) -> Dictionary:
	properties_from_tool = _properties_from_tool
	selected_item_properties = {}
	for child : Node in editor_props_list.get_children():
		child.queue_free()
	if instance is Brick || instance is TBWObject:
		for prop_name : String in instance.properties_to_save:
			# don't list pos rot or scale
			if prop_name != "global_position" && prop_name != "global_rotation" && prop_name != "scale":
				var prop : Variant = instance.get(prop_name)
				add_object_property_entry(prop_name, prop)
	return selected_item_properties

func clear_list() -> void:
	selected_item_properties = {}
	for child : Node in editor_props_list.get_children():
		child.queue_free()

func relist_object_properties(properties : Dictionary) -> void:
	# delete current list
	clear_list()
	# set to new property list
	selected_item_properties = properties
	# reload list
	for property : String in selected_item_properties.keys():
		add_object_property_entry(property, selected_item_properties[property])

var colour_picker : PackedScene = preload("res://data/scene/ui/ColourPicker.tscn")
var adjuster : PackedScene = preload("res://data/scene/ui/Adjuster.tscn")
var text_editor : PackedScene = preload("res://data/scene/ui/TextEditor.tscn")
var option_picker : PackedScene = preload("res://data/scene/ui/OptionPicker.tscn")
func add_object_property_entry(prop_name : String, prop : Variant) -> void:
	selected_item_properties[prop_name] = prop
	var entry : Control = null
	# Add colour picker
	if prop is Color:
		entry = colour_picker.instantiate()
		entry.get_node("ColorPickerButton").color = prop
		entry.get_node("ColorPickerButton").connect("color_changed", update_object_property.bind(prop_name))
		
	# Add adjuster for floats and ints, event editor for events
	if prop is float || prop is int:
		if prop_name == "event":
			entry = option_picker.instantiate()
			var event_option_picker : OptionButton = entry.get_node("Event")
			for event_type : String in EventHandler.event_types_readable:
				event_option_picker.add_item(event_type)
				# when a new item is selected, set the option button's index as the
				# selected event type
				event_option_picker.connect("item_selected", update_object_property.bind(prop_name))
			event_option_picker.selected = prop
		else:
			entry = adjuster.instantiate()
			var label : Label = entry.get_node("DynamicLabel")
			label.text = str(prop_name, ": ", prop)
			entry.get_node("DownBig").connect("pressed", update_object_property.bind(-10, prop_name, true, label))
			entry.get_node("Down").connect("pressed", update_object_property.bind(-1, prop_name, true, label))
			entry.get_node("Up").connect("pressed", update_object_property.bind(1, prop_name, true, label))
			entry.get_node("UpBig").connect("pressed", update_object_property.bind(10, prop_name, true, label))
	
	# Add line editor
	if prop is String:
		if prop_name == "team_name":
			entry = option_picker.instantiate()
			# set label above picker to say "Team"
			entry.get_node("Label").text = "Pick a team..."
			var team_option_picker : OptionButton = entry.get_node("Event")
			for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
				team_option_picker.add_item(team.name)
				# when a new item is selected, set the option button's index as the
				# selected event type
				team_option_picker.connect("item_selected", _update_object_property_team.bind(prop_name))
			# get index of team in world and set the selected option to that
			team_option_picker.selected = Global.get_world().get_current_map().get_teams().get_team_index(str(prop))
		elif prop_name == "connection":
			entry = Button.new()
			entry.text = "Connect button to brick..."
			entry.connect("pressed", _update_object_property_select_brick.bind(prop_name, entry))
		else:
			entry = text_editor.instantiate()
			var text : TextEdit = entry.get_node("TextEdit")
			var save_button : Button = entry.get_node("Save")
			text.text = str(prop)
			save_button.connect("pressed", _update_object_property_from_text_instance.bind(text, prop_name))
		
	if entry != null:
		editor_props_list.add_child(entry)

# convert team index to team name for saving
func _update_object_property_team(new_value : Variant, prop_name : String) -> void:
	update_object_property(Global.get_world().get_current_map().get_teams().get_team_name_by_index(new_value as int), prop_name)

func _update_object_property_select_brick(prop_name : String, button_from : Button) -> void:
	var editor : Map = Global.get_world().get_current_map()
	if editor is Editor:
		button_from.text = "Choose a brick."
		var selected_brick : Brick = await editor.select_brick()
		button_from.text = "Connect button to brick..."
		if selected_brick != null:
			update_object_property(str(selected_brick.get_path()), prop_name)

func _update_object_property_from_text_instance(instance : TextEdit, prop_name : String) -> void:
	var text : String = instance.text
	update_object_property(text, prop_name)

func update_object_property(new_value : Variant, prop_name : String, increment : bool = false, update_label : Label = null) -> void:
	if selected_item_properties.has(prop_name):
		if increment:
			selected_item_properties[prop_name] += new_value
		else:
			selected_item_properties[prop_name] = new_value
		if update_label:
			update_label.text = str(prop_name, ": ", selected_item_properties[prop_name])
	print("Updated object property:\n", selected_item_properties)
	emit_signal("property_updated", selected_item_properties)