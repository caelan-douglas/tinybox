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
class_name GamemodeRace

var ball_cooldown : int = 1
var ffa : bool = false

# constructor for deathmatch
func _init(_ffa : bool) -> void:
	ffa = _ffa
	if ffa:
		gamemode_name = "Race"
		gamemode_subtitle = "Race to the finish line!"
	# team
	else:
		gamemode_name = "Team Race"
		gamemode_subtitle = "Race to the finish line with your team!"

func start(_params : Array, _mods : Array) -> void:
	super(_params, _mods)

# runs as server
# Override default deathmatch params.
func set_run_parameters(p : RigidPlayer) -> void:
	pass

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	await super()
	
	# run start events
	Event.new(Event.EventType.CLEAR_LEADERBOARD).start()
	if !ffa:
		Event.new(Event.EventType.BALANCE_TEAMS).start()
	Event.new(Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN).start()
	# grace period in case any players were on finish line before gamemode started
	await get_tree().create_timer(0.5).timeout
	# in case ended during start events being run
	if running:
		# setup watchers
		var watcher : Watcher
		if ffa:
			watcher = Watcher.new(Watcher.WatcherType.PLAYER_PROPERTY_EXCEEDS, ["checkpoint", 0])
			watcher.connect("ended", end)
		# team capture
		else:
			watcher = Watcher.new(Watcher.WatcherType.TEAM_PROPERY_EXCEEDS_FOR_EACH_PLAYER, ["checkpoint", 0])
			watcher.connect("ended", end)
		watcher.start()
		connect("gamemode_ended", watcher.queue_free)

func end(args : Array) -> void:
	if !args.is_empty():
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
