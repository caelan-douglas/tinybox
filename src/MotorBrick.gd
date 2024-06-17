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
class_name MotorBrick

var speed = 0
var target_speed = 20
var steer = 0

var parent_seat = null
var in_water = false

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : Brick.BrickMaterial) -> void:
	# call base function
	super(new)

	match(new):
		# Metal
		BrickMaterial.METAL:
			target_speed = 23
		# Plastic
		BrickMaterial.PLASTIC:
			target_speed = 18
		# Rubber
		BrickMaterial.RUBBER:
			target_speed = 22
		# Wood, Charred Wood
		_:
			target_speed = 20

@rpc("any_peer", "call_local")
func set_parent_seat(seat_as_path : NodePath) -> void:
	parent_seat = get_node(seat_as_path)

func _ready():
	super()
	# only show dir arrow to owner of brick
	if !is_multiplayer_authority():
		$DirectionArrow.visible = false

# Remove this brick
@rpc("call_local")
func despawn() -> void:
	if parent_seat:
		if parent_seat.attached_motors.has(self):
			parent_seat.attached_motors.erase(self)
	super()

# Receive input from a player (motor seat).
@rpc("any_peer", "call_local")
func receive_input(input_forward : float, input_steer : float) -> void:
	speed = input_forward
	steer = input_steer

func enter_state() -> void:
	super()
	
	match _state:
		States.BUILD:
			$DirectionArrow.visible = true
		_:
			$DirectionArrow.visible = false

func _physics_process(delta):
	super(delta)
	
	var straight_mult = 1
	if steer == 0:
		straight_mult = 2
		
	angular_velocity = transform.basis.z * speed * target_speed * straight_mult
	
	# if this is controlled by a seat
	if parent_seat:
		# rotation relative to seat left/right
		var z_vec = global_transform.basis.z
		var rel_pos = parent_seat.global_position - global_position
		var dot_z = z_vec.dot(rel_pos)
		
		# determines if wheel is on left or right side of seat.
		if dot_z > 0:
			dot_z = 1
		elif dot_z < 0:
			dot_z = -1
		else: dot_z = 0
		
		# set velocity for tank turning
		angular_velocity -= transform.basis.z * steer * dot_z * target_speed
		
		# in water propulsion
		if in_water:
			# max speed 11 underwater
			if linear_velocity.length() < 11:
				apply_central_force(parent_seat.transform.basis.z * speed * -500)
			if steer != 0:
				# apply angular velocity to all bricks
				if brick_groups.groups.has(str(group)):
					for b in brick_groups.groups[str(group)]:
						if b != null:
							b.angular_velocity = parent_seat.transform.basis.y * -steer * 3

func entered_water() -> void:
	super()
	in_water = true

func exited_water() -> void:
	super()
	in_water = false
