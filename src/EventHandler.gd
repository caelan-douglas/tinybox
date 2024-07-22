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

extends Node

enum Event {
	TELEPORT_PLAYER,
	EXPLODE,
	CHANGE_PLAYER_TEAM
}

# same order as enum
var event_types_readable : Array[String] = ["Teleport player", "Explode", "Change player team"]

@rpc("any_peer", "call_local", "reliable")
func run_event(event_type : Event, args : Array) -> void:
	# only server runs events
	if !multiplayer.is_server(): return
	
	match (event_type):
		Event.TELEPORT_PLAYER:
			# get player (1st part of data array)
			var player : RigidPlayer = Global.get_world().get_node_or_null(str(args[0]))
			if player != null:
				player.teleport.rpc(args[1])
		Event.EXPLODE:
			var explosion_i : Explosion = SpawnableObjects.explosion.instantiate()
			get_tree().current_scene.add_child(explosion_i)
			explosion_i.set_explosion_size(1.5)
			# player_from id is later used in death messages
			explosion_i.set_explosion_owner(Global.get_world().get_node_or_null(str(args[0])).get_multiplayer_authority())
			explosion_i.global_position = args[1]
			explosion_i.play_sound()
		Event.CHANGE_PLAYER_TEAM:
			# get player (1st part of data array)
			var player : RigidPlayer = Global.get_world().get_node_or_null(str(args[0]))
			if player != null:
				Global.get_world().change_player_team(player)
		_:
			err()

func err() -> void:
	printerr("Failed to run event because the event type is not valid.")
