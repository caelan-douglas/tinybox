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
class_name GamemodeBalls

var ball_cooldown : int = 1

# constructor for deathmatch
func _init(_ffa : bool) -> void:
	ffa = _ffa
	if ffa:
		gamemode_name = "Balls!!!"
		gamemode_subtitle = "Balls."
	# tdm
	else:
		gamemode_name = "Team Balls!!!"
		gamemode_subtitle = "Balls."

func start(_params : Array, _mods : Array) -> void:
	if _params.size() > 1:
		# ball cooldown is param 2
		ball_cooldown = _params[1]
	super(_params, _mods)

# runs as server
# Override default deathmatch params.
func set_run_parameters(p : RigidPlayer) -> void:
	p.get_tool_inventory().add_tool.rpc(ToolInventory.ToolIdx.Bouncyball, -1, {"shot_cooldown": ball_cooldown})

func run() -> void:
	if !multiplayer.is_server(): return
	# wait for super method (camera preview)
	super()

func end(args : Array) -> void:
	super(args)
