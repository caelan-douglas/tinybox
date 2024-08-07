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

extends AnimatedList

@onready var list : Control = $List

func _ready() -> void:
	var load_file := FileAccess.open(str("res://contributors.txt"), FileAccess.READ)
	if load_file != null:
		while not load_file.eof_reached():
			var line := str(load_file.get_line())
			var label : Label = Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.text = line
			list.add_child(label)
	super()
