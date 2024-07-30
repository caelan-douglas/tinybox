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
class_name Adjuster
signal value_changed(new_val : int)

var val : int = 0

func _ready() -> void:
	$DownBig.connect("pressed", _increment_value.bind(-10))
	$Down.connect("pressed", _increment_value.bind(-1))
	$Up.connect("pressed", _increment_value.bind(1))
	$UpBig.connect("pressed", _increment_value.bind(10))

func _increment_value(amt : int) -> void:
	val += amt
	$DynamicLabel.text = str(val)
	emit_signal("value_changed", val)

