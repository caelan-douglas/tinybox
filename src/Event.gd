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
class_name Event

enum EventType {
	# 1 additonal arg
	TELEPORT_ALL_PLAYERS,
	LOCK_PLAYER_STATES,
	# base
	MOVE_ALL_PLAYERS_TO_SPAWN,
	BALANCE_TEAMS,
	CLEAR_LEADERBOARD
}

var event_type : EventType = EventType.TELEPORT_ALL_PLAYERS
var args : Array = []

func _init(e_event_type : EventType, e_args : Array) -> void:
	event_type = e_event_type
	args = e_args

func start() -> void:
	# add self to tree
	Global.get_world().add_child(self)
	# only server runs events
	if !multiplayer.is_server():
		queue_free()
		return
	
	match (event_type):
		EventType.TELEPORT_ALL_PLAYERS:
			var players : Array = Global.get_world().rigidplayer_list
			for player : RigidPlayer in players:
				# assuming vec3 may be string formatted
				player.teleport.rpc(Global.string_to_vec3(str(args[0])))
		EventType.MOVE_ALL_PLAYERS_TO_SPAWN:
			var players : Array = Global.get_world().rigidplayer_list
			for player : RigidPlayer in players:
				player.go_to_spawn.rpc()
		EventType.BALANCE_TEAMS:
			var teams : Teams = Global.get_world().get_current_map().get_teams()
			var participants : Array = Global.get_world().rigidplayer_list
			for i in range(participants.size()):
				if (i % 2) == 0:
					participants[i].update_team.rpc(teams.get_team_list()[1].name)
				else:
					participants[i].update_team.rpc(teams.get_team_list()[2].name)
				# update info on player's client side
				participants[i].update_info.rpc_id(participants[i].get_multiplayer_authority())
		EventType.CLEAR_LEADERBOARD:
			for player : RigidPlayer in Global.get_world().rigidplayer_list:
				player.update_kills.rpc(0)
				player.update_deaths.rpc(0)
		_:
			printerr("Failed to run event because the event type is not valid.")
	
	queue_free()
