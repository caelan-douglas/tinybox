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
class_name ToolInventory

var last_held_tool : Tool = null
# resets after 10 frames
var tool_just_holding : Tool = null
var disabled := false

var all_tools : Array[PackedScene] = [preload("res://data/scene/tool/BuildTool.tscn"),\
preload("res://data/scene/tool/BouncyballTool.tscn"),\
preload("res://data/scene/tool/BatTool.tscn"),\
preload("res://data/scene/tool/ExtinguisherTool.tscn"),\
preload("res://data/scene/tool/RocketTool.tscn"),\
preload("res://data/scene/tool/BombTool.tscn"),\
preload("res://data/scene/tool/FlamethrowerTool.tscn"),\
preload("res://data/scene/tool/MissileTool.tscn"),\
preload("res://data/scene/tool/PaintbrushTool.tscn")]

var hold_timer := 0

func _process(delta : float) -> void:
	if !disabled && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED && get_tools().size() > 0 &&(Input.is_action_just_pressed("switch_tool_right") || Input.is_action_just_pressed("switch_tool_left")):
		var active_tool : Tool = get_active_tool()
		if active_tool == null:
			# shift-scroll zooms camera
			if Input.is_action_just_pressed("switch_tool_left") && !(Input.is_action_pressed("control")):
				get_tools()[get_tools().size() - 1].set_tool_active(true)
			elif !Input.is_action_pressed("control"):
				get_tools()[0].set_tool_active(true)
		else:
			var active_tool_idx : int = get_index_of_tool(active_tool)
			# shift-scroll zooms camera
			if Input.is_action_just_pressed("switch_tool_right") && !Input.is_action_pressed("control"):
				active_tool_idx += 1
				if active_tool_idx >= get_tools().size():
					get_active_tool().set_tool_active(false)
					return
			elif !Input.is_action_pressed("control"):
				active_tool_idx -= 1
				if active_tool_idx < 0:
					get_active_tool().set_tool_active(false)
					return
			get_tools()[active_tool_idx].set_tool_active(true)
	if hold_timer > 0:
		hold_timer -= 1
		# when holdtimer reaches 0, reset tool just holding
		if hold_timer < 1:
			tool_just_holding = null

func set_disabled(new : bool, delay : float = -1) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	if disabled != new:
		disabled = new
		# if setting disabled, take note of the active tool
		if new == true:
			last_held_tool = get_active_tool()
			# set "just holding" tool
			tool_just_holding = get_active_tool()
			hold_timer = 10
		# restore held tool
		elif new == false && last_held_tool != null:
			last_held_tool.set_tool_active(true)
		for t : Tool in get_tools():
			if t.has_method("set_disabled"):
				t.set_disabled(new)

func arrange_tools() -> void:
	var tool_list : Control = get_tree().current_scene.get_node("GameCanvas/ToolList")
	if get_tools().size() == tool_list.get_children().size():
		get_tools().sort_custom(_arrange_tools_by_ui_shortcut)
		# remove unsorted ui elements
		for item in tool_list.get_children():
			tool_list.remove_child(item)
		# ask each tool (now in order) to re-add their ui element
		for t : Tool in get_tools():
			t.add_ui_partner()
			if t is ShootTool:
				t.update_ammo_display()

func _arrange_tools_by_ui_shortcut(a : Tool, b : Tool) -> bool:
	if a.ui_shortcut < b.ui_shortcut:
		return true
	return false

# Get all the tools in this inventory.
func get_tools() -> Array:
	return get_children()

func get_active_tool() -> Tool:
	for t : Tool in get_tools():
		if t.get_tool_active() == true:
			return t
	return null

func has_tool_by_name(name : String) -> Tool:
	for t : Tool in get_tools():
		if t.name == name:
			return t
	return null

# Add a new tool to this tool inventory.
func add_tool(tool : Tool) -> void:
	if !get_tools().has(tool):
		add_child(tool, true)

# get the index of a tool in a list.
func get_index_of_tool(tool : Tool) -> int:
	# count each tool in inventory
	for i in range(get_tools().size()):
		if get_tools()[i] == tool:
			# return index of this tool
			return i
	# tool is not in this inventory
	return -1

func delete_all_tools() -> void:
	for t : Tool in get_tools():
		t.delete()

func give_all_tools() -> void:
	for at : PackedScene in all_tools:
		add_tool(at.instantiate() as Tool)

func give_base_tools() -> void:
	add_tool(all_tools[1].instantiate() as Tool)
	add_tool(all_tools[2].instantiate() as Tool)

# resets inventory to default (sandbox) state (all tools in def. states)
func reset() -> void:
	delete_all_tools()
	give_all_tools()
