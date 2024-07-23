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

extends OptionButton

func _ready() -> void:
	# add built-in worlds
	add_separator("Built-in worlds")
	add_item("Frozen Field.tbw")
	add_item("Steep Swamp.tbw")
	# add user worlds to list
	add_separator("Your worlds")
	for map : String in Global.get_user_tbw_names():
		var image : Image = Global.get_world().get_tbw_image(map.split(".")[0])
		if image != null:
			image.resize(80, 64)
			var tex : ImageTexture = ImageTexture.create_from_image(image)
			add_icon_item(tex, map)
		else:
			add_item(map)
