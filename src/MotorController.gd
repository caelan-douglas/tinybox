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
class_name MotorController

# The motors attached to this controller, determined by this controller's group.
var attached_motors := []
# Vehicle weight determined by weight of all bricks combined.
var vehicle_weight : float = 0

# Drives this controller's motors based on given input.
@rpc("any_peer", "call_local")
func drive(input_forward : float, input_steer : float) -> void:
	for motor_brick : Variant in attached_motors:
		if motor_brick != null:
			if motor_brick is MotorBrick:
				motor_brick.receive_input(input_forward, input_steer)
		else:
			attached_motors.erase(motor_brick)

# Remove this brick
@rpc("any_peer", "call_local")
func despawn(check_world_groups : bool = true) -> void:
	for b : Variant in attached_motors:
		if b != null:
			if b is MotorBrick:
				b.receive_input(0, 0)
				b.parent_controller = null
	super()

# Sets the controlling player of this seat, and gives control to the player that sat down.
func activate() -> void:
	# only execute for owner of seat
	if !is_multiplayer_authority(): return
	if Global.get_world().get_current_map() is Editor:
		var editor : Editor = Global.get_world().get_current_map() as Editor
		if !editor.test_mode:
			return
	
	# find child motors
	vehicle_weight = 0
	if brick_groups.groups.has(str(group)):
		for b : Variant in brick_groups.groups[str(group)]:
			if b != null:
				b = b as Brick
				vehicle_weight += b.mass
				if b is MotorBrick:
					if !attached_motors.has(b):
						attached_motors.append(b)
					# set the motorbricks parent seat to this one
					b.set_parent_controller(self.get_path())
	update_weight.rpc(vehicle_weight)
	# unfreeze group so that the body that has
	# these motors is released.
	unfreeze_entire_group()

@rpc("any_peer", "call_local", "reliable")
func update_weight(new : float) -> void:
	vehicle_weight = new
	
