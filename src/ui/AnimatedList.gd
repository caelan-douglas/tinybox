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

extends VBoxContainer
class_name AnimatedList

func _ready() -> void:
	connect("visibility_changed", _on_visibility_changed)
	animate_list()

func _on_visibility_changed() -> void:
	if visible == true:
		animate_list()

func animate_list() -> void:
	var count : float = 0
	for c : Control in get_children():
		count += 1
		c.modulate = Color(1, 1, 1, 0)
	# don't make animation any slower than 0.15s intervals
	count = clamp(count, 8, 999)
	# animate list in downward fashion
	for c : Control in get_children():
		var tween : Tween = get_tree().create_tween().set_parallel(false)
		tween.tween_property(c, "modulate", Color(1, 1, 1, 1), 0.3)
		if !is_visible_in_tree():
			break
		# don't animate delays for spacers
		if c is Button || c is Panel || c is Label || c is LineEdit || c is HBoxContainer || c is PanelContainer || c is VBoxContainer:
			# more items means faster animation
			await get_tree().create_timer(0.15 * (8/count)).timeout
