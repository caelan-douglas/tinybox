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
class_name Teams

# List of teams for this map.
@export var team_list: Array[Resource]

# Get the list of all the teams.
func get_team_list() -> Array:
	return team_list

# Get target spawn point for a team.
func get_team_target_spawn(team_name : String) -> Node:
	var team_index : int = get_team_index(team_name)
	var map_team_spawns : Node = get_parent().get_node(str("Spawns/", team_index))
	return map_team_spawns.get_node_or_null("TargetSpawn")

# Get a team by its name.
func get_team(team_name : String) -> Team:
	for t in team_list:
		if t.name == str(team_name):
			return t
	return null

# Returns all players in a given team name as Rigidbodies.
func get_players_in_team(team_name : String) -> Array:
	var players : Array = Global.get_world().rigidplayer_list
	var ret_players := []
	for p : RigidPlayer in players:
		if team_name == p.team:
			ret_players.append(p)
	return ret_players

func get_team_name_by_index(idx : int) -> String:
	return team_list[idx].name

# Get a team's index in the list. Returns -1 if the team doesn't exist
func get_team_index(team_name : String) -> int:
	for i in range (team_list.size()):
		if team_list[i].name == team_name:
			return i
	return -1
