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
var editing_hovered : bool = false:
	set(value):
		$Panel/Editing.visible = value
		editing_hovered = value
	get:
		return editing_hovered

var copied_properties : Dictionary = {}

@onready var editor_props_list : VBoxContainer = get_node("Panel/Menu")
@onready var copy_button : Button = get_node("Panel/Copy")

func _ready() -> void:
	copy_button.connect("pressed", _on_copy_pressed)

func show_grab_actions(grabbed : Array, from_tool : EditorBuildTool) -> void:
	clear_list()
	
	var grab_label := Label.new()
	grab_label.text = str("Grabbed " , grabbed.size(), " things.")
	editor_props_list.add_child(grab_label)
	
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	editor_props_list.add_child(spacer)
	
	var save_lineedit := LineEdit.new()
	save_lineedit.placeholder_text = "Save name"
	from_tool.save_grabbed_name_lineedit = save_lineedit
	editor_props_list.add_child(save_lineedit)
	
	var save_button := DynamicButton.new()
	save_button.text = "Save grabbed things"
	save_button.connect("pressed", from_tool.save_grabbed)
	editor_props_list.add_child(save_button)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 16
	editor_props_list.add_child(spacer)
	
	var del_button := DynamicButton.new()
	del_button.text = "Delete grabbed things"
	del_button.self_modulate = Color.RED
	del_button.connect("pressed", from_tool.delete_grabbed)
	editor_props_list.add_child(del_button)

func _on_copy_pressed() -> void:
	copied_properties = selected_item_properties
	copy_button.text = JsonHandler.find_entry_in_file("ui/editor/copied")
	await get_tree().create_timer(1).timeout
	copy_button.text = JsonHandler.find_entry_in_file("ui/editor/copy_properties")

# Lists an object's properties
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

# Clears the property editor panel
func clear_list() -> void:
	selected_item_properties = {}
	for child : Node in editor_props_list.get_children():
		child.queue_free()
	copy_button.disabled = true

# Relists the existing properties of an given tool. (ie, when one tool is
# switched to another)
func relist_object_properties(properties : Dictionary,  _properties_from_tool : Node) -> void:
	properties_from_tool = _properties_from_tool
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
# Adds a corresponding UI entry for a given property.
func add_object_property_entry(prop_name : String, prop : Variant) -> void:
	selected_item_properties[prop_name] = prop
	var entry : Control = null
	# Add colour picker
	if prop is Color:
		entry = colour_picker.instantiate()
		entry.get_node("ColorPickerButton").color = prop
		entry.get_node("ColorPickerButton").connect("color_changed", update_object_property.bind(prop_name))
	
	# add checkbox
	if prop is bool:
		entry = CheckBox.new()
		entry.text = prop_name.capitalize()
		entry.button_pressed = prop as bool
		entry.connect("toggled", update_object_property.bind(prop_name))
		# special tooltips for some properties
		if prop_name == "immovable":
			entry.tooltip_text = JsonHandler.find_entry_in_file("property_tooltips/immovable")
		elif prop_name == "joinable":
			entry.tooltip_text = JsonHandler.find_entry_in_file("property_tooltips/joinable")
		elif prop_name == "indestructible":
			entry.tooltip_text = JsonHandler.find_entry_in_file("property_tooltips/indestructible")
	
	# Add adjuster for floats and ints
	if prop is float || prop is int:
		if prop_name == "_material":
			entry = option_picker.instantiate()
			entry.get_node("Label").text = "Brick material"
			var mat_option_picker : OptionButton = entry.get_node("Event")
			for brick_name : String in Brick.BRICK_MATERIALS_AS_STRINGS:
				mat_option_picker.add_item(brick_name)
			# brick mat is an int so we can just use selected option as the new prop value
			mat_option_picker.connect("item_selected", update_object_property.bind(prop_name))
			mat_option_picker.selected = prop
		# pickup types
		elif prop_name == "type":
			entry = option_picker.instantiate()
			entry.get_node("Label").text = "Pickup type"
			var type_option_picker : OptionButton = entry.get_node("Event")
			for pickup_type : String in Pickup.PICKUP_TYPES_AS_STRINGS:
				type_option_picker.add_item(pickup_type)
			# pickup type is an int so we can just use selected option as the new prop value
			type_option_picker.connect("item_selected", update_object_property.bind(prop_name))
			type_option_picker.selected = prop
		# checkpoint types
		elif prop_name == "checkpoint":
			entry = option_picker.instantiate()
			entry.get_node("Label").text = "Checkpoint"
			var chk_option_picker : OptionButton = entry.get_node("Event")
			for chk_name : String in SpawnPoint.CHECKPOINT_TYPES_AS_STRINGS:
				chk_option_picker.add_item(chk_name)
			# brick mat is an int so we can just use selected option as the new prop value
			chk_option_picker.connect("item_selected", update_object_property.bind(prop_name))
			chk_option_picker.selected = prop
		# motor control tags
		elif prop_name == "tag":
			entry = option_picker.instantiate()
			entry.get_node("Label").text = "Tag"
			var mtr_option_picker : OptionButton = entry.get_node("Event")
			for mtr_name : String in MotorController.MOTOR_TAGS_AS_STRINGS:
				mtr_option_picker.add_item(mtr_name)
			# brick mat is an int so we can just use selected option as the new prop value
			mtr_option_picker.connect("item_selected", update_object_property.bind(prop_name))
			mtr_option_picker.selected = prop
		else:
			entry = adjuster.instantiate()
			var label : Label = entry.get_node("DynamicLabel")
			# format string (ex. "target_speed" to "Target speed")
			label.text = str(formatted_prop_name(prop_name), ": ", prop)
			entry.val = prop as int
			entry.connect("value_changed", update_object_property.bind(prop_name, false, label))
	
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
		else:
			entry = text_editor.instantiate()
			var text : TextEdit = entry.get_node("TextEdit")
			var save_button : Button = entry.get_node("Save")
			text.text = str(prop)
			save_button.connect("pressed", _update_object_property_from_text_instance.bind(text, prop_name))
		
	if entry != null:
		editor_props_list.add_child(entry)
	copy_button.disabled = false

# Convert team index to team name for saving.
func _update_object_property_team(new_value : Variant, prop_name : String) -> void:
	update_object_property(Global.get_world().get_current_map().get_teams().get_team_name_by_index(new_value as int), prop_name)

# For connecting buttons.
func _update_object_property_select_brick(prop_name : String, button_from : Button) -> void:
	var editor : Map = Global.get_world().get_current_map()
	if editor is Editor:
		var selected_brick : Brick = await editor.select_brick()
		if selected_brick != null:
			update_object_property(str(selected_brick.get_path()), prop_name)

# For updating text properties from the panel.
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
			update_label.text = str(formatted_prop_name(prop_name), ": ", selected_item_properties[prop_name])
	emit_signal("property_updated", selected_item_properties)

func formatted_prop_name(what : String) -> String:
	return what.replace("_", " ").capitalize()
