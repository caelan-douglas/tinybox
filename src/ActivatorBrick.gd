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

func _init() -> void:
	_brick_spawnable_type = "brick_activator"
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "_material", "_colour", "immovable", "acceleration", "steering", "follow_nearby_player"]

func _ready() -> void:
	super()
	await get_tree().create_timer(0.5).timeout
	activate()

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




