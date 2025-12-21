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
class_name Watcher
signal ended(end_args : Array)

enum WatcherType {
	# 1 var
	PLAYER_PROPERTY_EXCEEDS,
	PLAYER_PROPERTY_FALLS_BELOW,
	TEAM_PROPERTY_EXCEEDS,
	SPECIFIC_TEAM_PROPERTY_EXCEEDS,
	TEAM_PROPERY_EXCEEDS_FOR_EACH_PLAYER,
	TIMER_EXCEEDS,
	TEAM_FULL
}

var watcher_type : WatcherType = WatcherType.PLAYER_PROPERTY_EXCEEDS
var args : Array = []
var started := false

func _init(w_watcher_type : WatcherType, w_args : Array = []) -> void:
	watcher_type = w_watcher_type
	args = w_args

func start() -> void:
	# add self to tree
	Global.get_world().add_child(self)
	# only server starts watchers
	if !multiplayer.is_server(): return
	# watch for watcher condition
	started = true
	
	# run once variables (ie, waiting for a timer)
	match (watcher_type):
		WatcherType.TIMER_EXCEEDS:
			var timer := Timer.new()
			timer.wait_time = args[0] as int
			add_child(timer)
			timer.connect("timeout", end)
			timer.start()

func _physics_process(delta : float) -> void:
	if started && multiplayer.is_server():
		# constantly checked variables
		match (watcher_type):
			WatcherType.PLAYER_PROPERTY_EXCEEDS:
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.get(str(args[0])) > str(args[1]).to_int():
						end([player.get_multiplayer_authority()])
			WatcherType.PLAYER_PROPERTY_FALLS_BELOW:
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.get(str(args[0])) < str(args[1]).to_int():
						end([player.get_multiplayer_authority()])
			WatcherType.TEAM_PROPERTY_EXCEEDS:
				for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
					var total_team_prop : int = 0
					for player : RigidPlayer in Global.get_world().rigidplayer_list:
						if player.team == team.name:
							total_team_prop += player.get(str(args[0]))
					if total_team_prop > str(args[1]).to_int():
						end([team.name])
			WatcherType.SPECIFIC_TEAM_PROPERTY_EXCEEDS:
				for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
					if team.name == str(args[2]):
						var total_team_prop : int = 0
						for player : RigidPlayer in Global.get_world().rigidplayer_list:
							if player.team == team.name:
								total_team_prop += player.get(str(args[0]))
						if total_team_prop > str(args[1]).to_int():
							end([team.name])
			WatcherType.TEAM_PROPERY_EXCEEDS_FOR_EACH_PLAYER:
				for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
					if team.members.size() > 0:
						var condition_met : bool = true
						for player : RigidPlayer in Global.get_world().rigidplayer_list:
							if player.team == team.name:
								if player.get(str(args[0])) <= str(args[1]).to_int():
									condition_met = false
						if condition_met:
							end([team.name])
			WatcherType.TEAM_FULL:
				# arg 0: team name
				var teams : Teams = Global.get_world().get_current_map().get_teams()
				var team : Team = teams.get_team(str(args[0]))
				
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.team != team.name:
						return
				# has all players
				end([team.name])

func end(end_args : Array = []) -> void:
	started = false
	emit_signal("ended", end_args)
	queue_free()
