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

extends RigidBody3D
class_name SyncedRigidbody3D

# If this body is spawned by a player, it will be referenced here.
var player_from : RigidPlayer = null
# How long from spawn before this despawns.
var despawn_time : float = -1
# Whether or not to add a MultiplayerSynchronizer to this at spawn.
@export var add_synchronizer_on_spawn  := false
var synchronizer : MultiplayerSynchronizer = null

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_player_left)
	if (despawn_time != -1) && despawn_time > 0:
		var despawn_timer : SceneTreeTimer = get_tree().create_timer(despawn_time)
		despawn_timer.connect("timeout", despawn)
	
	# add a synchronizer if we don't have one
	if add_synchronizer_on_spawn:
		add_synchronizer()
	
	synchronizer = get_node_or_null("MultiplayerSynchronizer")

# Remove this
@rpc("call_local")
func despawn() -> void:
	queue_free()

# Add a multiplayer synchronizer.
func add_synchronizer() -> void:
	var sync := MultiplayerSynchronizer.new()
	
	var pos_as_path : String = str(get_path(), ":position")
	var rot_as_path : String = str(get_path(), ":rotation")
	var src := SceneReplicationConfig.new()
	src.add_property(pos_as_path)
	src.add_property(rot_as_path)
	src.property_set_watch(pos_as_path, true)
	src.property_set_watch(rot_as_path, true)
	sync.delta_interval = 0.04
	sync.replication_interval = 0.04
	sync.replication_config = src
	add_child(sync)

# If the authority of this object has left the game, set the authority to the server.
func _player_left(id : int) -> void:
	if id != 1 && id == get_multiplayer_authority():
		set_multiplayer_authority(1)

func entered_water() -> void:
	gravity_scale = -0.05
	linear_damp = 0.8

func exited_water() -> void:
	gravity_scale = 1
	linear_damp = 0

@rpc("any_peer", "call_local", "reliable")
func deflect(player_facing : Vector3) -> void:
	linear_velocity = -linear_velocity
	rotate(Vector3.UP, PI)

@rpc("any_peer", "call_local", "unreliable")
func apply_force_rpc(dir : Vector3) -> void:
	apply_force(dir)
