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


# Base class for saveable .tbw objects, such as water, trees, etc.
extends Node3D
class_name TBWObject

@export var tbw_object_type : String = ""

var properties_to_save : Array[String] = ["global_position", "global_rotation", "scale"]

func set_property(property : StringName, value : Variant) -> void:
	set(property, value)

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	for prop : String in props.keys():
		if prop != "script":
			set_property(prop, props[prop])

func properties_as_dict() -> Dictionary:
	var dict : Dictionary = {}
	for p : String in properties_to_save:
		dict[p] = get(p)
	return dict
