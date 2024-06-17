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

extends Camera3D
class_name Camera
signal camera_mode_changed

enum CameraMode {
	FREE,
	AIM,
	TRACK,
	CONTROLLED
}

# The target that the camera points to and follows.
var target : Node
var yaw = 180
var pitch = -25
var dist = 5
var target_dist = 5
var aim_dist = 3
var sensitivity = 0.15
var _camera_mode : CameraMode = CameraMode.FREE
var mode_locked = false
var locked = false
# don't interpolate from spawn point
var do_interpolate = false
@onready var speed_trails = $SpeedTrails
@onready var gimbal = get_parent()
@onready var intersection_area = $IntersectionArea

func get_mode_locked():
	return mode_locked

func set_mode_locked(new : bool, mode : CameraMode = CameraMode.AIM) -> void:
	match new:
		true:
			mode_locked = false
			set_camera_mode(mode)
			mode_locked = true
		false:
			mode_locked = false
			set_camera_mode(mode)

func get_camera_mode():
	return _camera_mode

func set_camera_mode(new : CameraMode) -> void:
	if !mode_locked:
		_camera_mode = new
		if new == CameraMode.AIM:
			get_tree().current_scene.get_node("GameCanvas/Crosshair").visible = true
		else:
			get_tree().current_scene.get_node("GameCanvas/Crosshair").visible = false
		emit_signal("camera_mode_changed")

func set_target(new_target : Node, interpolate = true):
	if !locked:
		do_interpolate = interpolate
		if new_target == null:
			var last_pos = Vector3.ZERO
			if target != null:
				last_pos = target.global_position
			target = Node3D.new()
			get_tree().current_scene.add_child(target)
			target.global_position = last_pos
		else:
			target = new_target

func set_target_wait_to_player(target_1 : Node, wait_time = 1):
	set_target(target_1)
	await get_tree().create_timer(wait_time).timeout
	# update player camera to appropriate mode
	Global.get_player()._on_camera_mode_changed()

# Called when the node enters the scene tree for the first time.
func _ready():
	# always move camera last
	set_process_priority(255)
	set_physics_process_priority(255)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func move_around_target(vec: Vector2) -> void:
	# fmod is modulo on floats
	yaw = fmod((yaw - vec.x * sensitivity), 360)
	pitch = max(min(pitch - vec.y * sensitivity, 60), -85)
	rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)

func _unhandled_input(event) -> void:
	if !locked:
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var mouse = event
			var mouse_delta = mouse.get_relative()
			move_around_target(mouse_delta)
		#if event is InputEventMouseButton:
		#	if event.is_pressed():
		#		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		#			target_dist = clamp(target_dist - 2, 3, 40)
		#		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		#			target_dist = clamp(target_dist + 2, 3, 40)

var dist_to_hit = null
var min_dist = 3
var dist_diff = 0.0
var controlled_cam_pos = Vector3(0, 50, 0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if _camera_mode == CameraMode.CONTROLLED:
		target.global_position = lerp(target.global_position, controlled_cam_pos, 0.5)
		if Input.is_action_just_pressed("forward"):
			controlled_cam_pos += Vector3(0, 0, 1)
		if Input.is_action_just_pressed("back"):
			controlled_cam_pos += Vector3(0, 0, -1)
		if Input.is_action_just_pressed("left"):
			controlled_cam_pos += Vector3(1, 0, 0)
		if Input.is_action_just_pressed("right"):
			controlled_cam_pos += Vector3(-1, 0, 0)
		if Input.is_action_just_pressed("shift"):
			controlled_cam_pos += Vector3(0, 1, 0)
		if Input.is_action_just_pressed("control"):
			controlled_cam_pos += Vector3(0, -1, 0)
		global_position = Vector3(target.global_position.x, target.global_position.y + 5, target.global_position.z - 8)
		look_at(target.global_position)
	
	elif !locked:
		gimbal.global_rotation = Vector3.ZERO
		# zoom
		if Input.is_action_just_pressed("zoom_in") && Input.is_action_pressed("control"):
			target_dist = clamp(target_dist - 2, 3, 40)
		elif Input.is_action_just_pressed("zoom_out") && Input.is_action_pressed("control"):
			target_dist = clamp(target_dist + 2, 3, 40)
		
		dist = lerp(float(dist), float(target_dist), 9 * delta)
		# if multithreaded physics, this section FROM HERE
		# must be moved to physics process
		# (physics api calls can only be called on physics_process)
		dist_to_hit = null
		if target != null:
			var applied_pos = target.global_position - dist * project_ray_normal(get_viewport().get_visible_rect().size * 0.5)
			intersection_area.global_position = applied_pos
			if intersection_area.get_overlapping_bodies().size() > 0:
				var space_state = get_world_3d().direct_space_state
				# layer mask for ray is 0x7 (binary is 0111 for layers 1, 2, 3; camera is 4)
				var ray = PhysicsRayQueryParameters3D.create(target.global_position, applied_pos, 0x7)
				var hit = space_state.intersect_ray(ray)
				dist_to_hit = 0.0
				if hit:
					dist_to_hit = applied_pos.distance_to(hit["position"])
					# a bit of padding between the hit object and camera
					dist_to_hit += 0.4
			# speed trails
			if target.owner is RigidPlayer:
				var player = target.owner
				speed_trails.global_rotation = player.global_rotation
				speed_trails.rotate_object_local(Vector3.LEFT, deg_to_rad(-90))
				if player.lateral_velocity.length() > 12 && (player._state != RigidPlayer.DEAD && player._state != RigidPlayer.TRIPPED && player._state != RigidPlayer.DUMMY):
					speed_trails.emitting = true
				else:
					speed_trails.emitting = false
		# TO HERE
		
		var controller_sensitivity = 14
		var camera_vec = Vector2.ZERO
		camera_vec.y = (Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")) * 0.5
		camera_vec.x = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
		
		move_around_target(camera_vec * controller_sensitivity)
		
		if target != null:
			if dist_to_hit != null:
				dist_diff = lerp(dist_diff, dist_to_hit, 0.3)
				var new_dist = clamp((dist - dist_diff), 1, 40) - 0.1
				position = -new_dist * project_ray_normal(get_viewport().get_visible_rect().size * 0.5)
				gimbal.global_position = lerp(gimbal.global_position, target.global_position, 16 * delta)
			else:
				position = -dist * project_ray_normal(get_viewport().get_visible_rect().size * 0.5)
				if do_interpolate:
					gimbal.global_position = lerp(gimbal.global_position, target.global_position, 16 * delta)
				else:
					gimbal.global_position = target.global_position
					await get_tree().create_timer(0.1).timeout
					do_interpolate = true
		# Toggle camera modes.
		if Input.is_action_just_pressed("toggle_camera_mode"):
			match _camera_mode:
				CameraMode.FREE:
					set_camera_mode(CameraMode.AIM)
				CameraMode.AIM:
					set_camera_mode(CameraMode.FREE)
	elif _camera_mode == CameraMode.TRACK && target != null:
		look_at(target.global_position)
		var far_dist = clamp(global_position.distance_to(target.global_position), 0, 40)
		fov = 55 - far_dist

@rpc("call_local")
func get_mouse_pos_3d():
	if get_world_3d():
		var space_state = get_world_3d().direct_space_state
		var mouse_pos = get_viewport().get_mouse_position()
		var r_origin = project_ray_origin(mouse_pos)
		var r_end = r_origin + project_ray_normal(mouse_pos) * 8000
		# collision mask on layer 1(bit1), 2(bit2), 6(bit32)
		var ray_query = PhysicsRayQueryParameters3D.create(r_origin, r_end, 1|32)
		var r_array = space_state.intersect_ray(ray_query)
		
		if r_array:
			return r_array
	return Vector3()

func entered_water() -> void:
	$WaterOverlay.visible = true
	# enables the low pass effect when underwater
	AudioServer.set_bus_effect_enabled(2, 0, true)
	AudioServer.set_bus_effect_enabled(2, 1, true)

func exited_water() -> void:
	$WaterOverlay.visible = false
	# disables low pass effect
	AudioServer.set_bus_effect_enabled(2, 0, false)
	AudioServer.set_bus_effect_enabled(2, 1, false)
