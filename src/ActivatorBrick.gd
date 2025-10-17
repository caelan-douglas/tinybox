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

extends MotorController
class_name ActivatorBrick

var acceleration : int = 0
var steering : int = 0
var follow_nearby_player : bool = true

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	# set mass after determing mass mult from size
	mass = 10 * mass_mult

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : Brick.BrickMaterial) -> void:
	# don't change material on activator bricks
	pass

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	# don't change colour
	pass

func _init() -> void:
	_brick_spawnable_type = "brick_activator"
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "immovable", "indestructible", "acceleration", "steering", "follow_nearby_player", "tag"]

func _ready() -> void:
	super()
	if Global.get_world().tbw_loading:
		await Global.get_world().tbw_loaded
	await get_tree().create_timer(0.5).timeout
	activate()

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	super(props)
	# Don't show indicator to newly joined clients
	$DirectionArrow.visible = false

func enter_state() -> void:
	super()
	
	match _state:
		States.BUILD:
			$DirectionArrow.visible = true
		_:
			if Global.get_world().get_current_map() is Editor:
				var editor : Editor = Global.get_world().get_current_map() as Editor
				if editor.test_mode:
					$DirectionArrow.visible = false
			else:
				$DirectionArrow.visible = false

func _physics_process(delta : float) -> void:
	super(delta)
	if attached_motors.size() > 0:
		if follow_nearby_player:
			var nearest : RigidPlayer = null
			var nearest_dist : float = 999999
			for player : RigidPlayer in Global.get_world().rigidplayer_list:
				var dist := player.global_position.distance_to(self.global_position)
				if dist < nearest_dist:
					nearest = player
					nearest_dist = dist
			
			if nearest != null:
				var z_vec : Vector3 = global_transform.basis.z
				var x_vec : Vector3 = global_transform.basis.x
				var rel_pos : Vector3 = (global_position - nearest.global_position).normalized()
				var accel : float = z_vec.dot(rel_pos)
				var steer : float = -x_vec.dot(rel_pos)
				
				if accel > 0:
					accel = 1
				elif accel < 0:
					accel = -1
				else: accel = 0
				
				drive.rpc(accel, (steer * accel))
				
		else:
			drive.rpc(acceleration, steering)
