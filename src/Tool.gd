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

extends Node3D
class_name Tool

var ui_partner : Control = null
var ui_tool_name := ""
var ui_shortcut : int = -1
var tool_player_owner : RigidPlayer = null
var ui_button : PackedScene = preload("res://data/scene/ui/ToolButton.tscn")
var disabled := false
var active := false
var deleting := false
var tool_inventory : ToolInventory = null

enum ToolType {
	PLAYER,
	EDITOR
}

var visual_mesh : PackedScene = null
@export var visual_mesh_name := ""
@export var lock_camera_to_aim := false
@export var type : ToolType = ToolType.PLAYER
var tool_visual : Node3D = null
var visual_mesh_instance : Node3D = null

# Visual helper overlay for GameCanvas UI
var tool_overlay : Control = null
	
# Function for initializing this tool.
# Arg 1: The name of this tool.
# Arg 2: The player who owns this tool. If null, will be considered an editor
# tool.
func init(tool_name : String, player_owner : RigidPlayer = null) -> void:
	if player_owner != null:
		set_multiplayer_authority(player_owner.get_multiplayer_authority())
		tool_player_owner = player_owner
		tool_visual = tool_player_owner.get_node("Smoothing/character_model/character/Skeleton3D/ToolVisual")
		if visual_mesh_name != "":
			visual_mesh = load(str("res://data/scene/tool/visual_mesh/", visual_mesh_name, ".tscn"))
		tool_inventory = tool_player_owner.get_tool_inventory()
	else:
		type = ToolType.EDITOR
		tool_inventory = get_parent()
	# set the name of the tool for the ui
	ui_tool_name = tool_name
	# only execute on yourself
	if !is_multiplayer_authority(): return
	# Spawn new button for owner of this tool.
	ui_partner = ui_button.instantiate()
	# Add tool to UI list.
	add_ui_partner()
	ui_partner.connect("pressed", set_tool_active.bind(true, true))
	Global.connect("keybinds_changed", update_tool_number)
	update_tool_number()
	# for updating tool being held when a player joins
	multiplayer.peer_connected.connect(_on_peer_connected)

# only runs on auth
func _on_peer_connected(id : int) -> void:
	if active:
		show_tool_visual.rpc_id(id, true)

func add_ui_partner() -> void:
	if type == ToolType.PLAYER:
		get_tree().current_scene.get_node("GameCanvas/ToolList").add_child(ui_partner)
	else:
		get_tree().current_scene.get_node("EditorCanvas/ToolList").add_child(ui_partner)
	ui_partner.text = str(ui_tool_name)

func update_tool_number() -> void:
	if !is_multiplayer_authority(): return
	
	# first try to load a saved preferred key - saved by tool name
	var loaded_key_result : Variant = UserPreferences.load_pref(str("keybind_", name), "keybinds")
	if loaded_key_result != null:
		var loaded_key : String = str(loaded_key_result)
		# special case for mouse button
		if loaded_key == "MMB":
			ui_shortcut = MOUSE_BUTTON_MIDDLE
		else:
			ui_shortcut = OS.find_keycode_from_string(loaded_key)
		ui_partner.get_node("NumberLabel").text = loaded_key
	else:
		var tool_inv_index : int = tool_inventory.get_index_of_tool(self)
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
	tool_inventory.arrange_tools()

# Handle the UI and tool selection.
func _unhandled_input(event : InputEvent) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	if ui_shortcut != null:
		# only can be used when not disabled
		if (event is InputEventKey) && !disabled:
			if event.pressed and event.keycode == ui_shortcut:
				set_tool_active(!get_tool_active())
		elif (event is InputEventMouseButton) && !disabled:
			if event.pressed and event.button_index == ui_shortcut:
				set_tool_active(!get_tool_active())

@rpc("call_local")
func show_tool_visual(mode : bool) -> void:
	if mode == true:
		# check if visual mesh is null for rpc recievers
		if visual_mesh != null:
			add_visual_mesh_instance()
			if tool_player_owner:
				var tween : Tween = get_tree().create_tween()
				tween.tween_property(tool_player_owner.animator as AnimationMixer, "parameters/BlendTool/blend_amount", 1.0, 0.2)
	else:
		for c in tool_visual.get_children():
			c.queue_free()
		visual_mesh_instance = null
		if tool_player_owner:
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(tool_player_owner.animator as AnimationMixer, "parameters/BlendTool/blend_amount", 0.0, 0.2)

func add_visual_mesh_instance() -> void:
	visual_mesh_instance = visual_mesh.instantiate()
	tool_visual.add_child(visual_mesh_instance)

func get_tool_active() -> bool:
	return active

func set_tool_active(mode : bool, from_click : bool = false, free_camera_on_inactive : bool = true) -> void:
	if !is_multiplayer_authority(): return
	active = mode
	if type == ToolType.PLAYER:
		# Enable/disable tool helper UI.
		if tool_overlay != null:
			tool_overlay.visible = mode
	var camera : Camera3D = get_viewport().get_camera_3d()
	if mode == true:
		# disable other tools
		for t : Tool in tool_inventory.get_tools():
			if t != self:
				if t.get_tool_active() == true:
					t.set_tool_active(false, false, false)
		if !from_click:
			if ui_partner != null:
				ui_partner.button_pressed = true
		# Player tool specifics
		if type == ToolType.PLAYER:
			if camera is Camera:
				if lock_camera_to_aim:
					camera.set_mode_locked(true, Camera.CameraMode.AIM)
				else:
					# if the player specifically requested aim mode with right click
					# don't switch to free when the tool is deselected
					if camera.player_requested_aim_mode:
						camera.set_mode_locked(false, Camera.CameraMode.AIM)
					else:
						camera.set_mode_locked(false, Camera.CameraMode.FREE)
			if visual_mesh != null:
				show_tool_visual.rpc(true)
	else:
		if type == ToolType.PLAYER:
			if lock_camera_to_aim && free_camera_on_inactive && camera is Camera:
				# if the player specifically requested aim mode with right click
				# don't switch to free when the tool is deselected
				if camera.player_requested_aim_mode:
					camera.set_mode_locked(false, Camera.CameraMode.AIM)
				else:
					camera.set_mode_locked(false, Camera.CameraMode.FREE)
			show_tool_visual.rpc(false)
		if !from_click:
			ui_partner.button_pressed = false

func set_disabled(new : bool) -> void:
	if !is_multiplayer_authority(): return
	
	disabled = new
	ui_partner.disabled = new
	if new == true && get_tool_active():
		set_tool_active(false)

func delete() -> void:
	if !is_multiplayer_authority() || type == ToolType.EDITOR: return
	
	if !deleting:
		deleting = true
		set_tool_active(false)
		tool_player_owner.get_tool_inventory().remove_child(self)
		tool_player_owner.get_tool_inventory().arrange_tools()
		for t : Tool in tool_player_owner.get_tool_inventory().get_tools():
			t.update_tool_number()
		ui_partner.queue_free()
		call_deferred("queue_free")
