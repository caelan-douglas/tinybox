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

extends Throwable
class_name Firecracker

@onready var audio : AudioStreamPlayer3D = $HitAudio
var explosion_size : float = 1.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	if !is_multiplayer_authority(): return
	
	await get_tree().create_timer(despawn_time).timeout
	explode.rpc(Vector3.ZERO)

@rpc("any_peer", "call_local")
func explode(explosion_position : Vector3, from_whom : int = -1, _explosion_force : float = 4) -> void:
	var explosion_i : Explosion = SpawnableObjects.explosion.instantiate()
	get_tree().current_scene.add_child(explosion_i)
	explosion_i.set_explosion_size(explosion_size)
	explosion_i.set_explosion_owner(get_multiplayer_authority())
	explosion_i.global_position = global_position
	explosion_i.play_sound()
	queue_free()

func _on_body_entered(body : Node3D) -> void:
	super(body)
	#if body is RigidPlayer:
	#	explode(Vector3.ZERO)
	audio.volume_db = -15 + linear_velocity.length()
	clamp(audio.volume_db, -50, 0)
	audio.play()

@rpc("call_local")
func spawn_projectile(auth : int, shot_speed := 30, random_pos := false) -> void:
	super(auth, shot_speed, random_pos)
