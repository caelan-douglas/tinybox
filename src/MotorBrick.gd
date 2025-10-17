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
var max_speed : float = 80
var steer : float = 0
var flip_motor_side : bool = false
var tag : MotorController.Tag = MotorController.Tag.BLUE

var parent_controller : MotorController = null
var in_water := false

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	if property == "flip_motor_side":
		flip_motor_side = value as bool
		if !flip_motor_side:
			$Smoothing/MotorMesh.position.z = brick_scale.x * 0.5
		else:
			$Smoothing/MotorMesh.position.z = -brick_scale.x * 0.5
	if property == "tag":
		if $MotorTag != null:
			tag = value as int
			match (tag):
				MotorController.Tag.BLUE:
					$MotorTag.modulate = Color("2e77ff")
				MotorController.Tag.RED:
					$MotorTag.modulate = Color("f10036")
				MotorController.Tag.GREEN:
					$MotorTag.modulate = Color("00996c")
				MotorController.Tag.YELLOW:
					$MotorTag.modulate = Color("e69f00")

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : Brick.BrickMaterial) -> void:
	# call base function
	super(new)

@rpc("any_peer", "call_local")
func set_parent_controller(as_path : NodePath) -> void:
	parent_controller = get_node(as_path)

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "_material", "_colour", "immovable", "joinable", "indestructible", "flip_motor_side", "max_speed", "tag"]

func _ready() -> void:
	super()

# Remove this brick
@rpc("any_peer", "call_local")
func despawn(check_world_groups : bool = true) -> void:
	if parent_controller:
		if parent_controller.attached_motors.has(self):
			parent_controller.attached_motors.erase(self)
	super()

# Debug
var last_input_time : int = 0
# Receive input from a player (motor seat).
func receive_input(input_forward : float, input_steer : float) -> void:
	speed = input_forward
	steer = input_steer
	last_input_time = Time.get_ticks_msec()

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	super(props)
	# Don't show indicator to newly joined clients
	$DirectionArrow.visible = false
	$MotorTag.visible = false

func enter_state() -> void:
	super()
	
	match _state:
		States.BUILD:
			$DirectionArrow.visible = true
			$MotorTag.visible = true
		_:
			if Global.get_world().get_current_map() is Editor:
				var editor : Editor = Global.get_world().get_current_map() as Editor
				if editor.test_mode:
					$DirectionArrow.visible = false
					$MotorTag.visible = false
			else:
				$DirectionArrow.visible = false
				$MotorTag.visible = false

func _physics_process(delta : float) -> void:
	super(delta)
	
	var straight_mult : float = 1
	if steer == 0:
		straight_mult = 3
	
	var to_velocity : Vector3 = transform.basis.z * speed * max_speed * straight_mult
	
	if to_velocity.length() > angular_velocity.length():
		# larger wheels accel slower
		var divisor : float = clamp((mass_mult * mass_mult) * 0.2, 1, 999)
		angular_velocity = lerp(angular_velocity, to_velocity, 0.010 / divisor)
	# faster decel
	elif angular_velocity.length() != 0:
		angular_velocity = lerp(angular_velocity, to_velocity, 1/angular_velocity.length() * 0.5)
	
	# if this is controlled by a seat
	if parent_controller:
		# rotation relative to seat left/right
		var z_vec : Vector3 = global_transform.basis.z
		var rel_pos : Vector3 = parent_controller.global_position - global_position
		var dot_z : float = z_vec.dot(rel_pos)
		
		# determines if wheel is on left or right side of seat.
		if dot_z > 0:
			dot_z = 1
		elif dot_z < 0:
			dot_z = -1
		else: dot_z = 0
		
		# set velocity for tank turning
		var divisor : float = clamp(mass_mult * 0.7, 1, 999)
		angular_velocity = lerp(angular_velocity, transform.basis.z * steer * -dot_z * max_speed * 0.2, 0.1 / divisor)
		

func entered_water() -> void:
	super()
	in_water = true

func exited_water() -> void:
	super()
	in_water = false
