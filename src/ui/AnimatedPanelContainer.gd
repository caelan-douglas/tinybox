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

extends PanelContainer
class_name AnimatedPanelContainer

func _ready() -> void:
	connect("visibility_changed", _on_visibility_changed)
	animate_panel()

func _on_visibility_changed() -> void:
	if visible == true:
		animate_panel()

func animate_panel() -> void:
	pivot_offset = size/2
	scale = Vector2(0.8, 0.8)
	modulate = Color(1, 1, 1, 0)
	var tween : Tween = get_tree().create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.4)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
