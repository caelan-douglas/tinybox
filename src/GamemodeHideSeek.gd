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

# constructor for deathmatch
func _init() -> void:
	gamemode_name = "Hide & Seek"

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	await super()
	
	# set camera max zoom distance
	Global.set_camera_max_dist.rpc(8)
	
	# pick random player to be Seeker
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	var seeker : RigidPlayer = Global.get_world().rigidplayer_list.pick_random()
	seeker.update_team.rpc(teams.get_team_list()[1].name)
	# give them the bat
	seeker.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat)
	UIHandler.show_alert.rpc_id(seeker.get_multiplayer_authority(), "You are a Seeker! Find the hiders and hit them with your bat!", 10, false, UIHandler.alert_colour_player)
	# set others to runners
	var others : Array = Global.get_world().rigidplayer_list.duplicate()
	others.erase(seeker)
	for player : RigidPlayer in others:
		player.update_team.rpc(teams.get_team_list()[2].name)
		player.set_name_visible.rpc(false)
		player.connect("hit_by_melee", _on_hider_hit_by_melee.bind(player))
		UIHandler.show_alert.rpc_id(player.get_multiplayer_authority(), str("You are a hider! Hide from the seeker '", seeker.display_name, "'!"), 10, false, UIHandler.alert_colour_player)
	# move all players to spawn
	Event.new(Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN).start()
	# set seeker to locked for now
	seeker.change_state.rpc_id(seeker.get_multiplayer_authority(), RigidPlayer.DUMMY)
	# seeker timer
	await Event.new(Event.EventType.WAIT_FOR_SECONDS, [15, true, "Seeker released in "]).start()
	# unlock seeker after countdown
	seeker.change_state.rpc_id(seeker.get_multiplayer_authority(), RigidPlayer.IDLE)
	
	# end watchers
	
	# in case ended during start events being run
	if running:
		# setup watchers
		var watcher : Watcher
		watcher = Watcher.new(Watcher.WatcherType.TEAM_FULL,\
				[teams.get_team_list()[1].name],\
				[Event.new(Event.EventType.SHOW_PODIUM), Event.new(Event.EventType.END_ACTIVE_GAMEMODE)])
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

func end(args : Array) -> void:
	# disconnect hit by melee connections
	for player : RigidPlayer in Global.get_world().rigidplayer_list:
		if player.is_connected("hit_by_melee", _on_hider_hit_by_melee.bind(player)):
			player.disconnect("hit_by_melee", _on_hider_hit_by_melee.bind(player))
		player.set_name_visible.rpc(true)
	# reset camera zoom distance
	Global.set_camera_max_dist.rpc()
	super(args)