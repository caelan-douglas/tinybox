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

extends Control

# For running server commands.

@onready var scroll_box : ScrollContainer = $VBoxContainer/ScrollContainer
@onready var chat_list : Control = $VBoxContainer/ScrollContainer/ChatList
@onready var line_edit : Control = $VBoxContainer/LineEdit
@onready var chat_entry : PackedScene = preload("res://data/scene/ui/ChatEntry.tscn")
var tween : Tween = null
var chat_last_opened_time : int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	line_edit.connect("text_submitted", _on_chat_submitted)
	line_edit.connect("focus_entered", _on_line_edit_focus_entered)
	line_edit.connect("focus_exited", _on_line_edit_focus_exited)
	CommandHandler.connect("command_response", _on_command_response)

func _on_line_edit_focus_entered() -> void:
	chat_last_opened_time = Time.get_ticks_msec()
	if Global.get_player() != null:
		Global.get_player().locked = true
	# transparency effect for ingame
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if tween:
		tween.kill()
		tween = null
	# show old entries
	for entry in chat_list.get_children():
		entry.visible = true
	await get_tree().create_timer(0.1).timeout
	# scroll to bottom
	scroll_box.scroll_vertical = scroll_box.get_v_scroll_bar().max_value

func _on_line_edit_focus_exited() -> void:
	if Global.get_player() != null:
		Global.get_player().locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# hide old entries
	for entry in chat_list.get_children():
		if Time.get_ticks_msec() - entry.age > entry.hide_age:
			entry.visible = false
	await get_tree().create_timer(0.1).timeout
	# scroll to bottom
	scroll_box.scroll_vertical = scroll_box.get_v_scroll_bar().max_value

func _unhandled_input(event : InputEvent) -> void:
	if is_visible_in_tree():
		if (event is InputEventKey):
			if event.pressed and event.keycode == KEY_TAB:
				line_edit.grab_focus()

func _on_chat_submitted(text : String) -> void:
	CommandHandler.submit_command.rpc("", text)
	line_edit.text = ""
	# only release focus ingame
	line_edit.release_focus()
	await get_tree().create_timer(0.1).timeout
	# scroll to bottom
	scroll_box.scroll_vertical = scroll_box.get_v_scroll_bar().max_value

func _on_command_response(sender : String, text : String, timeout : int = 10) -> void:
	var entry : Control = chat_entry.instantiate()
	chat_list.add_child(entry)
	entry.age = Time.get_ticks_msec()
	entry.hide_age = timeout*1000
	entry.get_node("Margin/HBoxContainer/ChatLabel").text = str(text)
	entry.get_node("Margin/HBoxContainer/PlayerLabel").text = str(sender)
	
	get_tree().create_timer(timeout).connect("timeout", _on_entry_timeout.bind(entry))
	await get_tree().process_frame
	# scroll to bottom
	scroll_box.scroll_vertical = scroll_box.get_v_scroll_bar().max_value
	
	# show chat above player
	var player : RigidPlayer = Global.get_player_by_name(sender)
	if player != null:
		player.show_chat(text)

func _on_entry_timeout(entry : Node) -> void:
	# don't hide entries if chat is open
	if line_edit.has_focus():
		return
	entry.visible = false
