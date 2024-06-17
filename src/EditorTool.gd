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

extends Node
class_name EditorTool

var ui_partner
var ui_tool_name = ""
var ui_shortcut = null
var ui_button = preload("res://data/scene/ui/EditorToolButton.tscn")
var active = false

# Function for initializing this tool.
# Arg 1: The name of this tool.
# Arg 2: The player who owns this tool.
func init(tool_name : String) -> void:
	# set the name of the tool for the ui
	ui_tool_name = tool_name
	# Spawn new button for owner of this tool.
	ui_partner = ui_button.instantiate()
	# Add tool to UI list.
	add_ui_partner()
	ui_partner.connect("pressed", set_tool_active.bind(true, true))
	update_tool_number()

func add_ui_partner() -> void:
	get_tree().current_scene.get_node("EditorCanvas/ToolList").add_child(ui_partner)
	ui_partner.text = str(ui_tool_name)

func update_tool_number() -> void:
	var tool_inv_index = get_parent().get_index_of_tool(self)
	ui_partner.get_node("NumberLabel").text = str(((tool_inv_index + 1) % 10))
	match(tool_inv_index):
		0:
			ui_shortcut = KEY_1
		1:
			ui_shortcut = KEY_2
		2:
			ui_shortcut = KEY_3
		3:
			ui_shortcut = KEY_4
		4:
			ui_shortcut = KEY_5
		5:
			ui_shortcut = KEY_6
		6:
			ui_shortcut = KEY_7
		7:
			ui_shortcut = KEY_8
		8:
			ui_shortcut = KEY_9
		9:
			ui_shortcut = KEY_0
	# re-arrange tool list
	get_parent().arrange_tools()

# Handle the UI and tool selection.
func _unhandled_input(event) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	if ui_shortcut != null:
		# only can be used when not disabled
		if (event is InputEventKey):
			if event.pressed and event.keycode == ui_shortcut:
				set_tool_active(!get_tool_active())
		elif (event is InputEventMouseButton):
			if event.pressed and event.button_index == ui_shortcut:
				set_tool_active(!get_tool_active())

func get_tool_active():
	if !is_multiplayer_authority(): return
	return active

func set_tool_active(mode : bool, from_click : bool = false) -> void:
	if !is_multiplayer_authority(): return
	
	active = mode
	if mode == true:
		# disable other tools
		for t in get_parent().get_tools():
			if t != self:
				if t.get_tool_active() == true:
					t.set_tool_active(false, false)
		
		if !from_click:
			if ui_partner != null:
				ui_partner.button_pressed = true
	else:
		if !from_click:
			ui_partner.button_pressed = false
