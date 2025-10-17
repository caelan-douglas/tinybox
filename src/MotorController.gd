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

enum Tag {
	BLUE,
	RED,
	GREEN,
	YELLOW
}
const MOTOR_TAGS_AS_STRINGS : Array[String] = ["Blue", "Red", "Green", "Yellow"]

# The motors attached to this controller, determined by this controller's group.
var attached_motors := []
# Vehicle weight determined by weight of all bricks combined.
var vehicle_weight : float = 0
var tag : Tag = Tag.BLUE

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "_material", "_colour", "immovable", "joinable", "indestructible", "tag"]

func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
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

@rpc("authority", "call_local", "reliable")
func activate() -> void:
	# only execute for owner of controller
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
					# Only control wheels that have the same tag
					if b.tag == tag:
						if !attached_motors.has(b):
							attached_motors.append(b)
						# set the motorbricks parent controller to this one
						b.set_parent_controller(self.get_path())
	
	if is_multiplayer_authority():
		sync_attached_motors()
		update_weight.rpc(vehicle_weight)
		# unfreeze group so that the body that has
		# these motors is released.
		unfreeze_entire_group()

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	super(props)
	# Don't show indicator to newly joined clients
	$MotorTag.visible = false

func enter_state() -> void:
	super()
	
	match _state:
		States.BUILD:
			$MotorTag.visible = true
		_:
			if Global.get_world().get_current_map() is Editor:
				var editor : Editor = Global.get_world().get_current_map() as Editor
				if editor.test_mode:
					$MotorTag.visible = false
			else:
				$MotorTag.visible = false

func sync_attached_motors() -> void:
	var to_sync : Array[String] = []
	for m : Brick in attached_motors:
		to_sync.append(str(m.get_path()))
	update_attached_motors.rpc(to_sync)

@rpc("any_peer", "call_remote", "reliable")
func update_attached_motors(new : Array[String]) -> void:
	attached_motors = []
	for m : String in new:
		var motor := get_node_or_null(m)
		if motor != null:
			if motor is MotorBrick:
				attached_motors.append(motor)

@rpc("any_peer", "call_local", "reliable")
func update_weight(new : float) -> void:
	vehicle_weight = new

# reset vehicle weight to 0 if the controller is
# unjoined
@rpc("any_peer", "call_local", "reliable")
func unjoin() -> void:
	super()
	vehicle_weight = 0
