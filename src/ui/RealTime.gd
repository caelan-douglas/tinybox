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

@onready var sec_timer : Timer = Timer.new()

func _ready() -> void:
	sec_timer.wait_time = 1
	sec_timer.one_shot = false
	sec_timer.connect("timeout", update_time)
	add_child(sec_timer)
	sec_timer.start()

# Shows real time in top right.
func update_time() -> void:
	if get_parent().visible:
		var dict := Time.get_datetime_dict_from_system()
		# add leading zeroes
		var hour : String = ("%02d" % dict["hour"])
		var min : String = ("%02d" % dict["minute"])
		text = str(hour, ":", min)
