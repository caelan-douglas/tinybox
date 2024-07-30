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
signal condition_met(condition_args : Array)

enum WatcherType {
	# 1 var
	PLAYER_KILLS_EXCEEDS,
	PLAYER_CUSTOM_VARIABLE_EXCEEDS,
	TEAM_KILLS_EXCEEDS,
	TIMER_EXCEEDS
}

var watcher_type : WatcherType = WatcherType.PLAYER_KILLS_EXCEEDS
var args : Array = []
var started := false

func _init(w_watcher_type : WatcherType, w_args : Array) -> void:
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
	if started:
		# constantly checked variables
		match (watcher_type):
			WatcherType.PLAYER_KILLS_EXCEEDS:
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.kills > str(args[0]).to_int():
						end([player.get_multiplayer_authority()])
			WatcherType.TEAM_KILLS_EXCEEDS:
				for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
					var total_team_kills : int = 0
					for player : RigidPlayer in Global.get_world().rigidplayer_list:
						if player.team == team.name:
							total_team_kills += player.kills
					if total_team_kills > str(args[0]).to_int():
						end([team.name])

func end(args : Array = []) -> void:
	emit_signal("condition_met", args)
	print("Watcher ended with args: ", args)
	started = false
	queue_free()
