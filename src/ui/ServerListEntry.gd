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
class_name ServerListEntry

# UDP ping for each server
var udp := PacketPeerUDP.new()
var connected : bool = false

func set_info(s_name : String, s_address: String, s_hosts : String) -> void:
	var name_label : Label = $HBox/ServerInfo/Name
	var address_label : Label = $HBox/ServerInfo/Address
	var hosts_label : Label = $HBox/ServerInfo/Hosts
	var join_button : Button = $HBox/Join
	
	name_label.text = s_name
	address_label.text = s_address
	hosts_label.text = str("Hosted by: ", s_hosts)
	
	update_server_status_label(false)
	ping_server(s_address)
	
	var main : Main = get_tree().current_scene
	join_button.connect("pressed", main._on_join_pressed.bind(s_address, false))

func update_server_status_label(mode : bool) -> void:
	var status_label : Label = $HBox/ServerInfo/Status
	if mode == false:
		status_label.text = "Offline"
		status_label.self_modulate = Color("#ff2360")
	else:
		status_label.text = "Online"
		status_label.self_modulate = Color("#00f88f")

var last_packet_count : int = 0
func ping_server(address : String) -> void:
	var ip := IP.resolve_hostname(address, IP.TYPE_IPV4)
	var main : Main = get_tree().current_scene
	udp.connect_to_host(str(ip), main.SERVER_INFO_PORT)
	
	while true:
		# Try to contact server
		udp.put_packet("0".to_utf8_buffer())
		if udp.get_available_packet_count() > last_packet_count:
			last_packet_count = udp.get_available_packet_count()
			# server is available, show visually
			update_server_status_label(true)
		else:
			update_server_status_label(false)
		# check every 2s
		await get_tree().create_timer(2).timeout
