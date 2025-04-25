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
var alert_resource : PackedScene = preload("res://data/scene/ui/Alert.tscn")
var alert_actions_resource : PackedScene = preload("res://data/scene/ui/AlertActions.tscn")
var button : PackedScene = preload("res://data/scene/ui/Button.tscn")

var alert_colour_gold : Color = Color(4.0, 3.0, 1.0, 1)
var alert_colour_error : Color = Color("ff655a")
var alert_colour_player : Color = Color(1.0, 2.0, 14.0, 1)
var alert_colour_death : Color = Color(1.8, 0.0, 1.6, 1)

# Show an alert box.
# Arg 1: The text to show.
# Arg 2: The timeout. -1 will never timeout.
# Arg 3: Show in game canvas instead of persistent canvas. Useful
#        for alerts you only want to show in game, such as
#        when a host disconnects.
@rpc("any_peer", "call_local")
func show_alert(alert_text : String, timeout := -1, show_in_game_canvas : bool = false, alert_colour : Color = Color("#ffffff")) -> void:
	# if in dedicated server mode
	if multiplayer.is_server() && Global.server_mode():
		# show a chat instead
		CommandHandler.submit_command.rpc("ALERT FROM WORLD", alert_text, 1)
	# normal alert
	else:
		
		var alert : Alert = alert_resource.instantiate()
		alert.get_node("Content").text = alert_text
		if alert_colour.to_html() != "#ffffff":
			alert.self_modulate = alert_colour
		
		var alert_canvas : Node = get_tree().root.get_node("PersistentScene/AlertCanvas/Alerts")
		if show_in_game_canvas:
			alert_canvas = get_tree().root.get_node("Main/GameCanvas")
		
		# make sure that we haven't been disconnected
		if alert_canvas != null:
			# don't show dupes
			for existing : Node in alert_canvas.get_children():
				if existing is Alert:
					var content := existing.get_node_or_null("Content")
					if content != null:
						if content is Label:
							if content.text == alert_text:
								# show duplicate count
								var dupe_count := existing.get_node_or_null("Duplicate")
								if dupe_count != null:
									existing.dupes += 1
									dupe_count.text = str("(", existing.dupes, ")")
								alert.queue_free()
								return
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
func show_alert_with_actions(alert_text : String, action_texts : Array, error := false) -> Array:
	var alert : Alert = alert_actions_resource.instantiate()
	alert.get_node("Content/Label").text = alert_text
	
	var alert_canvas : Node = get_tree().root.get_node("PersistentScene/AlertCanvas/Alerts")
	for c in alert_canvas.get_children():
		c.queue_free()
	
	if error:
		alert.self_modulate = alert_colour_error
	
	alert_canvas.add_child(alert)
	var buttons_to_return := []
	
	for i in range (action_texts.size()):
		var b : Button = button.instantiate()
		b.text = action_texts[i]
		alert.get_node("Content/HBoxContainer").add_child(b)
		buttons_to_return.append(b)
		# close the alert once a button's pressed
		b.connect("pressed", alert.timeout)
		b.grab_focus()
	
	return buttons_to_return

# Show a small non-actionable alert.
@rpc("any_peer", "call_local")
func show_toast(alert_text : String, timeout := 3, alert_colour : Color = Color("#ffffff"), font_size : int = 16) -> void:
	# if in dedicated server mode
	if multiplayer.is_server() && Global.server_mode():
		# show a chat instead
		CommandHandler.submit_command.rpc("TOAST FROM WORLD", alert_text, 1)
	# normal toast
	else:
		var toast : Label = Label.new()
		toast.text = alert_text
		if alert_colour.to_html() != "#ffffff":
			toast.self_modulate = alert_colour
		toast.set("theme_override_constants/outline_size", 6 * (font_size / 16))
		toast.set("theme_override_colors/font_outline_color", Color("#00000062"))
		toast.set("theme_override_font_sizes/font_size", font_size)
		toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var alert_canvas : Node = get_tree().root.get_node("PersistentScene/AlertCanvas/Toasts")
		# make sure that we haven't been disconnected
		if alert_canvas != null:
			alert_canvas.add_child(toast)
		await get_tree().create_timer(timeout).timeout
		# make sure alert hasnt already been destroyed
		if toast != null:
			toast.queue_free()

func fade_black_transition(duration : float = 0.5) -> void:
	var fade : ColorRect = get_tree().root.get_node("PersistentScene/PersistentCanvas/Fade")
	fade.visible = true
	var tween : Tween = get_tree().create_tween().set_parallel(false)
	# hold black for a short while
	tween.tween_property(fade, "modulate", Color(1, 1, 1, 1), duration/2)
	tween.tween_property(fade, "modulate", Color(1, 1, 1, 0), duration/2)
	await get_tree().create_timer(duration).timeout
	fade.visible = false

@rpc("any_peer", "call_local")
func play_preview_animation_overlay(title : String, subtitle : String = "") -> void:
	# play preview animation
	var anim : AnimationPlayer = PersistentScene.get_node("PersistentCanvas/Preview/AnimationPlayer")
	var label : Label = PersistentScene.get_node("PersistentCanvas/Preview/Title")
	var subtitle_label : Label = PersistentScene.get_node("PersistentCanvas/Preview/SubtitleAnchor/Subtitle")
	label.text = title
	subtitle_label.text = subtitle
	anim.play("preview")

@rpc("any_peer", "call_local", "reliable")
func show_win_label(text : String) -> void:
	var win_label : Label = get_tree().current_scene.get_node("GameCanvas/WinLabel")
	win_label.text = text
	win_label.visible = true

@rpc("any_peer", "call_local", "reliable")
func hide_win_label() -> void:
	var win_label : Label = get_tree().current_scene.get_node("GameCanvas/WinLabel")
	win_label.visible = false
