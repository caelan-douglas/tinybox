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

extends EditorTool

func _ready() -> void:
	init("World properties")

func add_ui_partner() -> void:
	super.add_ui_partner()
	ui_partner.self_modulate = Color(0.6, 0.5, 2.3)

func set_tool_active(mode : bool, from_click : bool = false) -> void:
	super(mode, from_click)
	
	var properties_panel : Control = get_tree().current_scene.get_node("EditorCanvas/WorldProperties")
	properties_panel.visible = mode
	if properties_panel.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
