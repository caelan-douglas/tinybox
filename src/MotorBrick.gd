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

var speed : float = 0
var target_speed : float = 20
var steer : float = 0

var parent_seat : MotorSeat = null
var in_water := false

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : Brick.BrickMaterial) -> void:
	# call base function
	super(new)

	match(new):
		# Metal
		BrickMaterial.METAL:
			target_speed = 46
		# Plastic
		BrickMaterial.PLASTIC:
			target_speed = 36
		# Rubber
		BrickMaterial.RUBBER:
			target_speed = 44
		# Wood, Charred Wood
		_:
			target_speed = 40

@rpc("any_peer", "call_local")
func set_parent_seat(seat_as_path : NodePath) -> void:
	parent_seat = get_node(seat_as_path)

func _ready() -> void:
	super()
	# only show dir arrow to owner of brick
	if !is_multiplayer_authority():
		$DirectionArrow.visible = false

# Remove this brick
@rpc("call_local")
func despawn(check_world_groups : bool = true) -> void:
	if parent_seat:
		if parent_seat.attached_motors.has(self):
			parent_seat.attached_motors.erase(self)
	super()

# Receive input from a player (motor seat).
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

func _physics_process(delta : float) -> void:
	super(delta)
	
	var straight_mult : float = 1
	if steer == 0:
		straight_mult = 3
	
	var to_velocity : Vector3 = transform.basis.z * speed * target_speed * straight_mult
	
	if to_velocity.length() > angular_velocity.length():
		angular_velocity = lerp(angular_velocity, to_velocity, 0.025)
	# faster decel
	elif angular_velocity.length() != 0:
		angular_velocity = lerp(angular_velocity, to_velocity, 1/angular_velocity.length() * 0.5)
	
	# if this is controlled by a seat
	if parent_seat:
		# rotation relative to seat left/right
		var z_vec : Vector3 = global_transform.basis.z
		var rel_pos : Vector3 = parent_seat.global_position - global_position
		var dot_z : float = z_vec.dot(rel_pos)
		
		# determines if wheel is on left or right side of seat.
		if dot_z > 0:
			dot_z = 1
		elif dot_z < 0:
			dot_z = -1
		else: dot_z = 0
		
		# set velocity for tank turning
		angular_velocity = lerp(angular_velocity, transform.basis.z * steer * -dot_z * target_speed * 0.7, 0.1)
		
		# in water propulsion
		if in_water:
			# max speed 11 underwater
			if linear_velocity.length() < 11:
				apply_central_force(parent_seat.transform.basis.z * speed * -500)
			if steer != 0:
				# apply angular velocity to all bricks
				if brick_groups.groups.has(str(group)):
					for b : Variant in brick_groups.groups[str(group)]:
						if b != null:
							b = b as Brick
							b.angular_velocity = parent_seat.transform.basis.y * -steer * 3

func entered_water() -> void:
	super()
	in_water = true

func exited_water() -> void:
	super()
	in_water = false
