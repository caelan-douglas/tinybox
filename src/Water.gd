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
class_name Water

@onready var area = $WaterArea
@onready var deep_area = $DeepWaterArea
@onready var splash_sound = preload("res://data/scene/water/Splash.tscn")
@onready var splash_particles = preload("res://data/scene/water/SplashParticles.tscn")

func _ready():
	# for splash visuals & camera colour
	area.connect("body_entered", _on_body_entered)
	area.connect("body_exited", _on_body_exited)
	
	# for actually sending the water signal
	deep_area.connect("body_entered", _on_deep_body_entered)
	deep_area.connect("body_exited", _on_deep_body_exited)

func _on_deep_body_entered(body) -> void:
	# all objects except player
	if body.has_method("entered_water"):
		body.entered_water()

func _on_deep_body_exited(body) -> void:
	if body.has_method("exited_water"):
		body.exited_water()
	elif body.owner != null:
		if body.owner.has_method("exited_water"):
			body.owner.exited_water()

func _on_body_entered(body) -> void:
	# visual splash
	if body is RigidBody3D:
		if body.linear_velocity.length() > 1.5:
			splash(body.global_position)
			return
	else:
		splash(body.global_position)
	# camera colour
	if body.get_parent() != null:
		if body.get_parent() is Camera:
			body.get_parent().entered_water()

func _on_body_exited(body) -> void:
	if body.get_parent() != null:
		if body.get_parent() is Camera:
			body.get_parent().exited_water()

func splash(pos : Vector3) -> void:
	var audio = splash_sound.instantiate()
	add_child(audio)
	audio.global_position = pos
	audio.connect("finished", audio.queue_free)
	
	var particles = splash_particles.instantiate()
	add_child(particles)
	particles.global_position = pos
	particles.emitting = true
