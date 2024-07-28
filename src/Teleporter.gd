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

extends TBWObject

@onready var area : Area3D = $Area3D
@export var destinations : Array[Node3D]

@onready var particles : PackedScene = preload("res://data/scene/teleporter/TeleportParticles.tscn")

func _ready() -> void:
	$Area3D.connect("body_entered", _on_body_entered)

func _on_body_entered(body : Node3D) -> void:
	if (body is RigidPlayer || body is Bomb || body is ClayBall) && destinations.size() > 0:
		# run on player auth
		if body.get_multiplayer_authority() == multiplayer.get_unique_id():
			var dest : Node3D = destinations.pick_random()
			body.global_position = dest.global_position
			# spawn particles for all clients
			_spawn_particles.rpc(dest.global_position)

@rpc("any_peer", "call_local", "reliable")
func _spawn_particles(pos : Vector3) -> void:
	var p : GPUParticles3D = particles.instantiate()
	add_child(p)
	p.global_position = pos
	p.emitting = true
