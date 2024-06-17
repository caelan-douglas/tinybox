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

# Alert box
var alert_resource = preload("res://data/scene/ui/Alert.tscn")
var alert_actions_resource = preload("res://data/scene/ui/AlertActions.tscn")
var button = preload("res://data/scene/ui/Button.tscn")

var lobby_menu = preload("res://data/scene/ui/LobbyMenu.tscn")

# Show an alert box.
# Arg 1: The text to show.
# Arg 2: The timeout. -1 will never timeout.
# Arg 3: Show in game canvas instead of persistent canvas. Useful
#        for alerts you only want to show in game, such as
#        when a host disconnects.
@rpc("any_peer", "call_local")
func show_alert(alert_text : String, timeout = -1, show_in_game_canvas : bool = false, error : bool = false, gold : bool = false) -> void:
	var alert = alert_resource.instantiate()
	alert.get_node("Content/Label").text = alert_text
	if error:
		alert.self_modulate = Color(4.0, 0.2, 0.3, 1)
	if gold:
		alert.self_modulate = Color(4.0, 3.0, 1.0, 1)
	
	var alert_canvas = get_tree().root.get_node("PersistentScene/AlertCanvas/Alerts")
	if show_in_game_canvas:
		alert_canvas = get_tree().root.get_node("Main/GameCanvas")
	
	# make sure that we haven't been disconnected
	if alert_canvas != null:
		alert_canvas.add_child(alert)
	
	if timeout > 0:
		await get_tree().create_timer(timeout).timeout
		# make sure alert hasnt already been destroyed
		if alert != null:
			alert.timeout()

# Show an alert with actions
# Arg 1: The text to show.
# Arg 2: Button texts. Will return array of buttons.
# Arg 3: Makes window red.
# Can't be called RPC.
func show_alert_with_actions(alert_text : String, action_texts : Array, error = false) -> Array:
	var alert = alert_actions_resource.instantiate()
	alert.get_node("Content/Label").text = alert_text
	
	var alert_canvas = get_tree().root.get_node("PersistentScene/AlertCanvas/Alerts")
	for c in alert_canvas.get_children():
		c.queue_free()
	
	if error:
		alert.self_modulate = Color(4.0, 0.2, 0.3, 1)
	
	alert_canvas.add_child(alert)
	var buttons_to_return = []
	
	for i in range (action_texts.size()):
		var b = button.instantiate()
		b.text = action_texts[i]
		alert.get_node("Content/HBoxContainer").add_child(b)
		buttons_to_return.append(b)
		# close the alert once a button's pressed
		b.connect("pressed", alert.timeout)
	
	return buttons_to_return

func show_lobby_menu() -> void:
	var main = get_tree().current_scene
	var lobby_menu_i = lobby_menu.instantiate()
	main.get_node("GameCanvas").visible = false
	main.add_child(lobby_menu_i)

func hide_lobby_menu() -> void:
	var main = get_tree().current_scene
	var lobby_menu = main.get_node_or_null("LobbyMenu")
	if lobby_menu != null:
		lobby_menu.queue_free()
	main.get_node("GameCanvas").visible = true
