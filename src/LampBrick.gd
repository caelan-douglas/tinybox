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

extends Brick

@onready var light : OmniLight3D = $Smoothing/OmniLight3D

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	super(new)
	if light != null:
		light.set("light_color", new)

@rpc("call_local")
func set_glued(new : bool, affect_others : bool = true) -> void:
	super(new, affect_others)
	if light != null:
		light.visible = false