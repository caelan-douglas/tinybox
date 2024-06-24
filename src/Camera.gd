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
var yaw : float = 180
var pitch : float = -25
var dist : float = 5
var target_dist : float = 5
var aim_dist : float = 3
var sensitivity : float = 0.15
var max_dist : float = 40
var _camera_mode : CameraMode = CameraMode.FREE
var mode_locked := false
var locked := false
# don't interpolate from spawn point
var do_interpolate := false
@onready var speed_trails : GPUParticles3D = $SpeedTrails
@onready var gimbal : Node3D = get_parent()
@onready var intersection_area : Area3D = $IntersectionArea

func get_mode_locked() -> bool:
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

func get_camera_mode() -> CameraMode:
	return _camera_mode

func set_camera_mode(new : CameraMode) -> void:
	if !mode_locked:
		_camera_mode = new
		max_dist = 40
		if new == CameraMode.AIM:
			get_tree().current_scene.get_node("GameCanvas/Crosshair").visible = true
		else:
			get_tree().current_scene.get_node("GameCanvas/Crosshair").visible = false
		
		# longer zoom in controlled (editor) mode
		if new == CameraMode.CONTROLLED:
			max_dist = 150
		emit_signal("camera_mode_changed")

func set_target(new_target : Node, interpolate := true) -> void:
	if !locked:
		do_interpolate = interpolate
		if new_target == null:
			var last_pos := Vector3.ZERO
			if target != null:
				last_pos = target.global_position
			target = Node3D.new()
			get_tree().current_scene.add_child(target)
			target.global_position = last_pos
		else:
			target = new_target

func set_target_wait_to_player(target_1 : Node, wait_time := 1) -> void:
	set_target(target_1)
	await get_tree().create_timer(wait_time).timeout
	# update player camera to appropriate mode
	Global.get_player()._on_camera_mode_changed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# always move camera last
	set_process_priority(255)
	set_physics_process_priority(255)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func move_around_target(vec: Vector2) -> void:
	# fmod is modulo on floats
	yaw = fmod((yaw - vec.x * sensitivity), 360)
	pitch = max(min(pitch - vec.y * sensitivity, 70), -85)
	rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)

func _unhandled_input(event : InputEvent) -> void:
	if !locked:
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var mouse : InputEventMouseMotion = event
			var mouse_delta : Vector2 = mouse.get_relative()
			move_around_target(mouse_delta)
		#if event is InputEventMouseButton:
		#	if event.is_pressed():
		#		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		#			target_dist = clamp(target_dist - 2, 3, 40)
		#		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		#			target_dist = clamp(target_dist + 2, 3, 40)

func _control_camera_rotation(delta : float) -> void:
	var controller_sensitivity := 14
	var camera_vec := Vector2.ZERO
	camera_vec.y = (Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")) * 0.5
	camera_vec.x = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
	
	move_around_target(camera_vec * controller_sensitivity)
	
	if target != null:
		if dist_to_hit != null:
			dist_diff = lerp(dist_diff, dist_to_hit, 0.3)
			var new_dist : float = clamp((dist - dist_diff), 1, max_dist) - 0.1
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
	
	dist = lerp(float(dist), float(target_dist), 9 * delta)

var dist_to_hit : float = 0.0
var min_dist : float = 3
var dist_diff : float = 0.0
const CONTROLLED_CAM_DELAY_TIME = 10
var controlled_cam_delay := 5
var controlled_cam_pos := Vector3(0, 50, 0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta : float) -> void:
	if _camera_mode == CameraMode.CONTROLLED:
		target.global_position = lerp(target.global_position, controlled_cam_pos, 0.1)
		# reset if key is let go then pressed again
		if Input.is_action_just_pressed("forward") || Input.is_action_just_pressed("back") || Input.is_action_just_pressed("right") || Input.is_action_just_pressed("left") || Input.is_action_just_pressed("shift") || Input.is_action_just_pressed("control"):
			controlled_cam_delay = 0
		if controlled_cam_delay <= 0:
			var move_forward : float = Input.get_action_strength("back") - Input.get_action_strength("forward")
			var move_sideways : float = Input.get_action_strength("right") - Input.get_action_strength("left")
			var move_vertical : float = Input.get_action_strength("shift") - Input.get_action_strength("control")
			# don't move up/down with forward/sideways
			var controlled_cam_lateral := Vector3.ZERO
			# move relative to looking direction
			controlled_cam_lateral += move_forward * get_global_transform().basis.z
			controlled_cam_lateral += move_sideways * get_global_transform().basis.x
			controlled_cam_lateral.y = 0
			controlled_cam_pos += controlled_cam_lateral.normalized() + (move_vertical * Vector3.UP)
			# snap to grid
			controlled_cam_pos = controlled_cam_pos.round()
			controlled_cam_delay = CONTROLLED_CAM_DELAY_TIME
		else:
			controlled_cam_delay -= 60 * delta
		global_position = Vector3(target.global_position.x as float, target.global_position.y + 5 as float, target.global_position.z - 8 as float)
		
		# swap camera zoom
		if Input.is_action_just_pressed("editor_camera_zoom"):
			match (int(target_dist)):
				5:
					target_dist = 10
				10:
					target_dist = 15
				15:
					target_dist = 25
				25:
					target_dist = 50
				50:
					target_dist = 100
				_:
					target_dist = 5
		
		_control_camera_rotation(delta)
	
	elif !locked:
		gimbal.global_rotation = Vector3.ZERO
		# zoom
		if Input.is_action_just_pressed("zoom_in") && Input.is_action_pressed("control"):
			target_dist = clamp(target_dist - 2, 3, max_dist)
		elif Input.is_action_just_pressed("zoom_out") && Input.is_action_pressed("control"):
			target_dist = clamp(target_dist + 2, 3, max_dist)
		
		# if multithreaded physics, this section FROM HERE
		# must be moved to physics process
		# (physics api calls can only be called on physics_process)
		dist_to_hit = 0.0
		if target != null:
			var applied_pos : Vector3 = target.global_position - dist * project_ray_normal(get_viewport().get_visible_rect().size * 0.5)
			intersection_area.global_position = applied_pos
			if intersection_area.get_overlapping_bodies().size() > 0:
				var space_state := get_world_3d().direct_space_state
				# layer mask for ray is 0x7 (binary is 0111 for layers 1, 2, 3; camera is 4)
				var ray := PhysicsRayQueryParameters3D.create(target.global_position as Vector3, applied_pos, 0x7)
				var hit := space_state.intersect_ray(ray)
				if hit:
					dist_to_hit = applied_pos.distance_to(hit["position"] as Vector3)
					# a bit of padding between the hit object and camera
					dist_to_hit += 0.4
			# speed trails
			if target.owner is RigidPlayer:
				var player : RigidPlayer = target.owner
				speed_trails.global_rotation = player.global_rotation
				speed_trails.rotate_object_local(Vector3.LEFT, deg_to_rad(-90))
				if player.lateral_velocity.length() > 12 && (player._state != RigidPlayer.DEAD && player._state != RigidPlayer.TRIPPED && player._state != RigidPlayer.DUMMY):
					speed_trails.emitting = true
				else:
					speed_trails.emitting = false
		# TO HERE
		
		_control_camera_rotation(delta)
		
		# Toggle camera modes.
		if Input.is_action_just_pressed("toggle_camera_mode"):
			match _camera_mode:
				CameraMode.FREE:
					set_camera_mode(CameraMode.AIM)
				CameraMode.AIM:
					set_camera_mode(CameraMode.FREE)
	elif _camera_mode == CameraMode.TRACK && target != null:
		look_at(target.global_position as Vector3)
		var far_dist : float = clamp(global_position.distance_to(target.global_position as Vector3), 0, 40)
		fov = 55 - far_dist

@rpc("call_local")
func get_mouse_pos_3d() -> Dictionary:
	if get_world_3d():
		var space_state := get_world_3d().direct_space_state
		var mouse_pos : Vector2 = get_viewport().get_mouse_position()
		var r_origin := project_ray_origin(mouse_pos)
		var r_end := r_origin + project_ray_normal(mouse_pos) * 8000
		# collision mask on layer 1(bit1), 2(bit2), 6(bit32)
		var ray_query := PhysicsRayQueryParameters3D.create(r_origin, r_end, 1|32)
		var r_array : Dictionary = space_state.intersect_ray(ray_query)
		
		if r_array:
			return r_array
	return {}

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
