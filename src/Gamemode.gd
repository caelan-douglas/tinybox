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
var running := false

func _init() -> void:
	# tbw saving stuff
	tbw_object_type = "gamemode"
	properties_to_save = ["gamemode_name", "start_events", "watchers"]

# create from tbw file
func set_property(property : StringName, value : Variant) -> void:
	match(property):
		"gamemode_name":
			gamemode_name = str(value)
		"start_events":
			start_events = value as Array
		"watchers":
			watchers = value as Array

func create(g_name : String, g_start_events : Array, g_watchers : Array) -> void:
	gamemode_name = g_name
	start_events = g_start_events
	watchers = g_watchers

func start() -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	running = true
	print("Started gamemode: ", gamemode_name)
	# clear player inventories
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().delete_all_tools()
		p.get_tool_inventory().give_base_tools()
	# run preview event
	var preview_event : Event = Event.new(Event.EventType.SHOW_WORLD_PREVIEW, [gamemode_name])
	await preview_event.start()
	# run start events
	for event : Array in start_events:
		if Event.EventType.get(event[0]) is int:
			var created_event : Event = Event.new(Event.EventType.get(event[0]) as int, event[1] as Array)
			# for any events that have delays in them (ex. showing a podium or entry screen)
			await created_event.start()
		else:
			UIHandler.show_alert("Could not start gamemode: invalid event type", 4, false, UIHandler.alert_colour_error)
			end([])
			return
	# wait for next frame
	await get_tree().process_frame
	# in case ended during start events being run
	if running:
		# setup watchers
		for watcher : Array in watchers:
			if Watcher.WatcherType.get(watcher[0]) is int:
				#                                           watcher type enum                           watcher args         end events
				var created_watcher : Watcher = Watcher.new(Watcher.WatcherType.get(watcher[0]) as int, watcher[1] as Array, watcher[2] as Array)
				created_watcher.start()
				# if this gamemode ends, stop any other watchers that are running
				connect("gamemode_ended", created_watcher.queue_free)
			else:
				UIHandler.show_alert("Could not start gamemode: invalid watcher type", 4, false, UIHandler.alert_colour_error)
				end([])
				return

func end(params : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	print("Ended gamemode: ", gamemode_name)
	# cleanup and run any final stuff
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().reset()
	# never free gamemodes because they are saved as part of the world
	emit_signal("gamemode_ended")
	running = false
