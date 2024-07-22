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
class_name ButtonBrick

@onready var explosion : PackedScene = SpawnableObjects.explosion
@onready var button_audio : AudioStreamPlayer3D = $ButtonAudio
var event : EventHandler.Event = EventHandler.Event.TELEPORT_PLAYER
var connection : String = "/root/Main/World/1"

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "_material", "_colour", "event", "connection"]

func _ready() -> void:
	super()

var last_stepped_by : Node = null
# Button stepped on.
@rpc("any_peer", "call_local", "reliable")
func stepped(by_what_node_path : NodePath) -> void:
	$ButtonAudio.play()
	var by_what : Node = get_node_or_null(by_what_node_path)
	if by_what != null:
		if by_what is Node:
			last_stepped_by = by_what
		run_event()

func run_event() -> void:
	# format any strings
	if get_node_or_null(connection) != null && last_stepped_by != null:
		match (event):
			EventHandler.Event.TELEPORT_PLAYER:
				if last_stepped_by is RigidPlayer:
					EventHandler.run_event.rpc_id(1, event, [last_stepped_by.get_multiplayer_authority(), get_node(connection).global_position])
			EventHandler.Event.EXPLODE:
				EventHandler.run_event.rpc_id(1, event, [last_stepped_by.get_multiplayer_authority(), get_node(connection).global_position])
			EventHandler.Event.CHANGE_PLAYER_TEAM:
				if last_stepped_by is RigidPlayer:
					EventHandler.run_event.rpc_id(1, event, [last_stepped_by.get_multiplayer_authority()])
