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

@onready var map_selector : OptionButton = $VBoxContainer/MapSelection

func _ready() -> void:
	$VBoxContainer/Delete.connect("pressed", _on_delete_pressed)

func _on_delete_pressed() -> void:
	if is_visible_in_tree():
		var selected_map : String = map_selector.get_item_text(map_selector.selected)
		OS.move_to_trash(str(OS.get_user_data_dir(), "/world/", selected_map, ".tbw"))
		UIHandler.show_alert(str("The world '", selected_map, ".tbw' was moved to your device's trash bin."), 4)
	# refresh list
	map_selector.refresh()
