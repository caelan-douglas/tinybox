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
class_name PreviewCharacter

@onready var shirt_textures : Array = [preload("res://data/models/character/textures/fabric.jpg"), 
preload("res://data/textures/clothing/cloth_tex_0.png"), 
preload("res://data/textures/clothing/cloth_tex_1.png"), 
preload("res://data/textures/clothing/cloth_tex_2.png"), 
preload("res://data/textures/clothing/cloth_tex_3.png")]

func _ready() -> void:
	Global.connect("appearance_changed", change_appearance)
	change_appearance()

func change_appearance() -> void:
	var armature : Skeleton3D = get_node("character/Skeleton3D")
	var hair_material : Material = armature.get_node("hair_short/hair_short").get_surface_override_material(0)
	var shirt_material : Material = armature.get_node("shirt_shortsleeve").get_surface_override_material(0)
	var pants_material : Material = armature.get_node("pants").get_surface_override_material(0)
	var skin_material : Material = armature.get_node("Character_001").get_surface_override_material(0)
	
	if Global.shirt_colour != null:
		shirt_material.albedo_color = Global.shirt_colour
	if Global.pants_colour != null:
		pants_material.albedo_color = Global.pants_colour
	if Global.hair_colour != null:
		hair_material.albedo_color = Global.hair_colour
	if Global.skin_colour != null:
		skin_material.albedo_color = Global.skin_colour
	if Global.shirt != null:
		match Global.shirt:
			0:
				armature.get_node("shirt_jacket").visible = false
				armature.get_node("shirt_shortsleeve").visible = true
			1:
				armature.get_node("shirt_jacket").visible = true
				armature.get_node("shirt_shortsleeve").visible = false
	if Global.shirt_texture != null:
		shirt_material.albedo_texture = shirt_textures[Global.shirt_texture]
	if Global.hair != null:
		match Global.hair:
			1:
				armature.get_node("hair_short").visible = false
				armature.get_node("hair_ponytail").visible = true
			# bald
			2:
				armature.get_node("hair_short").visible = false
				armature.get_node("hair_ponytail").visible = false
			_:
				armature.get_node("hair_short").visible = true
				armature.get_node("hair_ponytail").visible = false
