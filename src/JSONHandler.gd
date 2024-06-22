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

func search_for_entry(json: Dictionary, tree: String) -> Variant:
	var found_entry := ""
	# array of all the entries in the path
	var entries : Array = tree.split("/")
	# the last entry in the tree, the one we are looking for
	var last_entry := entries.size() - 1
	
	#print("looking at ", entries[0], ", trying to find ", entries[last_entry])
	# if this is the last entry
	if json.has(entries[0]):
		if (entries[0] == entries[last_entry]):
			return json[entries[0]]
		else:
			# make a new tree, starting at the next tree iteration
			var pos := tree.find(str(entries[1]))
			var new_tree := tree.substr(pos)
			
			return search_for_entry(json[entries[0]] as Dictionary, new_tree)
	else:
		var err := str("JSON entry not found: ", tree, " (please report)")
		return err

func find_entry_in_file(key: String, file_name: String = "locale_en") -> Variant:
	var file := FileAccess.open(str("res://data/json/", file_name, ".json"), FileAccess.READ)
	var json := JSON.new()
	var parse_result : Variant = json.parse_string(file.get_as_text())
	
	if parse_result == null:
		printerr("JSONHandler: JSON parse result threw error: ", parse_result.error)
		return null
	else:
		var dict : Dictionary = parse_result as Dictionary
		return search_for_entry(dict, key)
