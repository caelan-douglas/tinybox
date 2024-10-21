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
class_name Rocket

@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var world : World = Global.get_world()

@onready var explosion : PackedScene = SpawnableObjects.explosion
var explosion_size : int = 2
var speed : int = 20
var grace_period := true
@export var guided := false
var tool_overlay : Control = null
var tool_overlay_time : Control = null
var tool_overlay_dist : Control = null
var despawn_timer : SceneTreeTimer = null
var addl_vel := Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# despawn in 15 seconds in case fired off map
	if guided:
		despawn_time = 25
	else:
		despawn_time = 15
	# replace super ready: explode instead of despawn on timer out
	multiplayer.peer_disconnected.connect(_player_left)
	if (despawn_time != -1) && despawn_time > 0:
		despawn_timer = get_tree().create_timer(despawn_time as float)
		despawn_timer.connect("timeout", _send_explode.bind(1))
	
	if guided:
		$MissileBeep.playing = true
	
	# add a synchronizer if we don't have one
	if add_synchronizer_on_spawn:
		add_synchronizer()

func _send_explode(from_whom_id : int) -> void:
	explode.rpc(from_whom_id)

@rpc("any_peer", "call_local", "reliable")
func explode(from_whom_id : int) -> void:
	var explosion_i : Explosion = explosion.instantiate()
	get_tree().current_scene.add_child(explosion_i)
	explosion_i.set_explosion_size(explosion_size)
	explosion_i.set_explosion_owner(from_whom_id)
	explosion_i.global_position = global_position
	explosion_i.play_sound()
	# wait a bit before resetting camera in guided missiles
	if guided && is_multiplayer_authority():
		if camera != null:
			camera.set_target_wait_to_player(null, 1)
		player_from.locked = false
		if tool_overlay != null:
			tool_overlay.visible = false
	queue_free()

@rpc("call_local")
func spawn_projectile(auth : int, shot_speed : float = 15) -> void:
	set_multiplayer_authority(auth)
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	player_from = world.get_node(str(auth))
	speed = shot_speed
	
	# Set ball spawn point to player point
	if player_from != null:
		global_position = player_from.global_position
		global_position = player_from.get_node("projectile_spawn_point").global_position
	
	# determine rocket direction
	var direction := Vector3.ZERO
	if camera:
		direction = -camera.global_transform.basis.z
		global_rotation = camera.global_rotation
	# propel player, if they are already being propulsed
	if !guided:
		player_from.apply_force(-direction * 350)
		# if player is in seat, add seat velocity
		if player_from.seat_occupying != null:
			addl_vel = player_from.seat_occupying.linear_velocity
	
	if guided:
		world.connect("map_deleted", connect_explosion)
		if camera is Camera:
			camera.set_target($Smoothing/target, false)
			player_from.locked = true
			if is_multiplayer_authority():
				tool_overlay = get_tree().current_scene.get_node_or_null("GameCanvas/ToolOverlay/MissileTool")
				if tool_overlay != null:
					tool_overlay.visible = true
					tool_overlay_time = get_tree().current_scene.get_node_or_null("GameCanvas/ToolOverlay/MissileTool/MissileTimer")
					tool_overlay_dist = get_tree().current_scene.get_node_or_null("GameCanvas/ToolOverlay/MissileTool/MissileDistance")
				# lower vol on client
				$MissileBeep.max_db = -8
		else:
			guided = false
	# allow all peers to have this explode, don't explode immediately
	# upon spawn (grace period)
	connect("body_entered", connect_explosion)
	await get_tree().create_timer(0.3).timeout
	grace_period = false

func _physics_process(delta : float) -> void:
	if !is_multiplayer_authority(): return
	
	if guided && is_multiplayer_authority():
		if camera != null:
			global_rotation.y = lerp_angle(global_rotation.y, camera.global_rotation.y, delta * 1.4)
			global_rotation.z = lerp_angle(global_rotation.z, camera.global_rotation.z, delta * 1.4)
			global_rotation.x = lerp_angle(global_rotation.x, camera.global_rotation.x, delta * 1.4)
		else:
			explode.rpc(get_multiplayer_authority())
		var dir : Vector3 = -global_transform.basis.z
		dir = dir.normalized()
		linear_velocity = dir * speed
		
		# explode on owner's death
		if player_from._state == RigidPlayer.DEAD:
			explode.rpc(get_multiplayer_authority())
		
		if tool_overlay_time != null && despawn_timer != null:
			tool_overlay_time.value = despawn_timer.time_left
		
		# show the distance of the nearest player
		if tool_overlay_dist != null:
			var min_dist : float = 9999
			for p : RigidPlayer in Global.get_world().rigidplayer_list:
				if p != player_from && p.global_position.distance_to(global_position) < min_dist:
					min_dist = p.global_position.distance_to(global_position)
			tool_overlay_dist.value = min_dist
	elif is_multiplayer_authority():
		# not guided
		linear_velocity = -global_transform.basis.z.normalized() * speed + addl_vel

func connect_explosion(body : Node3D) -> void:
	# explode on collision hit. the authority determines if the collision hit
	# & sends the result to all peers.
	
	# don't explode when a player hits themselves during the grace period
	if grace_period && body is RigidPlayer:
		if body.get_multiplayer_authority() == get_multiplayer_authority():
			return
	explode.rpc(get_multiplayer_authority())

# water does not affect rocket physics
func entered_water() -> void:
	pass

func exited_water() -> void:
	pass
