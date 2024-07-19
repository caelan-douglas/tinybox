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
class_name DynamicLabel

@export var json_text : String = ""
@export var raw_format := false

func _ready() -> void:
	if json_text != "":
		if !raw_format:
			text = JsonHandler.find_entry_in_file(json_text)
		else:
			text = format(json_text)
	elif raw_format && text != "":
		text = format(text)

func update_text() -> void:
	if json_text != "":
		text = JsonHandler.find_entry_in_file(json_text)

func format(what : String) -> String:
	what = what.replace("%version%", get_tree().current_scene.display_version as String)
	return what
