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

extends TextEdit

@export var char_limit : int = 130
var caret_line : int = 0
var caret_col : int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("text_changed", _on_text_changed)

func limit_chars() -> void:
	if text.length() > char_limit:
		text = text.substr(0, char_limit)
		set_caret_line(caret_line)
		set_caret_column(caret_col)
	caret_line = get_caret_line()
	caret_col = get_caret_column()
	
func _on_text_changed() -> void:
	limit_chars()
