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
class_name MotorSeat

# The player who is controlling this motorseat.
var controlling_player : RigidPlayer
@onready var sit_area : Area3D = $SitArea
@onready var sit_collider: CollisionShape3D = $SitArea/CollisionShape3D

func _init() -> void:
	super()
	_brick_spawnable_type = "brick_motor_seat"

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	if property == "brick_scale":
		if value is Vector3:
			# scale up sit area for seats
			var scale_new : Vector3 = (value as Vector3).round()
			if scale_new != Vector3(1, 1, 1):
				sit_collider.shape = sit_collider.shape.duplicate()
				sit_collider.shape.size = scale_new + Vector3(0.1, 0.1, 0.1)

# Lights this brick on fire.
@rpc("any_peer", "call_local")
func light_fire() -> void:
	super()
	# light anyone occupying the seat on fire too
	if controlling_player:
		if controlling_player is RigidPlayer:
			controlling_player.light_fire.rpc()

# Explodes this brick. The brick will set on fire if it can, and the explosion is strong enough. Sends
# the brick flying in a direction based on the position of the explosion.
# Arg 1: The position of the explosion. Required to determine impulse on the brick.
# Arg 2: From who this explosion came from.
@rpc("any_peer", "call_local")
func explode(explosion_position : Vector3, from_whom : int = -1, _explosion_force : float = 4) -> void:
	super.explode(explosion_position, from_whom, _explosion_force)
	# only run on authority
	if !is_multiplayer_authority(): return
	if controlling_player:
		controlling_player.seat_destroyed.rpc_id(controlling_player.get_multiplayer_authority())
		controlling_player = null

func _ready() -> void:
	# Connect the seat area detector.
	sit_area.connect("body_entered", _on_sit_entered)
	super()

# If something attempts to sit in this
func _on_sit_entered(body : Node3D) -> void:
	# do not sit in seats being built
	if _state != States.BUILD && _state != States.DUMMY_BUILD:
		if body is RigidPlayer:
			if controlling_player == null:
				sit(body as RigidPlayer)
				# set freeze mode to static once body is unglued
				freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

# Set the controlling player of this vehicle via rpc.
@rpc("any_peer", "call_local", "reliable")
func set_controlling_player(player_id : int) -> void:
	if player_id == -1:
		controlling_player = null
	else:
		controlling_player = Global.get_world().get_node_or_null(str(player_id))

# Remove this brick
@rpc("any_peer", "call_local")
func despawn(check_world_groups : bool = true) -> void:
	if controlling_player != null:
		controlling_player.seat_destroyed.rpc_id(controlling_player.get_multiplayer_authority())
	else:
		controlling_player = null
	super()

# Sets the controlling player of this seat, and gives control to the player that sat down.
func sit(player : RigidPlayer) -> void:
	# only execute for owner of seat
	if !is_multiplayer_authority(): return
	
	# set the controlling player for ALL peers
	set_controlling_player.rpc(player.get_multiplayer_authority())
	activate()
	var player_id : int = player.get_multiplayer_authority()
	player.entered_seat.rpc_id(player_id, self.get_path())

func _physics_process(delta : float) -> void:
	super(delta)
