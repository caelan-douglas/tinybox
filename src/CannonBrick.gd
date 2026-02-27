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

extends MotorBrick
class_name CannonBrick

@onready var firecracker : PackedScene = preload("res://data/scene/firecracker/Firecracker.tscn")
@onready var cannon_mesh : MeshInstance3D = $Smoothing/model/Cannon

var force : int = 20
var cooldown : int = 10
var automatic : bool = true
var team_name : String = "Default"

var target : Vector3 = Vector3.ZERO

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	# set mass after determing mass mult from size
	mass = 10 * mass_mult
	
	if property == "cooldown":
		cooldown = clamp(value, 2, 50)

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

func receive_input(input_forward : float, input_steer : float) -> void:
	pass

@rpc("any_peer", "call_local")
func set_parent_controller(as_path : NodePath) -> void:
	super(as_path)

func _init() -> void:
	_brick_spawnable_type = "brick_cannon"
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "immovable", "joinable", "indestructible", "force", "cooldown", "automatic", "team_name", "tag"]

func _ready() -> void:
	super()
	if Global.get_world().tbw_loading:
		await Global.get_world().tbw_loaded

func resize_mesh() -> void:
	super()
	cannon_mesh.scale = Vector3(brick_scale.y, brick_scale.y, brick_scale.y)

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	super(props)
	# Don't show indicator to newly joined clients
	$DirectionArrow.visible = false

func enter_state() -> void:
	super()
	
	match _state:
		States.BUILD:
			$MotorTag.visible = true
			$DirectionArrow.visible = true
		_:
			if Global.get_world().get_current_map() is Editor:
				var editor : Editor = Global.get_world().get_current_map() as Editor
				if editor.test_mode:
					$MotorTag.visible = false
					$DirectionArrow.visible = false
			else:
				$MotorTag.visible = false
				$DirectionArrow.visible = false

var last_fire_time : int = 0
func _physics_process(delta : float) -> void:
	super(delta)
	
	if automatic:
		var nearest : RigidPlayer = null
		var nearest_dist : float = 999999
		for player : RigidPlayer in Global.get_world().rigidplayer_list:
			var dist := player.global_position.distance_to(self.global_position)
			if dist < nearest_dist:
				nearest = player
				nearest_dist = dist
		if nearest != null:
			target = nearest.global_position
	else:
		if parent_controller == null: return
		if parent_controller is not MotorSeat: return
		# non-automatic cannons point in look direction of driver
		target = global_position - parent_controller.driver_look_direction
	
	if target != null:
		if global_position.distance_to(target) > 15:
			return
		
		cannon_mesh.rotation.y = lerp_angle(cannon_mesh.rotation.y, atan2((global_position - target).x, (global_position - target).z) - rotation.y, 0.035)
		
		if automatic:
			if Time.get_ticks_msec() - last_fire_time > (cooldown * 100):
				fire_cannon()

@rpc("any_peer", "call_local", "reliable")
func fire_cannon() -> void:
	if Time.get_ticks_msec() - last_fire_time < (cooldown * 100): return
	# apply recoil force when firing
	apply_impulse(cannon_mesh.global_transform.basis.z * force * 2)
	last_fire_time = Time.get_ticks_msec()
	
	# only server spawns projectiles
	if !multiplayer.is_server(): return
	
	var p := firecracker.instantiate()
	p.despawn_time = 2
	Global.get_world().add_child(p, true)
	p.linear_velocity = -cannon_mesh.global_transform.basis.z * force
	p.global_position = global_position - cannon_mesh.global_transform.basis.z
