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
var ms_sent : float = 0
var ms_recieved : float = 0

func _ready() -> void:
	add_child(update_timer)
	update_timer.wait_time = 2
	update_timer.connect("timeout", _on_ping_update)
	update_timer.start()

func _on_ping_update() -> void:
	if Global.connected_to_server:
		# get the current time in ms at ping send.
		ms_sent = Time.get_ticks_msec()
		# server should not ping itself
		if multiplayer.get_unique_id() != 1:
			ping_server.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_remote", "reliable")
func ping_server(id_from : int) -> void:
	# send the client a ping back.
	recieve_ping.rpc_id(id_from)

@rpc("any_peer", "call_remote", "reliable")
func recieve_ping() -> void:
	# as client, get ping.
	ms_recieved = Time.get_ticks_msec()
	text = str("Ping: ", ms_recieved - ms_sent)
	ms_recieved = 0
	ms_sent = 0
