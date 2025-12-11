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
class_name GamemodeHideSeek

var seeker_amt : int = 1

# constructor for deathmatch
func _init() -> void:
	gamemode_name = "Hide & Seek"
	gamemode_subtitle = "Seekers chase down the Hiders. If the Seekers hit a Hider with their bat, they become a Seeker."

func start(_params : Array, _mods : Array) -> void:
	if _params.size() > 1:
		# seeker starting amount (param 2)
		seeker_amt = _params[1]
	super(_params, _mods)

# runs as server
func set_run_parameters(p : RigidPlayer) -> void:
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	p.update_team.rpc(teams.get_team_list()[2].name)
	p.set_name_visible.rpc(false)
	p.connect("hit_by_melee", _on_hider_hit_by_melee.bind(p))
	UIHandler.show_alert.rpc_id(p.get_multiplayer_authority(), str("You are a hider! Hide from the seekers (green)!"), 10, false, UIHandler.alert_colour_player)

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	await super()
	
	# set camera max zoom distance
	Global.set_camera_max_dist.rpc(8)
	
	var others : Array = Global.get_world().rigidplayer_list.duplicate()
	var seekers : Array = []
	# pick random player to be Seeker
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	for i : int in range(seeker_amt):
		var seeker : RigidPlayer = others.pick_random()
		seekers.append(seeker)
		seeker.update_team.rpc(teams.get_team_list()[1].name)
		# give them the bat
		seeker.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat)
		UIHandler.show_alert.rpc_id(seeker.get_multiplayer_authority(), "You are a Seeker! Find the hiders and hit them with your bat!", 10, false, UIHandler.alert_colour_player)
		# this one has been chosen, erase from the remaining hiders pool
		others.erase(seeker)
	# set others to runners
	for player : RigidPlayer in others:
		set_run_parameters(player)
	# move all players to spawn
	Event.new(Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN).start()
	# set seeker to locked for now
	for seeker : RigidPlayer in seekers:
		seeker.change_state.rpc_id(seeker.get_multiplayer_authority(), RigidPlayer.DUMMY)
		seeker.protect_spawn(16, false)
	# seeker timer
	await Event.new(Event.EventType.WAIT_FOR_SECONDS, [15, true, "Seeker(s) released in "]).start()
	# unlock seeker after countdown
	for seeker : RigidPlayer in seekers:
		seeker.change_state.rpc_id(seeker.get_multiplayer_authority(), RigidPlayer.IDLE)
	# add hider death penalty after seeker has been released
	for player : RigidPlayer in others:
		player.connect("died", _on_hider_death.bind(player))
	
	# end watchers
	
	# in case ended during start events being run
	if running:
		# setup watchers
		var watcher : Watcher
		watcher = Watcher.new(Watcher.WatcherType.TEAM_FULL, [teams.get_team_list()[1].name])
		watcher.connect("ended", end)
		watcher.start()
		connect("gamemode_ended", watcher.queue_free)

func _on_hider_hit_by_melee(tool : Tool, player : RigidPlayer) -> void:
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	# if the tool owner (seeker)'s team is Seekers, and the hit player is not already on Seekers
	if tool.tool_player_owner.team == teams.get_team_list()[1].name && player.team != teams.get_team_list()[1].name:
		UIHandler.show_alert.rpc(str(player.display_name, " was found by ", tool.tool_player_owner.display_name, "!"), 5, false, UIHandler.alert_colour_player)
		player.get_tool_inventory().delete_all_tools()
		player.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat)
		# seekers' names are visible
		player.set_name_visible.rpc(true)
		UIHandler.show_alert.rpc_id(player.get_multiplayer_authority(), "You are now a Seeker! Find the other hiders!", 6, false, UIHandler.alert_colour_gold)
		await get_tree().process_frame
		# change the player who got hit to seeker team
		player.update_team.rpc(teams.get_team_list()[1].name)

func _on_hider_death(player : RigidPlayer) -> void:
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	if player.team == teams.get_team_list()[2].name:
		UIHandler.show_alert.rpc(str(player.display_name, " died and became a Seeker!"), 5, false, UIHandler.alert_colour_player)
		player.get_tool_inventory().delete_all_tools()
		player.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat)
		# seekers' names are visible
		player.set_name_visible.rpc(true)
		UIHandler.show_alert.rpc_id(player.get_multiplayer_authority(), "You died and are now a Seeker! Find the other hiders!", 6, false, UIHandler.alert_colour_gold)
		await get_tree().process_frame
		# change the player who got hit to seeker team
		player.update_team.rpc(teams.get_team_list()[1].name)
		# no longer need connection
		player.disconnect("died", _on_hider_death.bind(player))

func end(args : Array) -> void:
	# disconnect hit by melee connections
	for player : RigidPlayer in Global.get_world().rigidplayer_list:
		if player.is_connected("hit_by_melee", _on_hider_hit_by_melee.bind(player)):
			player.disconnect("hit_by_melee", _on_hider_hit_by_melee.bind(player))
		if player.is_connected("died", _on_hider_death.bind(player)):
			player.disconnect("died", _on_hider_death.bind(player))
		player.set_name_visible.rpc(true)
	# reset camera zoom distance
	Global.set_camera_max_dist.rpc()
	# if ended with no args that means that the timer expired
	# and the hiders won
	if args.is_empty():
		args.resize(2)
		var teams : Teams = Global.get_world().get_current_map().get_teams()
		args[0] = teams.get_team_list()[2].name
	else:
		args.resize(2)
	# either way, the winner will be a team (for podium)
	args[1] = "team"
	super(args)
	# show podium
	await Event.new(Event.EventType.SHOW_PODIUM, args).start()
	# reset teams
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.update_team.rpc("Default")
