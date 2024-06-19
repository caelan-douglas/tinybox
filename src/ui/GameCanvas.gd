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

@onready var intro_animator = $IntroOverlay/AnimationPlayer
@onready var intro_overlay = $IntroOverlay
@onready var intro_text = $IntroOverlay/TitleText
@onready var tip_text = $IntroOverlay/Tip

func hide_pause_menu() -> void:
	$PauseMenu.visible = false
	Global.get_player().locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_pause_menu() -> void:
	$PauseMenu.visible = true
	Global.get_player().locked = true
	if Global.get_world().minigame != null:
		$PauseMenu/Menu/Title.json_text = "ui/minigame_mode"
		$PauseMenu/Menu/ChangeMap.disabled = true
	else:
		$PauseMenu/Menu/Title.json_text = "ui/sandbox_mode"
		$PauseMenu/Menu/ChangeMap.disabled = false
	$PauseMenu/Menu/Title.update_text()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta):
	if Input.is_action_just_pressed("pause") && visible:
		if $PauseMenu.visible:
			hide_pause_menu()
		else:
			show_pause_menu()
		

func _send_on_change_map_pressed() -> void:
	var map_selector = $PauseMenu/Menu/MapSelection
	var map_name = map_selector.get_item_text(map_selector.selected)
	_on_change_map_pressed.rpc(map_name)

@rpc("any_peer", "call_local", "reliable")
func _on_change_map_pressed(map_name) -> void:
	# load intended map
	Global.get_world().clear_world()
	Global.get_world().load_map(load(str("res://data/scene/", map_name, "/", map_name, ".tscn")))
	
	# reset some player stuff
	var camera = get_viewport().get_camera_3d()
	if camera is Camera:
		Global.get_player().set_camera(camera)
	var player = Global.get_player()
	player.change_state(RigidPlayer.IDLE)
	player.go_to_spawn()

func play_intro_animation(text) -> void:
	# in case player was paused
	hide_pause_menu()
	intro_text.text = text
	intro_animator.play("intro")
	var tipnum = randi() % 9
	tip_text.text = JsonHandler.find_entry_in_file(str("tip/", tipnum))

func play_outro_animation(text) -> void:
	# in case player was paused
	hide_pause_menu()
	intro_text.text = text
	intro_animator.play("outro")

func _ready():
	$PauseMenu/Menu/StartGame.connect("pressed", Global.get_world().send_start_lobby)
	$PauseMenu/Menu/ChangeMap.connect("pressed", _send_on_change_map_pressed)
