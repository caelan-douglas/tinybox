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

extends SyncedRigidbody3D
class_name Bomb

@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var world : World = Global.get_world()

@onready var explosion : PackedScene = SpawnableObjects.explosion
@export var explode_time : float = 3
@export var explosion_size : float = 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# despawn in 30 seconds in case fired off map
	despawn_time = 30
	super()

@rpc("any_peer", "call_local")
func explode(from_whom_id : int) -> void:
	var explosion_i : Explosion = explosion.instantiate()
	get_tree().current_scene.add_child(explosion_i)
	explosion_i.set_explosion_size(explosion_size)
	# player_from id is later used in death messages
	explosion_i.set_explosion_owner(from_whom_id)
	explosion_i.global_position = global_position
	explosion_i.play_sound()
	queue_free()

@rpc("call_local")
func spawn_projectile(auth : int, shot_speed : int = 15) -> void:
	set_multiplayer_authority(auth)
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	player_from = world.get_node(str(auth))
	
	# Set ball spawn point to player point
	if player_from != null:
		global_position = player_from.global_position
		global_position = Vector3(global_position.x, global_position.y + 2.5, global_position.z)
	
	# determine direction from camera
	var direction : Vector3 = Vector3.ZERO
	if camera:
		direction = -camera.global_transform.basis.z
	
	var player_velocity : Vector3 = player_from.linear_velocity
	if player_from._state == RigidPlayer.IN_SEAT:
		player_velocity = player_from.seat_occupying.linear_velocity * 2
	linear_velocity = direction * shot_speed + player_velocity
	# bomb has arc throw
	linear_velocity.y += 6
	# bombs explode in time
	await get_tree().create_timer(explode_time).timeout
	explode.rpc(auth)

# deflected bombs get sent in the direction of the player who is holding the tool
@rpc("any_peer", "call_local", "reliable")
func deflect(player_facing : Vector3) -> void:
	apply_central_impulse(-player_facing * 10)
