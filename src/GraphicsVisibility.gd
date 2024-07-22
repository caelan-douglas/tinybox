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
class_name GraphicsVisibility

@export var visible_on_cool := true
@export var visible_on_bad := true
@export var visible_on_awful := true

func _ready() -> void:
	Global.connect("graphics_preset_changed", _on_graphics_preset_changed)
	_on_graphics_preset_changed()

func _on_graphics_preset_changed() -> void:
	match (Global.get_graphics_preset()):
		Global.GraphicsPresets.COOL:
			if name == "DirectionalLight3D":
				set("shadow_enabled", visible_on_cool)
			else:
				visible = visible_on_cool
		Global.GraphicsPresets.BAD:
			if name == "DirectionalLight3D":
				set("shadow_enabled", visible_on_bad)
			else:
				visible = visible_on_bad
		Global.GraphicsPresets.AWFUL:
			if name == "DirectionalLight3D":
				set("shadow_enabled", visible_on_awful)
			else:
				visible = visible_on_awful
