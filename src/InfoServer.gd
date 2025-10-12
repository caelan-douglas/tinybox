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

extends Node
class_name InfoServer

const SERVER_INFO_PORT = 30816
# for server info
var udp_server : UDPServer = UDPServer.new()

func start_udp_listener() -> void:
	udp_server.listen(SERVER_INFO_PORT)

# Listen on the udp server.
func _process(delta : float) -> void:
	udp_server.poll()
	if udp_server.is_connection_available():
		var peer : PacketPeerUDP = udp_server.take_connection()
		# Reply w/ player count
		peer.put_packet(str(Global.get_world().rigidplayer_list.size(), ";", (get_tree().current_scene as Main).server_version).to_utf8_buffer())
