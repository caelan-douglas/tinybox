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
var time_limit_seconds : int = 600
@onready var game_timer : Timer = Timer.new()
@onready var timer_ui : GameTimer = get_tree().current_scene.get_node("GameCanvas/Timer") as ProgressBar

func start(params : Array, mods : Array) -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	running = true
	print(get_multiplayer_authority(), " - Started gamemode: ", gamemode_name, " with params ", params, " and modifiers ", mods)
	# clear player inventories
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().delete_all_tools.rpc()
		if mods.size() > 0:
			p.set_move_speed.rpc(mods[0] as float)
		if mods.size() > 1:
			# set player health as server
			p.set_max_health(mods[1] as int)
			# fill the health
			p.set_health(p.max_health as int)
		if mods.size() > 2:
			# jump force is a multiplier
			p.set_jump_force.rpc(2.4 * mods[2] as float)
		if mods.size() > 3:
			Global.get_world().get_current_map().set_low_grav(mods[3] as bool)
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
	game_timer.one_shot = true
	game_timer.wait_time = time_limit_seconds
	game_timer.connect("timeout", end.bind([]))
	add_child(game_timer)
	game_timer.start()
	if timer_ui != null:
		timer_ui.set_visible_rpc.rpc(true)
		timer_ui.set_max_val_rpc.rpc(time_limit_seconds)
		update_timer()

func update_timer() -> void:
	timer_ui.update_timer.rpc(gamemode_name, game_timer.time_left)
	# update every 1s
	await get_tree().create_timer(1).timeout
	if running:
		update_timer()

func end(params : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	print(get_multiplayer_authority(), " - Ended gamemode: ", gamemode_name)
	# cleanup and run any final stuff
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().reset.rpc()
		# reset player stuff
		p.set_max_health(20)
		p.set_move_speed.rpc(5)
		p.set_jump_force.rpc(2.4)
		# reset map gravity, in case it changed
		Global.get_world().get_current_map().set_low_grav(false)
	# never free gamemodes because they are saved as part of the world
	emit_signal("gamemode_ended")
	running = false
	if timer_ui != null:
		timer_ui.set_visible_rpc.rpc(false)
	# stop timer
	if game_timer.is_connected("timeout", end.bind([])):
		game_timer.disconnect("timeout", end.bind([]))
	game_timer.stop()
