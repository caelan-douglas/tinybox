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
var gamemode_subtitle := "A new gamemode has been started!"
var running := false
# defaults to 600 seconds or 10 mins
var time_limit_seconds : int = 20
@onready var game_timer : Timer = Timer.new()
@onready var timer_ui : ProgressBar = get_tree().current_scene.get_node("GameCanvas/Timer") as ProgressBar

func start(params : Array) -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	running = true
	print(get_multiplayer_authority(), " - Started gamemode: ", gamemode_name, " with params ", params)
	# clear player inventories
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().delete_all_tools.rpc()
	if params.size() > 0:
		# the time limit chooser is in minutes but this is in
		# seconds so we convert
		time_limit_seconds = params[0] * 60
	run()

func run() -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	# run preview event
	var preview_event : Event = Event.new(Event.EventType.SHOW_WORLD_PREVIEW, [gamemode_name, gamemode_subtitle])
	await preview_event.start()
	# start default timer
	game_timer.wait_time = time_limit_seconds
	game_timer.connect("timeout", end.bind([]))
	add_child(game_timer)
	game_timer.start()
	if timer_ui != null:
		timer_ui.visible = true
		timer_ui.max_value = time_limit_seconds
		timer_ui.value = time_limit_seconds
		update_timer()

func update_timer() -> void:
	var timer_text : Label = timer_ui.get_node("Label")
	if timer_text != null:
		var mins := str(int(game_timer.time_left as int / 60))
		var seconds := str('%02d' % (int(game_timer.time_left as int) % 60))
		timer_text.text = str(gamemode_name, " - ", mins, ":", seconds)
		timer_ui.value = game_timer.time_left
		await get_tree().create_timer(1).timeout
		update_timer()

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
	if timer_ui != null:
		timer_ui.visible = false
	# stop timer
	if game_timer.is_connected("timeout", end.bind([])):
		game_timer.disconnect("timeout", end.bind([]))
	game_timer.stop()
