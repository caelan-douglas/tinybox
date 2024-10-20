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

@export var include_built_in : bool = true

func add_map(file_name : String) -> void:
	var image : Variant = Global.get_tbw_image(file_name)
	if image != null:
		image.resize(80, 54)
		var tex : ImageTexture = ImageTexture.create_from_image(image as Image)
		add_icon_item(tex, file_name)
	else:
		image = load("res://data/textures/tbw_placeholder.jpg")
		var tex : ImageTexture = ImageTexture.create_from_image(image as Image)
		add_icon_item(tex, file_name)

func _ready() -> void:
	refresh()

func refresh() -> void:
	clear()
	# add built-in worlds
	if include_built_in:
		add_separator("Built-in worlds")
		add_map("Frozen Field")
		add_map("Acid House")
		add_map("Castle")
		add_map("Warp Spire")
		add_map("Quarry Quarrel")
		add_map("Perilous Platforms")
		add_map("Slapdash Central")
		add_map("Steep Swamp")
		add_map("Grasslands")
	# add user worlds to list
	add_separator("Your worlds")
	for map : String in Global.get_user_tbw_names():
		add_map(map.split(".")[0])
