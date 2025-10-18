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
class_name Fire

@onready var particles : GPUParticles3D = $GPUParticles3D
@onready var audio : AudioStreamPlayer3D = $AudioStreamPlayer3D

func set_particle_scale(size : Vector2 = Vector2(1, 1)) -> void:
	var new := particles.draw_pass_1.duplicate()
	new.size = size
	particles.draw_pass_1 = new

func light() -> void:
	particles.restart()
	audio.play(randi_range(0, 4))

func extinguish() -> void:
	particles.emitting = false
	audio.stop()
