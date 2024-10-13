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
			watcher = Watcher.new(Watcher.WatcherType.PLAYER_PROPERTY_EXCEEDS,\
					["kills", 15],\
					[Event.new(Event.EventType.SHOW_PODIUM), Event.new(Event.EventType.END_ACTIVE_GAMEMODE)])
		else:
			watcher = Watcher.new(Watcher.WatcherType.TEAM_KILLS_EXCEEDS,\
				["kills", 20],\
				[Event.new(Event.EventType.SHOW_PODIUM), Event.new(Event.EventType.END_ACTIVE_GAMEMODE)])
		watcher.start()
		connect("gamemode_ended", watcher.queue_free)
