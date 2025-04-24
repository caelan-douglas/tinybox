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

extends GamemodeDeathmatch
class_name GamemodeHomeRun

var bat_knockback : int = 10

# constructor for deathmatch
func _init(_ffa : bool) -> void:
	ffa = _ffa
	if ffa:
		gamemode_name = "Home Run"
		gamemode_subtitle = "Knock other players off the map with your bat!"
	# tdm
	else:
		gamemode_name = "Team Home Run"
		gamemode_subtitle = "Knock other players off the map with your bat! Watch out for friendly fire."

func start(_params : Array, _mods : Array) -> void:
	if _params.size() > 1:
		# bat knockback is param 2
		bat_knockback = _params[1]
	super(_params, _mods)

# runs as server
# Override default deathmatch params.
func set_run_parameters(p : RigidPlayer) -> void:
	p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bat, -1, {"knockback": bat_knockback})

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	super()

func end(args : Array) -> void:
	super(args)
