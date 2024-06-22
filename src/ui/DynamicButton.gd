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

extends Button
class_name DynamicButton

@export var json_text : String = ""
@export var grab_initial_focus := false

func _ready() -> void:
	set_text_to_json(json_text)
	if is_visible_in_tree() && grab_initial_focus:
		grab_focus()

func set_text_to_json(json : String) -> void:
	json_text = json
	if json_text != "":
		text = JsonHandler.find_entry_in_file(json_text)
