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

extends CanvasLayer

@onready var intro_animator : AnimationPlayer = $IntroOverlay/AnimationPlayer
@onready var intro_overlay : Control = $IntroOverlay
@onready var intro_text : Label = $IntroOverlay/TitleText
@onready var tip_text : Label = $IntroOverlay/Tip
@onready var pause_tip_text : Label = $PauseMenu/Tip
@onready var client_request_world_timer : Timer = $RequestWorldTimer

const NUM_OF_TIPS = 15

func _ready() -> void:
	$PauseMenu/TabContainer/Pause/ChangeMap.connect("pressed", _send_on_change_map_pressed)
	$PauseMenu/TabContainer/Pause/SaveWorld.connect("pressed", _on_save_world_pressed)

func hide_pause_menu() -> void:
	Global.is_paused = false
	if Global.get_world().get_current_map() is Editor:
		$TestModePauseMenu.visible = false
		Global.get_player().locked = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		$PauseMenu.visible = false
		if Global.get_player() != null:
			Global.get_player().locked = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_pause_menu() -> void:
	Global.is_paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# if in editor world, we are testing, so show test pause menu
	if Global.get_world().get_current_map() is Editor:
		var editor : Editor = Global.get_world().get_current_map()
		$TestModePauseMenu.visible = true
		Global.get_player().locked = true
		$TestModePauseMenu/Menu/ReturnToEditor.connect("pressed", editor.exit_test_mode)
	else:
		$PauseMenu.visible = true
		if Global.get_player() != null:
			Global.get_player().locked = true
		# show tip on pause screen
		var tipnum : int = randi() % NUM_OF_TIPS
		pause_tip_text.text = JsonHandler.find_entry_in_file(str("tip/", tipnum))

func _process(delta : float) -> void:
	if Input.is_action_just_pressed("pause") && visible:
		# in editor testing mode
		if Global.get_world().get_current_map() is Editor:
			if $TestModePauseMenu.visible:
				hide_pause_menu()
			else:
				show_pause_menu()
		else:
			if $PauseMenu.visible:
				hide_pause_menu()
			else:
				show_pause_menu()
		

func _send_on_change_map_pressed() -> void:
	var map_selector : OptionButton = $PauseMenu/TabContainer/Pause/MapSelection
	var map_name : String = map_selector.get_item_text(map_selector.selected)
	# load tbw with switching flag
	# clients must wait 15s between loading worlds to avoid spam
	if multiplayer.is_server():
		Global.get_world().load_tbw(map_name.split(".")[0], true)
	else:
		if client_request_world_timer.is_stopped():
			Global.get_world().load_tbw(map_name.split(".")[0], true)
			UIHandler.show_alert(str("Your request to load \"", map_name, "\" was sent to the host."), 4)
			client_request_world_timer.start()
		else:
			UIHandler.show_alert(str("Wait ", round(client_request_world_timer.time_left), " more seconds before requesting\nto load another world!"), 5, false, UIHandler.alert_colour_error)

func play_intro_animation(text : String) -> void:
	# in case player was paused
	hide_pause_menu()
	intro_text.text = text
	intro_animator.play("intro")
	var tipnum : int = randi() % NUM_OF_TIPS
	tip_text.text = JsonHandler.find_entry_in_file(str("tip/", tipnum))

func play_outro_animation(text : String) -> void:
	# in case player was paused
	hide_pause_menu()
	intro_text.text = text
	intro_animator.play("outro")

func _on_save_world_pressed() -> void:
	var world_name : String = $PauseMenu/TabContainer/Pause/SaveWorldName.text
	if world_name == "":
		UIHandler.show_alert("Please enter a world name above!", 4, false, UIHandler.alert_colour_error)
	else:
		Global.get_world().save_tbw(str(world_name))
