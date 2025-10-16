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

extends Brick

@onready var light : OmniLight3D = $Smoothing/OmniLight3D

var lamp_range : float = 60
var lamp_falloff : float = 8

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "_colour", "immovable", "joinable", "indestructible", "lamp_range", "lamp_falloff"]

func _ready() -> void:
	super()
	Global.connect("graphics_preset_changed", _on_graphics_preset_changed)
	_on_graphics_preset_changed()

func _on_graphics_preset_changed() -> void:
	match (Global.get_graphics_preset()):
		Global.GraphicsPresets.COOL:
			light.distance_fade_begin = lamp_range * 1.5
			light.distance_fade_shadow = lamp_range
			light.shadow_enabled = true
		Global.GraphicsPresets.BAD:
			light.distance_fade_begin = lamp_range
			light.distance_fade_shadow = lamp_range * 0.75
			light.shadow_enabled = true
		Global.GraphicsPresets.AWFUL:
			light.distance_fade_begin = lamp_range * 0.5
			light.shadow_enabled = false

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	if property == "lamp_range":
		lamp_range = value as float
		light.omni_range = lamp_range
		_on_graphics_preset_changed()
	elif property == "lamp_falloff":
		lamp_falloff = value as float
		light.omni_attenuation = clampf(lamp_falloff * 0.1, 0.1, 1)

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	# don't set colour of lamp brick, just light colour
	# so super() is skipped here
	_colour = new
	if light != null:
		light.set("light_color", new)

@rpc("call_local")
func set_material(new : Brick.BrickMaterial) -> void:
	# don't change material on lamp bricks
	pass

@rpc("call_local")
func set_glued(new : bool, affect_others : bool = true, addl_radius : float = 0) -> void:
	super(new, affect_others, addl_radius)
	if light != null:
		light.visible = false
