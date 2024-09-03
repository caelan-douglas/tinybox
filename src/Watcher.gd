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

enum WatcherType {
	# 1 var
	PLAYER_PROPERTY_EXCEEDS,
	PLAYER_PROPERTY_FALLS_BELOW,
	TEAM_KILLS_EXCEEDS,
	TIMER_EXCEEDS
}

# Watcher types that cannot be used in the editor gamemode creation tool.
const EDITOR_DISALLOWED_TYPES : Array[String] = []
var watcher_type : WatcherType = WatcherType.PLAYER_PROPERTY_EXCEEDS
var args : Array = []
var started := false
# list of events (serialized) to run when this watcher's condition is met
var end_events : Array = []

func _init(w_watcher_type : WatcherType, w_args : Array, w_end_events : Array) -> void:
	watcher_type = w_watcher_type
	args = w_args
	end_events = w_end_events

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
			WatcherType.PLAYER_PROPERTY_EXCEEDS:
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.get(str(args[0])) > str(args[1]).to_int():
						end([player.get_multiplayer_authority()])
			WatcherType.PLAYER_PROPERTY_FALLS_BELOW:
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.get(str(args[0])) < str(args[1]).to_int():
						end([player.get_multiplayer_authority()])
			WatcherType.TEAM_KILLS_EXCEEDS:
				for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
					var total_team_kills : int = 0
					for player : RigidPlayer in Global.get_world().rigidplayer_list:
						if player.team == team.name:
							total_team_kills += player.kills
					if total_team_kills > str(args[0]).to_int():
						end([team.name])

func end(end_args : Array = []) -> void:
	started = false
	# run end events
	for event : Array in end_events:
		if Event.EventType.get(event[0]) is int:
			# set to watcher end args for some event types
			if Event.EventType.get(event[0]) == Event.EventType.SHOW_PODIUM:
				# event[1] is args (2nd array)
				event[1] = end_args
			# create and run event
			var created_event : Event = Event.new(Event.EventType.get(event[0]) as int, event[1] as Array)
			# for any events that have delays, like showing the podium or intro screen
			await created_event.start()
		else:
			UIHandler.show_alert("Could not run watcher end event: invalid event type", 4, false, UIHandler.alert_colour_error)
	
	queue_free()
