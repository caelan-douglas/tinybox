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

extends Button
class_name DynamicButton

@export var json_text : String = ""
@export var grab_initial_focus := false
@onready var audio := AudioStreamPlayer.new()
@onready var audio_click := AudioStreamPlayer.new()

func _ready() -> void:
	# sounds
	audio.stream = load("res://data/audio/ui_button_click.ogg")
	audio.volume_db = -6
	audio.bus = "UI"
	add_child(audio)
	audio_click.stream = load("res://data/audio/ui_button.ogg")
	audio_click.volume_db = -4
	audio_click.bus = "UI"
	add_child(audio_click)
	
	set_text_to_json(json_text)
	if is_visible_in_tree() && grab_initial_focus:
		grab_focus()
	connect("visibility_changed", _on_visibility_changed)
	
	# green save buttons
	if json_text == "ui/save":
		self_modulate = Color(1, 3.2, 1, 1)
	
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	connect("focus_entered", play_audio_hover)
	connect("pressed", play_audio_click)

func _on_visibility_changed() -> void:
	if is_visible_in_tree() && grab_initial_focus:
		# prevent playing focus sound on menu's first appearance
		disconnect("focus_entered", play_audio_hover)
		grab_focus()
		connect("focus_entered", play_audio_hover)

func _on_mouse_entered() -> void:
	# pivot center
	pivot_offset = Vector2(size.x / 2, size.y / 2)
	var tween : Tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	grab_focus()

func _on_mouse_exited() -> void:
	var tween : Tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	release_focus()

func play_audio_hover() -> void:
	await get_tree().process_frame
	if !audio_click.playing:
		audio.play()

func play_audio_click() -> void:
	audio_click.play()

func set_text_to_json(json : String) -> void:
	json_text = json
	if json_text != "":
		text = JsonHandler.find_entry_in_file(json_text)
