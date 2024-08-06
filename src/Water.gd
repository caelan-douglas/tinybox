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

enum WaterType {
	WATER,
	SWAMP
}

@onready var area : Area3D = $WaterArea
@onready var deep_area : Area3D = $DeepWaterArea
@onready var splash_sound : PackedScene = preload("res://data/scene/water/Splash.tscn")
@onready var splash_particles : PackedScene = preload("res://data/scene/water/SplashParticles.tscn")
@onready var mesh : MeshInstance3D = $mesh
@onready var damage_timer : Timer = $DamageTimer

@onready var water_material : Material = preload("res://data/materials/water.tres")
@onready var swamp_water_material : Material = preload("res://data/materials/swamp_water.tres")

var water_type : WaterType = WaterType.WATER
var water_types_as_strings : Array[String] = ["Water", "Swamp"]

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "scale", "water_type"]

func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	if property == "water_type":
		set_water_type(value as int)

func _on_damage_timer_timeout() -> void:
	if multiplayer.is_server():
		for body in deep_area.get_overlapping_bodies():
			if body is RigidPlayer:
				body.reduce_health(2, RigidPlayer.CauseOfDeath.SWAMP_WATER)

func set_water_type(new_type : WaterType) -> void:
	water_type = new_type
	match (water_type):
		WaterType.WATER:
			mesh.set_surface_override_material(0, water_material)
			# stop damaging players who enter
			damage_timer.stop()
		WaterType.SWAMP:
			mesh.set_surface_override_material(0, swamp_water_material)
			# start damaging players who enter
			damage_timer.start()

func _ready() -> void:
	# for splash visuals & camera colour
	area.connect("body_entered", _on_body_entered)
	area.connect("body_exited", _on_body_exited)
	
	area.connect("area_entered", _on_area_entered)
	area.connect("area_exited", _on_area_exited)
	
	# for actually sending the water signal
	deep_area.connect("body_entered", _on_deep_body_entered)
	deep_area.connect("body_exited", _on_deep_body_exited)
	
	damage_timer.connect("timeout", _on_damage_timer_timeout)

func _on_deep_body_entered(body : PhysicsBody3D) -> void:
	# all objects except player
	if body.has_method("entered_water"):
		body.entered_water()

func _on_deep_body_exited(body : PhysicsBody3D) -> void:
	if body.has_method("exited_water"):
		body.exited_water()
	elif body.owner != null:
		if body.owner.has_method("exited_water"):
			body.owner.exited_water()

func _on_body_entered(body : Node3D) -> void:
	# visual splash
	if body is RigidBody3D:
		if body.linear_velocity.length() > 1.5:
			splash(body.global_position)
			return
	else:
		splash(body.global_position)

func _on_body_exited(body : Node3D) -> void:
	pass

func _on_area_entered(area : Node3D) -> void:
	# camera colour
	if area.get_parent() != null:
		if area.get_parent() is Camera:
			area.get_parent().entered_water()
			splash(area.global_position)

func _on_area_exited(area : Node3D) -> void:
	if area.get_parent() != null:
		if area.get_parent() is Camera:
			area.get_parent().exited_water()

func splash(pos : Vector3) -> void:
	var audio : AudioStreamPlayer3D = splash_sound.instantiate()
	add_child(audio)
	audio.global_position = pos
	audio.connect("finished", audio.queue_free)
	
	var particles : GPUParticles3D = splash_particles.instantiate()
	add_child(particles)
	particles.global_position = pos
	particles.emitting = true
