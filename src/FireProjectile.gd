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
class_name FireProjectile

# From Flamethrower

@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var world : World = Global.get_world()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Area3D.connect("body_entered", _on_body_entered)
	despawn_time = 2.5
	super()

func _on_body_entered(body : Node3D) -> void:
	# only run on auth
	if !is_multiplayer_authority(): return
	
	if body.has_method("light_fire"):
		# special "from_who" arg for players
		if body is RigidPlayer:
			body.light_fire.rpc(get_multiplayer_authority(), 8)
		# lower chance of lighting fire for anything that's not a player
		else:
			if (randi() % 10 > 8):
				body.light_fire.rpc()

@rpc("call_local")
func spawn_projectile(auth : int, shot_speed := 30) -> void:
	set_multiplayer_authority(auth)
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	player_from = world.get_node(str(auth))
	
	# Set water spawn point to player point
	if player_from != null:
		global_position = player_from.global_position
		global_position = player_from.get_node("projectile_spawn_point").global_position
	
	# determine direction from camera
	var direction := Vector3.ZERO
	if camera:
		direction = -camera.global_transform.basis.z
	# set own velocity
	linear_velocity = direction * shot_speed
