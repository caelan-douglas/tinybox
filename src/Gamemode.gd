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
class_name Gamemode
signal gamemode_ended

var gamemode_name := "Gamemode"
var running := false

func start() -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	running = true
	print(get_multiplayer_authority(), " - Started gamemode: ", gamemode_name)
	# clear player inventories
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().delete_all_tools.rpc()
	run()

func run() -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	# run preview event
	var preview_event : Event = Event.new(Event.EventType.SHOW_WORLD_PREVIEW, [gamemode_name])
	await preview_event.start()

func end(params : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	print(get_multiplayer_authority(), " - Ended gamemode: ", gamemode_name)
	# cleanup and run any final stuff
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().reset.rpc()
		p.update_team.rpc("Default")
	# never free gamemodes because they are saved as part of the world
	emit_signal("gamemode_ended")
	running = false
