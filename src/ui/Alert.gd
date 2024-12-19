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
class_name Alert

var dupes : int = 1

func timeout() -> void:
	var anim : AnimationPlayer = $AnimationPlayer
	anim.play("hide")
	# for alert boxes, disable their buttons so that they cannot be clicked
	# multiple times once already pressed
	if has_node("Content/HBoxContainer"):
		for b : Button in $Content/HBoxContainer.get_children():
			b.disabled = true
	await Signal(anim, "animation_finished")
	queue_free()
