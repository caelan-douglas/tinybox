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
class_name SpawnPoint

@onready var area : Area3D = $Area3D
var team_name : String = "Default"

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "scale", "team_name"]

# set colour of spawns to team colour
func set_property(property : StringName, value : Variant) -> void:
	match(property):
		"team_name":
			team_name = str(value)
			var mat := StandardMaterial3D.new()
			var team : Team = Global.get_world().get_current_map().get_teams().get_team(team_name)
			mat.albedo_color = team.colour
			
			var add_material_to_cache := true
			# Check over the graphics cache to make sure we don't already have the same material created.
			for cached_material : Material in Global.graphics_cache:
				# If the material texture and colour matches (that's all that really matters):
				if (cached_material.albedo_color == team.colour):
					# Instead of using the duplicate material we created, use the cached material.
					mat = cached_material
					# Don't add this material to cache, since we're pulling it from the cache already.
					add_material_to_cache = false
			# Add the material to the graphics cache if we need to.
			if add_material_to_cache:
				Global.add_to_graphics_cache(mat)
			$MeshInstance3D.set_surface_override_material(0, mat)
		_:
			set(property, value)

func occupied() -> bool:
	for b in area.get_overlapping_bodies():
		if b is RigidPlayer:
			return true
	return false
