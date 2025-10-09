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

extends Node
class_name BrickGroups

@export var groups : Dictionary = {}

var last_checked_time : int = 0
# Determines the groups for bricks in the world.
func check_world_groups(override : bool = false) -> void:
	# don't check too frequently
	var curr_time : int = Time.get_ticks_msec()
	if curr_time - last_checked_time < 500 && !override:
		return
	last_checked_time = curr_time
	groups = {}
	
	print("Checking world brick groups.")
	
	# reset all groups
	for b : Variant in Global.get_world().get_children():
		if b != null:
			if b is Brick:
				set_brick_group(b as Brick, str(b.name))
	
	for b : Variant in Global.get_world().get_children():
		if b != null:
			if b is Brick:
				if b.joint_detector.has_overlapping_bodies():
					for other : Variant in b.joint_detector.get_overlapping_bodies():
						if other is Brick:
							if other != b && other.group != b.group && other.groupable && b.joinable && other.joinable:
								var other_size := 0
								var my_size := 0
								for othergroup : Variant in groups[other.group]:
									other_size += 1
								for mygroup : Variant in groups[b.group]:
									my_size += 1
								
								var larger_group_name := ""
								var smaller_group_name := ""
								if my_size >= other_size || other_size == 1:
									larger_group_name = b.group
									smaller_group_name = other.group
								else:
									larger_group_name = other.group
									smaller_group_name = b.group
								
								# for clearing later
								for smaller_group_brick : Brick in groups[smaller_group_name]:
									# join to larger group
									set_brick_group(smaller_group_brick, larger_group_name)
								# clear old group
								groups[smaller_group_name] = []

func set_brick_group(b : Brick, group_name : String) -> void:
	b.group = group_name
	if !groups.has(group_name):
		groups[group_name] = []
	groups[group_name].append(b)
