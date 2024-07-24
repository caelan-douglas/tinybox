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
class_name ClayBall

@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var world : World = Global.get_world()
@onready var spring_audio : AudioStreamPlayer3D = $SpringAudio
@onready var area : Area3D = $Area3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area.connect("body_entered", _on_body_entered)
	despawn_time = 15
	super()

func _on_body_entered(body : Node3D) -> void:
	spring_audio.volume_db = -15 + linear_velocity.length()
	clamp(spring_audio.volume_db, -50, 0)
	spring_audio.play()
	if body is Brick:
		# Unjoin this brick from its group if it is hit too hard.
		if linear_velocity.length() > body.unjoin_velocity:
			body.set_glued(false)
			body.unjoin()
	elif body is RigidPlayer:
		# if we hit a player, set the player's last hit by ID to this one
		if multiplayer.is_server():
			body.set_last_hit_by_id.rpc(get_multiplayer_authority())
			body.change_state.rpc(RigidPlayer.TRIPPED)
			body.reduce_health((randi() % 3) + 1, RigidPlayer.CauseOfDeath.HIT_BY_BALL, get_multiplayer_authority())
	if is_multiplayer_authority():
		# stepped on button
		if body is ButtonBrick:
			body.stepped.rpc(get_path())

@rpc("call_local")
func spawn_projectile(auth : int, shot_speed := 30, random_pos := false) -> void:
	set_multiplayer_authority(auth)
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	player_from = world.get_node(str(auth))
	
	# Set ball spawn point to player point
	if player_from != null:
		global_position = player_from.global_position
		global_position = player_from.get_node("projectile_spawn_point").global_position
	if random_pos:
		global_rotation = player_from.global_rotation
		translate_object_local(Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), 0))
	
	# Set ball velocity to the position entry of get_mouse_pos_3d dict.
	var direction := Vector3.ZERO
	if camera:
		direction = -camera.global_transform.basis.z
	linear_velocity = direction * shot_speed
