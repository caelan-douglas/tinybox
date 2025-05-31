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
var respawn_time : int = 5
@export var songs : Array = MusicHandler.ALL_SONGS_LIST.duplicate()
var _song_line : String = ""

@rpc("any_peer", "call_local", "reliable")
func set_songs(line : String) -> void:
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != get_multiplayer_authority() && multiplayer.get_remote_sender_id() != 0:
		return
	if line != "":
		songs = JSON.parse_string(str(line).split(" ; ")[1])
	else:
		songs = []
	_song_line = line

# set fallback values for loading new world before properties are set
func reset_map_properties() -> void:
	# set default gravity
	set_gravity_scale.rpc(1.0)
	set_gravity.rpc(false)
	
	death_limit_low = 20
	death_limit_high = 400
	respawn_time = 5
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
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)

# runs as server
func _on_peer_connected(id : int) -> void:
	set_gravity_scale.rpc_id(id, gravity_scale)
	set_respawn_time.rpc_id(id, respawn_time)
	set_gravity.rpc_id(id, false)
	set_songs.rpc_id(id, _song_line)

@rpc ("authority", "call_local", "reliable")
func set_gravity_scale(value : float) -> void:
	# only server or auth can change this
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0 && multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	
	gravity_scale = value

@rpc ("authority", "call_local", "reliable")
func set_respawn_time(value : float) -> void:
	# only server or auth can change this
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0 && multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	
	respawn_time = value

@rpc ("authority", "call_local", "reliable")
func set_gravity(low_grav : bool = false) -> void:
	# only server or auth can change this
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0 && multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	
	if low_grav == false:
		PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, 9.8 * gravity_scale)
	else:
		PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, 9.8 * 0.5)
