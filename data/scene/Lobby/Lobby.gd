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

extends Map
class_name Lobby

enum GameWinCondition {
	BASE_DEFENSE,
	DEATHMATCH,
	TEAM_DEATHMATCH,
	KINGS
}

func _ready() -> void:
	var camera : Camera3D = get_viewport().get_camera_3d()
	camera.locked = true
	camera.global_position = Vector3(0, 52, 4)
	camera.global_rotation_degrees = Vector3(-10, 0, 0)
	super()
	# when map is initalized, set graphics on world
	get_parent().get_parent()._on_graphics_preset_changed()
	# move players when lobby is initialized
	var player : RigidPlayer = Global.get_player()
	if player:
		player.change_state(RigidPlayer.DUMMY)
	UIHandler.show_lobby_menu()
	Global.get_world().clear_world()
