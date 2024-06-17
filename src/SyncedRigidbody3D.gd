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
var player_from = null
# How long from spawn before this despawns.
var despawn_time = -1
# Whether or not to add a MultiplayerSynchronizer to this at spawn.
@export var add_synchronizer_on_spawn = false

var synchronizer = null

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_player_left)
	if (despawn_time != -1) && despawn_time > 0:
		var despawn_timer = get_tree().create_timer(despawn_time)
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
	var sync = MultiplayerSynchronizer.new()
	
	var pos_as_path = str(get_path(), ":position")
	var rot_as_path = str(get_path(), ":rotation")
	var src = SceneReplicationConfig.new()
	src.add_property(pos_as_path)
	src.add_property(rot_as_path)
	src.property_set_watch(pos_as_path, true)
	src.property_set_watch(rot_as_path, true)
	sync.delta_interval = 0.04
	sync.replication_interval = 0.04
	sync.replication_config = src
	add_child(sync)

# sync properties with client over rpc
@rpc("any_peer", "call_remote")
func _sync_properties_spawn(args : Array) -> void:
	global_position = args[0]
	global_rotation = args[1]
	set_multiplayer_authority(args[2])

# When a peer connects, sync properties about this to them.
func _on_peer_connected(id : int) -> void:
	if !is_multiplayer_authority(): return
	_sync_properties_spawn.rpc_id(id, [global_position, global_rotation, get_multiplayer_authority()])

# If the authority of this object has left the game, set the authority to the server.
func _player_left(id : int) -> void:
	if id != 1 && id == get_multiplayer_authority():
		set_multiplayer_authority(1)

func entered_water() -> void:
	gravity_scale = -0.05
	linear_damp = 0.8
	angular_damp = 0.5

func exited_water() -> void:
	gravity_scale = 1
	linear_damp = 0
	angular_damp = 0.3

@rpc("any_peer", "call_local", "reliable")
func deflect(player_facing) -> void:
	linear_velocity = -linear_velocity
	rotate(Vector3.UP, PI)

@rpc("any_peer", "call_local", "unreliable")
func apply_force_rpc(dir) -> void:
	apply_force(dir)
