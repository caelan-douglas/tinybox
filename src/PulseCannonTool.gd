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

extends Tool
class_name PulseCannonTool

@export var ammo : int = -1
@onready var audio : AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer")
@onready var audio_anim : AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var beam_area : Area3D = $BeamArea
@onready var beam_area_collider : CollisionShape3D = $BeamArea/CollisionShape3D
@onready var beam_mesh : Node3D = $Smoothing/BeamMesh
var beam_active : bool = false
var beam_ammo_cooldown : int = 0
var ui_progress : ProgressBar = null
var damage_cooldown : int = 0
var predelete : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super.init("Pulse Cannon", get_parent().get_parent() as RigidPlayer)
	if is_multiplayer_authority():
		update_ammo_display()

func update_ammo_display() -> void:
	if !is_multiplayer_authority(): return
	if ui_partner != null:
		# inf ammo
		if ammo < 1:
			ui_partner.text = str(ui_tool_name)
		# limited ammo
		else:
			ui_partner.text = str("Pulse (", ammo, ")")

func reduce_ammo() -> void:
	if ammo > 0:
		ammo -= 1
		update_ammo_display()
		if ammo < 1:
			predelete = true
			# allow time for the disengage sound to play
			await get_tree().create_timer(1).timeout
			delete()

func increase_ammo() -> void:
	ammo += 1
	update_ammo_display()

@rpc("any_peer", "call_local", "reliable")
func _set_tool_audio_playing(mode : bool) -> void:
	match(mode):
		true:
			audio_anim.stop()
			audio.volume_db = -13
			audio.play()
		false:
			audio_anim.play("fadeout")

var beam_active_time : int = 0
func _physics_process(delta : float) -> void:
	if multiplayer.is_server():
		# timer for lighting player/items on fire with sustained fire
		if beam_active:
			beam_active_time += 1
		else:
			beam_active_time = 0
		
		for body in beam_area.get_overlapping_bodies():
			# make sure we don't damage ourselves
			if body is RigidPlayer && body.get_multiplayer_authority() != tool_player_owner.get_multiplayer_authority() && damage_cooldown < 1:
				body.reduce_health(1, RigidPlayer.CauseOfDeath.FIRE, get_multiplayer_authority(), true)
				if beam_active_time > 35:
					body.light_fire.rpc(tool_player_owner.get_multiplayer_authority(), 0)
				damage_cooldown = 6
			elif body is Bomb || body is Rocket:
				if beam_active_time > 35:
					body.explode.rpc(tool_player_owner.get_multiplayer_authority())
			elif body is ExplosiveBrick:
				if beam_active_time > 35:
					body.explode.rpc(body.global_position, tool_player_owner.get_multiplayer_authority())
		if damage_cooldown > 0:
			damage_cooldown -= 1
	if is_multiplayer_authority():
		if beam_active:
			# for all others, sync at physics fps
			update_beam.rpc(start, end)
			if beam_ammo_cooldown < 1:
				reduce_ammo()
				beam_ammo_cooldown = 6
			if beam_ammo_cooldown > 0:
				beam_ammo_cooldown -= 1

@rpc("authority", "call_remote")
func update_beam(start : Vector3, end : Vector3) -> void:
	beam_mesh.scale.z = end.distance_to(start)
	beam_mesh.global_position = end.lerp(start, 0.5)
	beam_mesh.look_at(end, Vector3(0, 1, 0))
	
	beam_area_collider.shape.size.z = beam_mesh.scale.z
	beam_area.global_position = end.lerp(start, 0.5)
	beam_area.look_at(end, Vector3(0, 1, 0))

@rpc("authority", "call_local", "reliable")
func update_beam_active(mode : bool) -> void:
	beam_mesh.visible = mode
	beam_area_collider.disabled = !mode
	beam_active = mode

var start : Vector3 = Vector3.ZERO
var end : Vector3 = Vector3.ZERO
func _process(delta : float) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	var stop_audio := false
	# if this tool is selected
	if get_tool_active():
		if ammo > 0 || ammo == -1:
			if Input.is_action_pressed("click") && !predelete:
				tool_player_owner.locked = true
				update_beam_active.rpc(true)
				if (audio != null && audio_anim != null):
					if !audio.playing || audio_anim.is_playing():
						_set_tool_audio_playing.rpc(true)
				var camera := get_viewport().get_camera_3d()
				var mousepos := get_viewport().get_mouse_position()
				var origin := camera.project_ray_origin(mousepos)
				end = origin + camera.project_ray_normal(mousepos) * 250
				start = visual_mesh_instance.get_node("beam_start_point").global_position
				if visual_mesh_instance != null:
					# for THIS client
					update_beam(start, end)
					# sync on first frame with other clients to avoid
					# showing old position
					# (other clients only sync beam at physics fps)
					if Input.is_action_just_pressed("click"):
						update_beam.rpc(start, end)
			else:
				tool_player_owner.locked = false
				if beam_active:
					update_beam_active.rpc(false)
				stop_audio = true
		elif (ammo < 1 && ammo != -1):
			tool_player_owner.locked = false
			if beam_active:
				update_beam_active.rpc(false)
			stop_audio = true
	else:
		tool_player_owner.locked = false
		if beam_active:
			update_beam_active.rpc(false)
		stop_audio = true
	if stop_audio && (audio != null && audio_anim != null):
		# if audio is currently playing, and we are not fading out, fade out
		if audio.playing && !audio_anim.is_playing():
			_set_tool_audio_playing.rpc(false)

func set_tool_active(mode : bool, from_click : bool = false, free_camera_on_inactive : bool = true) -> void:
	super(mode, from_click, free_camera_on_inactive)
	
func delete() -> void:
	if !is_multiplayer_authority() || type == ToolType.EDITOR: return
	
	predelete = true
	update_beam_active.rpc(false)
	_force_stop_audio.rpc()
	super()

@rpc("any_peer", "call_local", "reliable")
func _force_stop_audio() -> void:
	audio.stop()
