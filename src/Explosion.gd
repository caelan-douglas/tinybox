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

extends Node3D
class_name Explosion

@onready var particles : GPUParticles3D = $GPUParticles3D
@onready var area : Area3D = $Area3D
@onready var audio : AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var spawn_time : int = Time.get_ticks_msec()
@onready var distant_sound : AudioStream = preload("res://data/audio/explosion/explode_distant.ogg")
@onready var general_sounds : Array[AudioStream] = [
	preload("res://data/audio/explosion/explode_0.ogg"),
	preload("res://data/audio/explosion/explode_1.ogg"),
]

var by_whom : int = 1
var explosion_size : int = 1

func set_explosion_size(new : float) -> void:
	explosion_size = new
	(area.get_node("CollisionShape3D") as CollisionShape3D).get_shape().set("radius", new)
	particles.scale = Vector3(new/4, new/4, new/4)
	particles.amount = new*80/2
	var new_dp := particles.draw_pass_1.duplicate()
	new_dp.size = Vector2((new + 2)/3, (new + 2)/3)
	particles.draw_pass_1 = new_dp

func set_explosion_owner(who_id : int) -> void:
	by_whom = who_id

func _ready() -> void:
	particles.emitting = true
	# delete explosion after 8s to allow particles & sound to play out
	get_tree().create_timer(8).connect("timeout", queue_free)
	area.connect("body_entered", explode)
	# delete explosion hitbox after 0.1s
	await get_tree().create_timer(0.1).timeout
	area.call_deferred("queue_free")
	# update brick groups after an explosion
	var brick_groups : BrickGroups = Global.get_world().get_node("BrickGroups")
	brick_groups.check_world_groups()

func play_sound() -> void:
	var db_lower : int = 0
	# check other explosions to lower volume
	for e : Node in get_tree().current_scene.get_children():
		if e is Explosion && e != self:
			if Time.get_ticks_msec() - e.spawn_time < 1000:
				db_lower += 1
	
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if global_position.distance_to(camera.global_position) > 100:
		audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		audio.stream = distant_sound
		audio.volume_db -= db_lower
		audio.max_distance = 5000
		audio.play()
	else:
		audio.stream = general_sounds[randi() % general_sounds.size()]
		audio.max_distance = 200
		audio.volume_db -= db_lower
		audio.play()

func explode(body : Node3D) -> void:
	if body.has_method("explode") && !(body is Explosion) && !(body is Rocket) && !(body is Bomb):
		body.explode.rpc(global_position, by_whom, explosion_size)
		# set 'last_hit_by' on player to this authority so that
		# if a player is knocked off the map by an explosion,
		# the point is attributed
		if body is RigidPlayer && multiplayer.is_server():
			body.set_last_hit_by_id.rpc(by_whom)
