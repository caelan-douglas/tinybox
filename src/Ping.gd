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

func _ready() -> void:
	add_child(update_timer)
	update_timer.wait_time = 2
	update_timer.connect("timeout", _on_ping_update)
	update_timer.start()
	
	# reset sent time to avoid waiting for response after disconnecting
	multiplayer.server_disconnected.connect(func() -> void: ms_sent = 0)

func _on_ping_update() -> void:
	if Global.connected_to_server:
		# check that response has been received from the previous ping before
		# sending another
		if ms_sent != 0:
			update_label(Time.get_ticks_msec() - ms_sent)
			return

		# server should not ping itself
		if multiplayer.get_unique_id() != 1:
			# get the current time in ms at ping send.
			ms_sent = Time.get_ticks_msec()
			ping_server.rpc_id(1, multiplayer.get_unique_id())
		else:
			# the server should show 0 ping
			update_label(0)

@rpc("any_peer", "call_remote", "reliable")
func ping_server(id_from : int) -> void:
	# send the client a ping back.
	receive_ping.rpc_id(id_from)

@rpc("any_peer", "call_remote", "reliable")
func receive_ping() -> void:
	# as client, get ping.
	update_label(Time.get_ticks_msec() - ms_sent)
	# reset the send time so the timer can send another ping
	ms_sent = 0

func update_label(ping_ms : int) -> void:
	text = str("Ping: ", ping_ms)
