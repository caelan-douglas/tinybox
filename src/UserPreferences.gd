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

# Saves a preference to the disk (located in Tinybox/preferences.txt in your operating system's app data folder.)
func save_pref(key : String, value: Variant, section := "preferences") -> void:
	var config := ConfigFile.new()
	# in case the file already exists, load it
	var err := config.load("user://preferences.txt")
	if err != OK:
		# if the file doesn't exist, create a new one
		config = ConfigFile.new()
	config.set_value(section, key, value)
	# Save it to a file (overwrite if already exists).
	config.save("user://preferences.txt")

# Loads a preference from disk (located in Tinybox/preferences.txt in your operating system's app data folder.)
func load_pref(key : String, section := "preferences") -> Variant:
	var config := ConfigFile.new()
	# Load data from a file.
	var err := config.load("user://preferences.txt")
	# If the file didn't load, ignore it.
	if err != OK:
		return
	if config.has_section_key(section, key):
		return config.get_value(section, key, null)
	else:
		return null

func delete_pref(section : String, key : String) -> void:
	var config := ConfigFile.new()
	# Load data from a file.
	var err := config.load("user://preferences.txt")
	# If the file didn't load, ignore it.
	if err != OK:
		return
	config.erase_section_key(section, key)
	config.save("user://preferences.txt")

func has_section(section : String) -> bool:
	var config := ConfigFile.new()
	# Load data from a file.
	var err := config.load("user://preferences.txt")
	# If the file didn't load, ignore it.
	if err != OK:
		return false
	return config.has_section(section)
