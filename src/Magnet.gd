# Tinybox
# Copyright (C) 2023-present Caelan Douglas Carmen Lamprecht
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
class_name Magnet

var north_pos : Vector3 = Vector3.ZERO
var south_pos : Vector3 = Vector3.ZERO

@onready var magnet_area : Area3D = $MagnetDetectRegion
@onready var magnet_area_collision : CollisionShape3D = $MagnetDetectRegion/CollisionShape3D
# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	# set mass after determing mass mult from size
	mass = 10 * mass_mult
	if magnet_area_collision.shape is SphereShape3D:
		magnet_area_collision.shape.radius = 7*mass_mult
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

 #-> |_| ->


func _init() -> void:
	_brick_spawnable_type = "brick_magnet"
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "immovable", "indestructible",]

func _ready() -> void:
	super()
	self.name = "magnet"
	await get_tree().create_timer(0.5).timeout
	unfreeze_entire_group()

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	super(props)

func enter_state() -> void:
	super()

func _on_sleeping_state_changed() -> void:
	# If we are sleeping, and we are NOT glued, and we are NOT in a group (eg. lone brick)
	pass
		
func _physics_process(delta : float) -> void:
	#super(delta)
	var magnet_area_others : = magnet_area.get_overlapping_bodies()
	for other_magnet in magnet_area_others:
		#var a: string = other_magnet.w
		print(other_magnet.name)
		if other_magnet is not Magnet or other_magnet == self:
			continue
			
		north_pos = transform.basis.y * (brick_scale.y+1)/2 #up vector relative to brick * 
		south_pos = - transform.basis.y * (brick_scale.y-1)/2
		
		var distance : float = (other_magnet.global_position - global_position).length()
		
		var aaa : float = other_magnet.north_pos.dot(north_pos)
		var bbb : float = other_magnet.north_pos.dot(south_pos)
		var ccc : float = other_magnet.south_pos.dot(north_pos)
		var ddd : float = other_magnet.south_pos.dot(south_pos)
		
		var force_magnitude1 : float = clampf(1 / aaa, 0.001, 1)
		var force_magnitude2 : float = clampf(1 / bbb, 0.001, 1)
		var force_magnitude3 : float = clampf(1 / ccc, 0.001, 1)
		var force_magnitude4 : float = clampf(1 / ddd, 0.001, 1)
		
		var northA_northB : Vector3 = mass_mult * 100* force_magnitude1 * (other_magnet.north_pos - north_pos)
		var northA_southB : Vector3 = mass_mult * 100* force_magnitude2 * (other_magnet.north_pos - south_pos)
		var southA_northB : Vector3 = mass_mult * 100* force_magnitude3 * (other_magnet.south_pos - north_pos)
		var southA_southB : Vector3 = mass_mult* 100* force_magnitude4 * (other_magnet.south_pos - south_pos)
		
		apply_force(northA_northB, north_pos)
		apply_force(northA_southB, north_pos)
		apply_force(southA_northB, south_pos)
		apply_force(southA_southB, south_pos)
	
