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


# A group of bricks that form a premade asset, like a car, house, etc.
extends RestrictedNode3D
class_name Building

var place_on_spawn := true
var building_group := []
var first_brick_pos := Vector3.ZERO

func _init(_place_on_spawn := true) -> void:
	place_on_spawn = _place_on_spawn

func _ready() -> void:
	# only server spawns buildings
	if !multiplayer.is_server():
		# If not the server, delete self
		queue_free()
		return
	super()
	if !scheduled_for_deletion && place_on_spawn:
		place()

func place() -> void:
	# don't place nothing
	if get_children().size() < 1:
		printerr("Building: Tried to load building with nothing in it.")
		return
	# change ownership first
	for b in get_children():
		# Set Smoothing to be not top level for now, model will follow brick's
		# position
		var smoothing : Node3D = b.get_node("Smoothing")
		smoothing.top_level = false
		var old_pos : Vector3 = b.global_position
		var old_rot : Vector3 = b.global_rotation
		remove_child(b)
		# we duplicate the scene so that it syncs across clients on spawn
		# MultiplayerSpawners must have the node enter the tree under their
		# root path in order for them to sync, so we create a new node
		var bdupe : Brick = b.duplicate()
		Global.get_world().add_child(bdupe, true)
		# Update group name, otherwise the first item in this
		# building will still be group "Brick", thus causing it
		# to group with all other buildings
		bdupe.group = bdupe.name
		bdupe.global_position = old_pos
		bdupe.global_rotation = old_rot
		bdupe.change_state.rpc(Brick.States.PLACED)
		building_group.append(bdupe)
		# Reset smoothing node to top level
		smoothing.top_level = true
		# remove the original (non-dupe)
		b.queue_free()
	# wait a bit before checking joints
	await get_tree().create_timer(0.1).timeout
	
	first_brick_pos = building_group[0].global_position
	var building_group_extras := []
	# sort array by position
	building_group.sort_custom(_pos_sort)
	# first make all basic brick colliders disabled
	for b : Brick in building_group:
		b.joinable = false
		b.model_mesh.visible = false
	# now move all extra bricks (motorseat, motorbrick) to building_group_extras
	for b : Brick in building_group:
		if b is MotorBrick || b is MotorSeat:
			building_group_extras.append(b)
			building_group.erase(b)
	# resort basic bricks
	building_group.sort_custom(_pos_sort)
	# now for each basic brick:
	# 1. enable its collider
	# 2. check neighbours
	var count : int = 0
	for b : Brick in building_group:
		b.joinable = true
		b.model_mesh.visible = true
		b.check_joints()
		if count == 1:
			# recheck first brick in array on second brick check
			# (never gets chance to join)
			building_group[0].check_joints()
		count += 1
	# now for each extra brick:
	# 1. enable its collider
	# 2. check neighbours
	await get_tree().process_frame
	count = 0
	for b : Brick in building_group_extras:
		b.joinable = true
		b.model_mesh.visible = true
		b.check_joints()
		count += 1

func _pos_sort(a : Node3D, b : Node3D) -> bool:
	return a.global_position.distance_to(first_brick_pos) < b.global_position.distance_to(first_brick_pos)
