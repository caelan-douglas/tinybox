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


# For non-player controlled characters.
class_name Character
extends SyncedRigidbody3D

enum {
	IDLE,
	RUN,
	AIR,
	TRIPPED,
	STANDING_UP,
	DEAD,
	RESPAWN
}

@export var health : int = 750
@export var team := "Default"
@onready var label : Label3D = $Label3D

func set_health(new : int) -> int:
	health = new
	label.text = str("Health: ", health)
	update_health.rpc(health)
	return health

func get_health() -> int:
	return health

# Update peers with new health
@rpc("call_remote")
func update_health(new : int) -> void:
	health = new
	label.text = str("Health: ", health)

@rpc("any_peer", "call_local")
func explode(explosion_position : Vector3, from_whom : int = -1) -> void:
	# only run on authority
	if !is_multiplayer_authority(): return
	
	var explosion_force := randi_range(20, 30)
	# reduce health depending on distance of explosion; notify health handler who it was from
	var offset_pos : Vector3 = Vector3(global_position.x, global_position.y + 0.4, global_position.z)
	set_health(get_health() - (28 / int(1 + offset_pos.distance_to(explosion_position))))
	var explosion_dir : Vector3 = explosion_position.direction_to(global_position) * explosion_force
	apply_impulse(explosion_dir)
