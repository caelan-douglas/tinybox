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
class_name WaterProjectile

# From Extinguisher

@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var world : World = Global.get_world()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Area3D.connect("body_entered", _on_body_entered)
	despawn_time = 3
	super()

func _on_body_entered(body : PhysicsBody3D) -> void:
	if body.has_method("extinguish_fire"):
		body.extinguish_fire()

@rpc("call_local")
func spawn_projectile(auth : int, shot_speed := 30) -> void:
	set_multiplayer_authority(auth)
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	player_from = world.get_node(str(auth))
	
	# Set water spawn point to player point
	if player_from != null:
		global_position = player_from.get_node("projectile_spawn_point").global_position
		global_position.y -= 0.7
	
	# determine direction from camera
	var direction := Vector3.ZERO
	if camera:
		direction = -camera.global_transform.basis.z
	# if player in vehicle, propel vehicle
	if player_from._state == RigidPlayer.IN_SEAT:
		if player_from.seat_occupying is MotorSeat:
			# apply force on seat owner's client instead of player
			direction = -player_from.seat_occupying.transform.basis.z
			player_from.seat_occupying.apply_force_rpc.rpc_id(player_from.seat_occupying.get_multiplayer_authority(), direction * (50 * player_from.seat_occupying.vehicle_weight))
			global_position = player_from.seat_occupying.global_position
			linear_velocity = direction
	else:
		var addl_power : int = 0
		# more power when sliding
		if player_from._state == RigidPlayer.SLIDE || player_from._state == RigidPlayer.SLIDE_BACK:
			addl_power = 14
		# propel player
		player_from.external_propulsion = true
		player_from.apply_force(Vector3((direction.x * (35 + addl_power)), (35), (direction.z * (35 + addl_power))))
		# set own velocity
		linear_velocity = -direction * shot_speed
