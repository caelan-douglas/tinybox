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
class_name Map

@export var gravity_scale := 1.0
var death_limit_low : int = 20
var death_limit_high : int = 400
var songs : Array = MusicHandler.ALL_SONGS_LIST.duplicate()

func reset_map_properties() -> void:
	gravity_scale = 1.0
	death_limit_low = 20
	death_limit_high = 400
	songs = MusicHandler.ALL_SONGS_LIST.duplicate()

func set_song(mode : bool, song_name : String) -> void:
	if mode == true:
		if !songs.has(song_name):
			songs.append(song_name)
			MusicHandler.switch_song(songs)
	else:
		if songs.has(song_name):
			songs.erase(song_name)
			MusicHandler.switch_song(songs)

# Return the teams node for this map
func get_teams() -> Teams:
	return get_node_or_null("Teams")

func _ready() -> void:
	# set song
	# wait for music / server setting to load if on main menu
	await get_tree().create_timer(0.2).timeout
	MusicHandler.switch_song(songs)
	# Modify default gravity
	if !self is Editor:
		set_low_grav(false)

func set_low_grav(mode : bool = false) -> void:
	if mode == false:
		PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, 9.8 * gravity_scale)
	else:
		PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, 9.8 * 0.5)
