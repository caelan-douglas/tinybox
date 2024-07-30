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

extends TBWObject
class_name Gamemode
signal gamemode_ended

# for built-in modes
var built_in := false

var gamemode_name := "Gamemode"
# Nested array of event types and event args.
#						 eventtype v
#							  eventargs v
#								 [["TELEPORT_ALL_PLAYERS", ["arg1", "arg2"]], ["OTHER_EVENT_NAME", ["arg1", "arg2"]]]
# like this for saving as a single line to a file
var start_events : Array = []
var watchers : Array = []
var end_events : Array = []

func _init() -> void:
	# tbw saving stuff
	tbw_object_type = "gamemode"
	properties_to_save = ["gamemode_name", "start_events", "watchers", "end_events"]

# create from tbw file
func set_property(property : StringName, value : Variant) -> void:
	print("setting ", property, " to ", value)
	match(property):
		"gamemode_name":
			gamemode_name = str(value)
		"start_events":
			start_events = value as Array
		"watchers":
			watchers = value as Array
		"end_events":
			end_events = value as Array

func create(g_name : String, g_start_events : Array, g_watchers : Array, g_end_events : Array) -> void:
	gamemode_name = g_name
	start_events = g_start_events
	watchers = g_watchers
	end_events = g_end_events

func start() -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	print("Started gamemode: ", gamemode_name)
	# run start events
	for event : Array in start_events:
		if Event.EventType.get(event[0]) is int:
			var created_event : Event = Event.new(Event.EventType.get(event[0]) as int, event[1] as Array)
			created_event.start()
		else:
			UIHandler.show_alert("Could not start gamemode: invalid event type", 4, false, UIHandler.alert_colour_error)
			end([])
			return
	# wait for next frame
	await get_tree().process_frame
	# setup watchers
	for watcher : Array in watchers:
		if Watcher.WatcherType.get(watcher[0]) is int:
			var created_watcher : Watcher = Watcher.new(Watcher.WatcherType.get(watcher[0]) as int, watcher[1] as Array)
			created_watcher.connect("condition_met", end)
			created_watcher.start()
		else:
			UIHandler.show_alert("Could not start gamemode: invalid watcher type", 4, false, UIHandler.alert_colour_error)
			end([])
			return

func end(params : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	print("Ended gamemode: ", gamemode_name)
	print(get_incoming_connections())
	# run end events
	for event : Array in end_events:
		if Event.EventType.get(event[0]) is int:
			var created_event : Event = Event.new(Event.EventType.get(event[0]) as int, event[1] as Array)
			created_event.start()
		else:
			UIHandler.show_alert("Could not end gamemode: invalid event type", 4, false, UIHandler.alert_colour_error)
	# cleanup and run any final stuff
	# never free gamemodes because they are saved as part of the world
	emit_signal("gamemode_ended")
