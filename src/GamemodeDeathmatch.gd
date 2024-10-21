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
	if ffa:
		gamemode_name = "Deathmatch"
		gamemode_subtitle = "A classic arena deathmatch mode! Free-for-all."
	# tdm
	else:
		gamemode_name = "Team Deathmatch"
		gamemode_subtitle = "A classic arena team deathmatch mode! Be careful of friendly fire."

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	await super()
	
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bouncyball)
		p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat)
	# run start events
	Event.new(Event.EventType.CLEAR_LEADERBOARD).start()
	if !ffa:
		Event.new(Event.EventType.BALANCE_TEAMS).start()
	Event.new(Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN).start()
	# wait for next frame
	await get_tree().process_frame
	# in case ended during start events being run
	if running:
		# setup watchers
		var watcher : Watcher
		if ffa:
			watcher = Watcher.new(Watcher.WatcherType.PLAYER_PROPERTY_EXCEEDS, ["kills", 14])
			watcher.connect("ended", end)
		else:
			watcher = Watcher.new(Watcher.WatcherType.TEAM_KILLS_EXCEEDS, [19])
			watcher.connect("ended", end)
		watcher.start()
		connect("gamemode_ended", watcher.queue_free)

func end(args : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	if args.is_empty():
		# free for all determinant
		if ffa:
			var player_highest_kills : RigidPlayer = null
			for player : RigidPlayer in Global.get_world().rigidplayer_list:
				if player_highest_kills == null:
					player_highest_kills = player
				else:
					if player.kills > player_highest_kills.kills:
						player_highest_kills = player
			# determine winner if we ended based on timer
			args = [player_highest_kills.get_multiplayer_authority(), "player"]
		#tdm
		else:
			var team_highest_kills : Team = null
			var team_highest_kill_count : int = 0
			for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
				var total_team_kills : int = 0
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.team == team.name:
						total_team_kills += player.kills
				if team_highest_kills == null:
					team_highest_kills = team
					team_highest_kill_count = total_team_kills
				elif total_team_kills > team_highest_kill_count:
					team_highest_kills = team
					team_highest_kill_count = total_team_kills
			args = [team_highest_kills.name, "team"]
	# args returned from watcher does not have player/team distinction
	else:
		args.resize(2)
		if ffa:
			args[1] = "player"
		else:
			args[1] = "team"
	# end game
	super(args)
	# show podium
	await Event.new(Event.EventType.SHOW_PODIUM, args).start()
	# reset teams
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		p.update_team.rpc("Default")
