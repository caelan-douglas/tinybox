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
const NUM_OF_TIPS = 12

func hide_pause_menu() -> void:
	if Global.get_world().get_current_map() is Editor:
		$TestModePauseMenu.visible = false
		Global.get_player().locked = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		$PauseMenu.visible = false
		Global.get_player().locked = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_pause_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# if in editor world, we are testing, so show test pause menu
	if Global.get_world().get_current_map() is Editor:
		var editor : Editor = Global.get_world().get_current_map()
		$TestModePauseMenu.visible = true
		Global.get_player().locked = true
		$TestModePauseMenu/Menu/ReturnToEditor.connect("pressed", editor.exit_test_mode)
	else:
		$PauseMenu.visible = true
		Global.get_player().locked = true
		if Global.get_world().minigame != null:
			$PauseMenu/Menu/Title.json_text = "ui/minigame_mode"
			$PauseMenu/Menu/ChangeMap.disabled = true
		else:
			$PauseMenu/Menu/Title.json_text = "ui/sandbox_mode"
			$PauseMenu/Menu/ChangeMap.disabled = false
		$PauseMenu/Menu/Title.update_text()
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
	var map_selector : OptionButton = $PauseMenu/Menu/MapSelection
	var map_name : String = map_selector.get_item_text(map_selector.selected)
	Global.get_world().load_tbw(map_name.split(".")[0])

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

func _ready() -> void:
	$PauseMenu/Menu/StartGame.connect("pressed", Global.get_world().send_start_lobby)
	$PauseMenu/Menu/ChangeMap.connect("pressed", _send_on_change_map_pressed)
	$PauseMenu/Menu/SaveWorld.connect("pressed", _on_save_world_pressed)

func _on_save_world_pressed() -> void:
	var world_name : String = $PauseMenu/Menu/SaveWorldName.text
	if world_name == "":
		UIHandler.show_alert("Please enter a world name above!", 4, false, true, false)
	else:
		Global.get_world().save_tbw(str(world_name))
