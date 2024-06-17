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

extends Node

# Holds a list of all brick's groups in the map. Bricks read and write their own groups to this.
@export var groups = {}

var non_auth_group = []
var receive_timeout = 0

@rpc("any_peer", "call_remote", "reliable")
func receive_group_from_authority(brick_name):
	receive_timeout = 45
	non_auth_group.append(brick_name)

func _physics_process(delta):
	receive_timeout -= 1
