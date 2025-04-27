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
class_name GamemodeOneVersusAll

var one : RigidPlayer

# constructor for deathmatch
func _init() -> void:
	gamemode_name = "One vs. All"
	gamemode_subtitle = "One player gets more health & stronger weapons, and the rest have to take them out before the timer expires."

# runs as server
func set_run_parameters(p : RigidPlayer, one_name : String = "") -> void:
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bouncyball)
	p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat)
	p.update_team.rpc(teams.get_team_list()[2].name)
	UIHandler.show_alert.rpc_id(p.get_multiplayer_authority(), str("Work with your team to take out ", one_name, " before time runs out!\nCareful: if they kill you, the timer decreases\nand they get a bit of health."), 10, false, UIHandler.alert_colour_player)

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	await super()
	
	var others : Array = Global.get_world().rigidplayer_list.duplicate()
	var seekers : Array = []
	# pick random player to be Seeker
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	one = others.pick_random()
	one.set_max_health((others.size() * 20) as int)
	one.set_health((others.size() * 20) as int)
	one.connect("kills_increased", _on_one_kills_increased)
	# custom weapons for one player
	one.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bouncyball, -1, {"shot_cooldown": 15})
	one.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat, -1, {"knockback": 5})
	
	one.update_team.rpc(teams.get_team_list()[1].name)
	UIHandler.show_alert.rpc_id(one.get_multiplayer_authority(), "You're on your own!\nSurvive as long as possible!", 10, false, UIHandler.alert_colour_player)
	# this one has been chosen, erase from the remaining hiders pool
	others.erase(one)
	for player : RigidPlayer in others:
		set_run_parameters(player, one.display_name)
	# run start events
	Event.new(Event.EventType.CLEAR_LEADERBOARD).start()
	Event.new(Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN).start()
	# wait for next frame
	await get_tree().process_frame
	# in case ended during start events being run
	if running:
		# setup watchers
		var watcher : Watcher
		# if the one player dies, the other team wins
		watcher = Watcher.new(Watcher.WatcherType.SPECIFIC_TEAM_PROPERTY_EXCEEDS, ["deaths", 0, teams.get_team_list()[1].name])
		watcher.connect("ended", end)
		watcher.start()
		connect("gamemode_ended", watcher.queue_free)

func _on_one_kills_increased() -> void:
	# When the lone player gets a kill, increase their health
	one.set_health(one.get_health() + 10)
	# and remove time from the timer.
	game_timer.wait_time = game_timer.time_left - (clamp(game_timer.wait_time*0.035, 5, 25))
	game_timer.start()

func end(args : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	# if ended due to timer, then the one player wins
	if args.is_empty():
		args = [one.get_multiplayer_authority(), "player"]
	# args returned from watcher does not have player/team distinction
	else:
		var teams : Teams = Global.get_world().get_current_map().get_teams()
		args = [teams.get_team_list()[2].name, "team"]
	# end game
	super(args)
	# disconnect kills watcher
	one.disconnect("kills_increased", _on_one_kills_increased)
	# show podium
	await Event.new(Event.EventType.SHOW_PODIUM, args).start()
	# reset teams
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.update_team.rpc("Default")
