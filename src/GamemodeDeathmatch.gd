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

extends Gamemode
class_name GamemodeDeathmatch

# whether or not it's a team deathmatch
var ffa : bool = false

# constructor for deathmatch
func _init(_ffa : bool) -> void:
	ffa = _ffa
	create()

func create() -> void:
	if ffa:
		gamemode_name = "Deathmatch"
		start_events = [
			Event.new(Event.EventType.CLEAR_LEADERBOARD),
			Event.new(Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN),
		]
		watchers = [
			Watcher.new(Watcher.WatcherType.PLAYER_PROPERTY_EXCEEDS,\
				["kills", 15],\
				[Event.new(Event.EventType.SHOW_PODIUM), Event.new(Event.EventType.END_ACTIVE_GAMEMODE)])
		]
	# tdm
	else:
		gamemode_name = "Team Deathmatch"
		start_events = [
			Event.new(Event.EventType.CLEAR_LEADERBOARD),
			Event.new(Event.EventType.BALANCE_TEAMS),
			Event.new(Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN),
		]
		watchers = [
			Watcher.new(Watcher.WatcherType.TEAM_KILLS_EXCEEDS,\
				["kills", 20],\
				[Event.new(Event.EventType.SHOW_PODIUM), Event.new(Event.EventType.END_ACTIVE_GAMEMODE)])
		]

func start() -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	# in case we are restarting, re-create the events and watchers
	create()
	running = true
	print("Started gamemode: ", gamemode_name)
	# clear player inventories
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().delete_all_tools.rpc()
		p.get_tool_inventory().give_base_tools.rpc()
	# run preview event
	var preview_event : Event = Event.new(Event.EventType.SHOW_WORLD_PREVIEW, [gamemode_name])
	await preview_event.start()
	# run start events
	for event : Event in start_events:
		# for any events that have delays in them (ex. showing a podium or entry screen)
		await event.start()
	# wait for next frame
	await get_tree().process_frame
	# in case ended during start events being run
	if running:
		# setup watchers
		for watcher : Watcher in watchers:
			watcher.start()
			# if this gamemode ends, stop any other watchers that are running
			connect("gamemode_ended", watcher.queue_free)

func end(params : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	print("Ended gamemode: ", gamemode_name)
	# cleanup and run any final stuff
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().reset.rpc()
	# never free gamemodes because they are saved as part of the world
	emit_signal("gamemode_ended")
	running = false
