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

func _ready() -> void:
	var file := FileAccess.open(str("res://data/json/server_list.json"), FileAccess.READ)
	var json := JSON.new()
	var parse_result : Variant = json.parse_string(file.get_as_text())
	
	# failed
	if parse_result == null:
		return
	
	for dict : Dictionary in parse_result:
		add_server(dict)

@onready var server_list_entry : PackedScene = preload("res://data/scene/ui/ServerListEntry.tscn")
func add_server(server_info : Dictionary) -> void:
	var s_name : String = server_info["name"]
	var s_address : String = server_info["address"]
	var s_hosts : String = server_info["hosted_by"]
	
	var server_list_entry_i : ServerListEntry = server_list_entry.instantiate()
	var list : VBoxContainer = $ScrollContainer/List
	list.add_child(server_list_entry_i)
	server_list_entry_i.set_info(s_name, s_address, s_hosts)
