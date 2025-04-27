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

# Toggles visiblity of two objects based on special dates or holidays.
extends Node3D

enum Dates {
	XMAS
}

@export var special_date : Dates = Dates.XMAS
@export var set_visible_to_what : bool = true

func _ready() -> void:
	var date := Time.get_datetime_dict_from_system()
	visible = !set_visible_to_what
	match special_date:
		# Any day from Dec 12 - Jan 8
		Dates.XMAS:
			if date.month == 12:
				if date.day > 11:
					visible = set_visible_to_what
			elif date.month == 1:
				if date.day < 8:
					visible = set_visible_to_what
