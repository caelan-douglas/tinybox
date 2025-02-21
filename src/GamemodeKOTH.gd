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
class_name GamemodeKOTH

# whether or not it's a team KOTH
var ffa : bool = false
var capture_points : Array[CapturePoint] = []
var capture_time_limit : int = 60

# constructor for koth
func _init(_ffa : bool) -> void:
	ffa = _ffa
	if ffa:
		gamemode_name = "Capture"
		gamemode_subtitle = "Capture and hold a point to win!"
	# tdm
	else:
		gamemode_name = "Team Capture"
		gamemode_subtitle = "As a team, capture and hold a point to win!"

func start(_params : Array, _mods : Array) -> void:
	# only server starts games
	if !multiplayer.is_server(): return
	
	if _params.size() > 1:
		# capture time limit is default 60s
		capture_time_limit = _params[1]
	
	# get all capture points in world
	for c in Global.get_world().get_children():
		if c is CapturePoint:
			capture_points.append(c)
			print(str("Capture Point added: ", c, "."))
			c.set_visible_rpc.rpc(true)
	
	super(_params, _mods)

# Sync parameters on player join.
func _on_peer_connected(id : int) -> void:
	super(id)
	# sync capture point colours
	for c in capture_points:
		c.set_colour.rpc_id(id, c.current_colour)
		c.set_visible_rpc.rpc(true)

# runs as server
func set_run_parameters(p : RigidPlayer) -> void:
	p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bouncyball)
	p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat)
	p.update_capture_time(0)

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	await super()
	
	# run start events
	Event.new(Event.EventType.CLEAR_LEADERBOARD).start()
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		set_run_parameters(p)
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
			watcher = Watcher.new(Watcher.WatcherType.PLAYER_PROPERTY_EXCEEDS, ["capture_time", capture_time_limit - 1])
			watcher.connect("ended", end)
		# team capture
		else:
			watcher = Watcher.new(Watcher.WatcherType.TEAM_PROPERTY_EXCEEDS, ["capture_time", capture_time_limit - 1])
			watcher.connect("ended", end)
		watcher.start()
		connect("gamemode_ended", watcher.queue_free)

func end(args : Array) -> void:
	# only server ends games
	if !multiplayer.is_server(): return
	
	for c in capture_points:
		c.set_visible_rpc.rpc(false)
	
	if args.is_empty():
		# free for all determinant
		if ffa:
			var player_highest_capture : RigidPlayer = null
			for player : RigidPlayer in Global.get_world().rigidplayer_list:
				if player_highest_capture == null:
					player_highest_capture = player
				else:
					if player.capture_time > player_highest_capture.capture_time:
						player_highest_capture = player
			# determine winner if we ended based on timer
			args = [player_highest_capture.get_multiplayer_authority(), "player"]
		#team
		else:
			var team_highest_capture : Team = null
			var team_highest_capture_count : int = 0
			for team : Team in Global.get_world().get_current_map().get_teams().get_team_list():
				var total_team_capture : int = 0
				for player : RigidPlayer in Global.get_world().rigidplayer_list:
					if player.team == team.name:
						total_team_capture += player.capture_time
				if team_highest_capture == null:
					team_highest_capture = team
					team_highest_capture_count = total_team_capture
				elif total_team_capture > team_highest_capture_count:
					team_highest_capture = team
					team_highest_capture_count = total_team_capture
			args = [team_highest_capture.name, "team"]
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
