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
class_name EditorToolInventory

var disabled := false
var last_held_tool : EditorTool = null

func _process(delta : float) -> void:
	if !disabled && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED && (Input.is_action_just_pressed("switch_tool_right") || Input.is_action_just_pressed("switch_tool_left")) && !Input.is_action_pressed("control"):
		var active_tool : EditorTool = get_active_tool()
		if active_tool == null:
			if Input.is_action_just_pressed("switch_tool_left"):
				get_tools()[get_tools().size() - 1].set_tool_active(true)
			else:
				get_tools()[0].set_tool_active(true)
		else:
			var active_tool_idx : int = get_index_of_tool(active_tool)
			if Input.is_action_just_pressed("switch_tool_right"):
				active_tool_idx += 1
				if active_tool_idx >= get_tools().size():
					# rollover to first tool active
					get_tools()[0].set_tool_active(true)
					return
			else:
				active_tool_idx -= 1
				if active_tool_idx < 0:
					# rollover to last tool active
					get_tools()[get_tools().size() - 1].set_tool_active(true)
					return
			get_tools()[active_tool_idx].set_tool_active(true)

func arrange_tools() -> void:
	var tool_list : Control = get_tree().current_scene.get_node("EditorCanvas/ToolList")
	if get_tools().size() == tool_list.get_children().size():
		get_tools().sort_custom(_arrange_tools_by_ui_shortcut)
		# remove unsorted ui elements
		for item in tool_list.get_children():
			tool_list.remove_child(item)
		# ask each tool (now in order) to re-add their ui element
		for t : EditorTool in get_tools():
			t.add_ui_partner()

func set_disabled(new : bool, delay : float = -1) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	if disabled != new:
		disabled = new
		# if setting disabled, take note of the active tool
		if new == true:
			last_held_tool = get_active_tool()
			for t : EditorTool in get_tools():
				t.set_tool_active(false)
		# restore held tool
		elif new == false && last_held_tool != null:
			last_held_tool.set_tool_active(true)
		for t : EditorTool in get_tools():
			if t.has_method("set_disabled"):
				t.set_disabled(new)

func _arrange_tools_by_ui_shortcut(a : EditorTool, b : EditorTool) -> bool:
	if a.ui_shortcut < b.ui_shortcut:
		return true
	return false

# Get all the tools in this inventory.
func get_tools() -> Array:
	return get_children()

func get_active_tool() -> EditorTool:
	for t : EditorTool in get_tools():
		if t.get_tool_active() == true:
			return t
	return null

func has_tool_by_name(name : String) -> EditorTool:
	for t : EditorTool in get_tools():
		if t.name == name:
			return t
	return null

# Add a new tool to this tool inventory.
func add_tool(tool : Tool) -> void:
	if !get_tools().has(tool):
		add_child(tool)

# get the index of a tool in a list.
func get_index_of_tool(tool : EditorTool) -> int:
	# count each tool in inventory
	for i in range(get_tools().size()):
		if get_tools()[i] == tool:
			# return index of this tool
			return i
	# tool is not in this inventory
	return -1
