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

extends GraphicsVisibility

@onready var camera : Camera3D = get_viewport().get_camera_3d()

func _ready() -> void:
	super()

func _process(delta : float) -> void:
	if camera != null:
		global_position = Vector3(camera.global_position.x, camera.global_position.y + 3, camera.global_position.z)
