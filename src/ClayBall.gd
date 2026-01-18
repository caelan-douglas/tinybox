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
class_name ClayBall

@onready var spring_audio : AudioStreamPlayer3D = $SpringAudio

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	despawn_time = 15
	super()

func _on_body_entered(body : Node3D) -> void:
	super(body)
	spring_audio.volume_db = -15 + linear_velocity.length()
	clamp(spring_audio.volume_db, -50, 0)
	spring_audio.play()

@rpc("authority", "call_local", "reliable")
func set_colour(new : String) -> void:
	var new_colour : Color = Color(new)
	var mesh : MeshInstance3D = $Smoothing/MeshInstance3D
	var xmas_mesh : MeshInstance3D = $Smoothing/present/Present
	var mat : Material = mesh.get_surface_override_material(0).duplicate()
	mat.albedo_color = new_colour
	var add_material_to_cache := true
	# Check over the graphics cache to make sure we don't already have the same material created.
	for cached_material : Material in Global.ball_colour_cache:
		# If the material texture and colour matches (that's all that really matters):
		if (cached_material.albedo_color == new_colour):
			# Instead of using the duplicate material we created, use the cached material.
			mat = cached_material
			# Don't add this material to cache, since we're pulling it from the cache already.
			add_material_to_cache = false
	# Add the material to the graphics cache if we need to.
	if add_material_to_cache:
		Global.add_to_ball_colour_cache(mat)
	mesh.set_surface_override_material(0, mat)
	xmas_mesh.set_surface_override_material(0, mat)

@rpc("call_local")
func spawn_projectile(auth : int, shot_speed := 30, random_pos := false) -> void:
	super(auth, shot_speed, random_pos)
	# Set ball colour to auth's pants colour.
	set_colour.rpc(Global.pants_colour.to_html(false))
