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


# A Node3D that can have its spawn restricted by minigame modes.
extends TBWObject
class_name RestrictedNode3D

@export var restrict_to_minigame_type := false
@export var restriction : Array[Lobby.GameWinCondition] = [Lobby.GameWinCondition.DEATHMATCH]
@export var delete_in_sandbox := false
@export var only_in_sandbox := false
var scheduled_for_deletion := false

func _ready() -> void:
	if only_in_sandbox:
		var minigame : Minigame = Global.get_world().minigame
		if minigame != null:
			scheduled_for_deletion = true
			call_deferred("queue_free")
			return
	# server checks for minigame
	if restrict_to_minigame_type:
		# check first if this building has gamemode restrictions
		var minigame : Minigame = Global.get_world().minigame
		if minigame != null:
			var no_match := false
			if minigame is MinigameBaseDefense:
				if !restriction.has(Lobby.GameWinCondition.BASE_DEFENSE):
					no_match = true
			elif minigame is MinigameDM:
				if !restriction.has(Lobby.GameWinCondition.DEATHMATCH) && !restriction.has(Lobby.GameWinCondition.TEAM_DEATHMATCH):
					no_match = true
			elif minigame is MinigameKing:
				if !restriction.has(Lobby.GameWinCondition.KINGS):
					no_match = true
			
			if no_match:
				scheduled_for_deletion = true
				call_deferred("queue_free")
				return
		elif delete_in_sandbox:
			scheduled_for_deletion = true
			call_deferred("queue_free")
			return
