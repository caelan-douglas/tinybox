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
class_name CannonBrick

@onready var firecracker : PackedScene = preload("res://data/scene/firecracker/Firecracker.tscn")

var force : int = 20
var automatic : bool = true
var team_name : String = "Default"

var target : Vector3 = Vector3.ZERO

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
	_brick_spawnable_type = "brick_cannon"
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "immovable", "joinable", "indestructible", "force", "automatic", "team_name"]

func _ready() -> void:
	super()
	if Global.get_world().tbw_loading:
		await Global.get_world().tbw_loaded
	await get_tree().create_timer(0.5).timeout
	unfreeze_entire_group()

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

var tick : int = 0
func _physics_process(delta : float) -> void:
	super(delta)
	
	tick += 1
	
	var nearest : RigidPlayer = null
	var nearest_dist : float = 999999
	for player : RigidPlayer in Global.get_world().rigidplayer_list:
		var dist := player.global_position.distance_to(self.global_position)
		if dist < nearest_dist:
			nearest = player
			nearest_dist = dist
	target = nearest.global_position
	
	if target != null:
		if global_position.distance_to(target) > 15:
			return
		
		model_mesh.rotation.y = lerp_angle(model_mesh.rotation.y, atan2((global_position - target).x, (global_position - target).z), 0.035)
		
		if automatic:
			if tick % 60 == 0:
				var p := firecracker.instantiate()
				p.despawn_time = 2
				Global.get_world().add_child(p)
				p.linear_velocity = -model_mesh.global_transform.basis.z * force
				p.global_position = global_position - model_mesh.global_transform.basis.z
				# apply recoil force when firing
				apply_impulse(model_mesh.global_transform.basis.z * force * 2)
		
