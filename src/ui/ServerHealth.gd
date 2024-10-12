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

extends Label

@onready var update_timer : Timer = Timer.new()

func _ready() -> void:
	add_child(update_timer)
	update_timer.wait_time = 2
	update_timer.connect("timeout", _on_update)
	update_timer.start()

func _on_update() -> void:
	if Global.connected_to_server && !Global.server_mode():
		check_server_health.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func check_server_health(id_from : int) -> void:
	# 45 is the target physics fps
	var health : int = ((Engine.get_frames_per_second() / 45) * 100)
	health = clamp(health, 0, 100)
	# send the client response back.
	send_server_health.rpc_id(id_from, health)

@rpc("any_peer", "call_local", "reliable")
func send_server_health(health : int) -> void:
	text = str("Server health: ", health, "%")
	if health < 71:
		modulate = Color.RED.lerp(Color("#ffffff"), float((health * (100/70)) * 0.01))
	else:
		modulate = Color("#ffffff")
