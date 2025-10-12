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

extends Control
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
	hosts_label.text = str("Host: ", s_hosts)
	
	ping_server(s_address)
	
	var main : Main = get_tree().current_scene
	join_button.connect("pressed", main._on_join_pressed.bind(s_address, true))

func update_server_status_label(mode : bool, player_count : String = "0", server_version : String = "unknown") -> void:
	var status_label : Label = $HBox/ServerInfo/Status
	var version_label : Label = $HBox/ServerInfo/Version
	if mode == false:
		status_label.text = "Offline"
		status_label.self_modulate = Color("#ff2360")
		var join_button : Button = $HBox/Join
		join_button.text = "Can't join:\nServer\noffline!"
		join_button.disabled = true
	else:
		var my_version : String = str((get_tree().current_scene as Main).server_version)
		if player_count == "1":
			status_label.text = str("Online - ", player_count, " player")
		else:
			status_label.text = str("Online - ", player_count, " players")
		if server_version != my_version:
			var join_button : Button = $HBox/Join
			join_button.text = "Can't join:\nVersion\nmismatch!"
			join_button.disabled = true
		else:
			var join_button : Button = $HBox/Join
			join_button.text = "Join"
			join_button.disabled = false
		status_label.self_modulate = Color("#00f88f")
		
	# shows on entry
	var display_version : String = server_version
	# if the number is a server version (ie. 12010), format
	if (display_version.is_valid_int()):
		display_version = Global.format_server_version(server_version)
	version_label.text = str("Version: ", display_version)

func ping_server(address : String) -> void:
	var ip := IP.resolve_hostname(address, IP.TYPE_IPV4)
	var main : Main = get_tree().current_scene
	udp.connect_to_host(str(ip), main.SERVER_INFO_PORT)
	
	# Try to contact server; first packet
	udp.put_packet("0".to_utf8_buffer())
	# First check (show online servers before list is loaded)
	await get_tree().create_timer(0.5).timeout
	check_server_status()
	while true:
		# don't check when server list is not visible
		if is_visible_in_tree():
			check_server_status()
		# check every 2s
		await get_tree().create_timer(2).timeout

func check_server_status() -> void:
	# Try to contact server
	udp.put_packet("0".to_utf8_buffer())
	if udp.get_available_packet_count() > 0:
		var packet : String = udp.get_packet().get_string_from_utf8()
		var packet_split : Array = packet.split(";")
		if packet_split.size() > 1:
			# server is available, show visually
			update_server_status_label(true, str(packet_split[0]), str(packet_split[1]))
	else:
		update_server_status_label(false)
