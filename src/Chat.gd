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

# TODO: Implement this in a better way, commands 
# should be something that Global or World runs, not Chat.

@onready var chat_list = $VBoxContainer/ChatList
@onready var line_edit = $VBoxContainer/LineEdit

@onready var chat_entry = preload("res://data/scene/ui/ChatEntry.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	line_edit.connect("text_submitted", _on_chat_submitted)
	line_edit.connect("focus_entered", _on_line_edit_focus_entered)
	line_edit.connect("focus_exited", _on_line_edit_focus_exited)

func _on_line_edit_focus_entered() -> void:
	Global.get_player().locked = true

func _on_line_edit_focus_exited() -> void:
	Global.get_player().locked = false

func _unhandled_input(event) -> void:
	if (event is InputEventKey):
		if event.pressed and event.keycode == KEY_QUOTELEFT:
			line_edit.grab_focus()

func _on_chat_submitted(text : String) -> void:
	submit_chat.rpc(text, Global.display_name)
	line_edit.text = ""
	line_edit.release_focus()

# Creates a chat entry.
# Arg 1: The ID who sent this command.
# Arg 2: The text to display.
# Arg 3: The time before the message disappears.
func create_chat_entry(sender : String, text : String, timeout : float = 10) -> void:
	var ce_i = chat_entry.instantiate()
	chat_list.add_child(ce_i)
	ce_i.get_node("HBoxContainer/ChatLabel").text = str(text)
	ce_i.get_node("HBoxContainer/PlayerLabel").text = str(sender)
	get_tree().create_timer(timeout).connect("timeout", ce_i.queue_free)

# Send the chat to all clients.
@rpc("any_peer", "call_local")
func submit_chat(text : String, display_name : String) -> void:
	var split_text = text.split(" ")
	if text == "?":
		create_chat_entry("Server says: ", "Command list:")
		create_chat_entry("$speed", "ex. $speed 12 - sets player speed to 12. Default is 5.")
		return
	# Move All command
	if split_text[0] == "$speed":
		if split_text.size() == 2:
			# Move to X spawn
			var x = int(split_text[1])
			# Get this player and give them the speed.
			var player = Global.get_player()
			if player != null:
				player.move_speed = x
			return
		else:
			create_chat_entry("Server says: ", str(display_name, ": Invalid use of $speed. Correct syntax example: $moveall 7"))
			return
	# no command, just send the chat
	create_chat_entry(display_name, text)
