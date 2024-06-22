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

extends Tool
class_name PaintbrushTool

var colours : Array[Color] = [Color.WHITE, 
Color.CRIMSON, 
Color.DARK_RED, 
Color.CORAL, 
Color.ORANGE, 
Color.YELLOW, 
Color.LIGHT_GREEN, 
Color.DARK_GREEN, 
Color.CADET_BLUE, 
Color.ROYAL_BLUE, 
Color.MIDNIGHT_BLUE, 
Color.INDIGO, 
Color.PURPLE, 
Color.PINK, 
Color.BLACK]

var _selected_colour_idx : int = 0

func _ready() -> void:
	# Create new tool.
	super.init("Paintbrush", get_parent().get_parent() as RigidPlayer)
	tool_overlay = get_tree().current_scene.get_node_or_null("GameCanvas/ToolOverlay/PaintbrushTool")

func _process(delta : float) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	# If the tool is active (ui partner selected)
	if get_tool_active():
		if Input.is_action_just_pressed("paintbrush_next_colour") || Input.is_action_just_pressed("paintbrush_prev_colour"):
			if Input.is_action_just_pressed("paintbrush_next_colour"):
				_selected_colour_idx += 1
				if _selected_colour_idx >= colours.size():
					_selected_colour_idx = 0
			if Input.is_action_just_pressed("paintbrush_prev_colour"):
				_selected_colour_idx -= 1
				if _selected_colour_idx < 0:
					_selected_colour_idx = colours.size() - 1
			if tool_overlay != null:
				tool_overlay.get_node("SelectedColour").color = colours[_selected_colour_idx]
		if Input.is_action_pressed("click"):
			# get mouse position in 3d space
			var m_3d : Dictionary = get_viewport().get_camera_3d().get_mouse_pos_3d()
			var m_pos_3d := Vector3()
			# we must check if the mouse's ray is not hitting anything
			if m_3d:
				# if it is hitting something
				m_pos_3d = m_3d["position"] as Vector3
			if m_3d:
				# if we are hovering a brick and we are NOT auth
				if (m_3d["collider"] is Brick && (m_3d["collider"].get_multiplayer_authority() != get_multiplayer_authority())) || (m_3d["collider"].get_parent() is Brick && (m_3d["collider"].get_parent().get_multiplayer_authority() != get_multiplayer_authority())):
					var hov_brick : Node3D = m_3d["collider"] as Node3D
					if m_3d["collider"].get_parent() is Brick:
						hov_brick = m_3d["collider"].get_parent() as Brick
					hov_brick.set_colour.rpc(colours[_selected_colour_idx])
				# if we ARE auth
				elif m_3d["collider"].owner is Brick && (m_3d["collider"].owner.get_multiplayer_authority() == get_multiplayer_authority()):
					var brick : Brick = m_3d["collider"].owner
					brick.set_colour.rpc(colours[_selected_colour_idx])
