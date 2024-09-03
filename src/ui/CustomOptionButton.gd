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

# OptionButton with a signal to pass the selected item's ID instead of idx.
extends OptionButton
class_name CustomOptionButton
signal item_selected_with_id(id : int)

func _ready() -> void:
	self.connect("item_selected", _on_item_selected)

# Like "item_selected" but with ID instead of index.
func _on_item_selected(item_index : int) -> void:
	emit_signal("item_selected_with_id", get_item_id(item_index))
