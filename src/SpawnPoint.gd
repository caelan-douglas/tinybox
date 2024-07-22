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

extends TBWObject
class_name SpawnPoint

@onready var area : Area3D = $Area3D
var team_name : String = "Default"

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "scale", "team_name"]

func occupied() -> bool:
	for b in area.get_overlapping_bodies():
		if b is RigidPlayer:
			return true
	return false
