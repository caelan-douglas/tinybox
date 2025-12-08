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

# Runs all Editor functions.
extends Map
class_name Editor

@onready var editor_canvas : EditorCanvas = get_tree().current_scene.get_node("EditorCanvas")
@onready var editor_tool_inventory : ToolInventory = get_node("EditorToolInventory")
@onready var property_editor : PropertyEditor = get_tree().current_scene.get_node("EditorCanvas/LeftPanel/PropertyEditor")

var selected_item_properties : Dictionary = {}
var test_mode : bool = false

func toggle_player_visual() -> void:
	$CameraTarget/PlayerVisual.visible = !$CameraTarget/PlayerVisual.visible

func _ready() -> void:
	super()
	
	await disable_player()
	
	# for when a new .tbw map is loaded
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera is Camera:
		camera.set_target($CameraTarget)
		camera.set_camera_mode(Camera.CameraMode.CONTROLLED)
	
	editor_canvas.toggle_player_visual_button.connect("pressed", toggle_player_visual)
	
	# load default world
	Global.get_world().load_tbw("editor_default", false, false)

func _on_tbw_loaded() -> void:
	# Check if map has water
	for obj in Global.get_world().get_children():
		if obj is Water:
			active_water = obj
			# update height display
			water_height = active_water.global_position.y
			editor_canvas.water_height_adj.set_value(water_height)
	# Set map height adjusters
	editor_canvas.death_lim_low_adj.set_value(death_limit_low)
	editor_canvas.death_lim_hi_adj.set_value(death_limit_high)
	# Set map respawn adjuster
	editor_canvas.respawn_time_adj.set_value(respawn_time)
	# Set gravity adjuster
	editor_canvas.grav_slider.set_value(gravity_scale)
	# Update environment text
	var env : Node = get_environment()
	if env != null:
		editor_canvas.env_button.text = JsonHandler.find_entry_in_file(str("tbw_objects/", env.environment_name))
	# Update background text
	var bg : TBWObject = get_background()
	if bg != null:
		editor_canvas.bg_button.text = JsonHandler.find_entry_in_file(str("tbw_objects/", bg.tbw_object_type))
	# Update song list
	var song_list : VBoxContainer = editor_canvas.get_node("PauseMenu/ScrollContainer/Sections/World Properties/SongList/List")
	for old_entry : Node in song_list.get_children():
		old_entry.queue_free()
	for song : String in MusicHandler.ALL_SONGS_LIST:
		var check := CheckBox.new()
		# display name
		check.text = str(JsonHandler.find_entry_in_file(str("songs/", song)))
		# internal name, ex. mus1 mus2
		check.name = song
		# if loaded map has the song, check it
		if songs.has(song):
			check.button_pressed = true
		song_list.add_child(check)
		check.connect("toggled", set_song.bind(song))
	MusicHandler.switch_song(songs)

func get_object_properties_visible() -> bool:
	return editor_canvas.get_node("PropertyEditor").visible

var active_water : Water = null
var water_height : float = 42
# in case water is turned off and on again, save the type
var water_type : int = 0
@onready var obj_water : PackedScene = preload("res://data/scene/editor_obj/WorldWater.tscn")
func toggle_water() -> void:
	if active_water != null:
		active_water.queue_free()
		active_water = null
	else:
		var water_inst : Water = obj_water.instantiate()
		Global.get_world().add_child(water_inst, true)
		water_inst.global_position = Vector3(0, water_height, 0)
		active_water = water_inst
		active_water.set_water_type(water_type)

func switch_water_type(update_text_path : String) -> void:
	if active_water != null:
		water_type = active_water.water_type
		water_type += 1
		if water_type >= Water.WaterType.size():
			water_type = 0
		active_water.set_water_type(water_type)
		if "text" in get_node_or_null(update_text_path):
			get_node(update_text_path).text = active_water.water_types_as_strings[water_type]

func adjust_water_height(amt : float) -> void:
	water_height = amt
	if active_water != null:
		active_water.global_position.y = water_height

func adjust_death_limit_low(new_val : int) -> void:
	death_limit_low = new_val

func adjust_death_limit_high(new_val : int) -> void:
	death_limit_high = new_val

func adjust_respawn_time(new_val : int) -> void:
	respawn_time = new_val

func delete_environment() -> void:
	for obj in Global.get_world().get_children():
		if obj is TBWEnvironment:
			obj.queue_free()

func get_environment() -> TBWEnvironment:
	for obj in Global.get_world().get_children():
		if obj is TBWEnvironment:
			return obj
	return null

func delete_background() -> void:
	for obj in Global.get_world().get_children():
		if obj is TBWObject:
			if obj.tbw_object_type.begins_with("bg_"):
				obj.queue_free()

func get_background() -> TBWObject:
	for obj in Global.get_world().get_children():
		if obj is TBWObject:
			if obj.tbw_object_type.begins_with("bg_"):
				return obj
	return null

func switch_environment() -> void:
	var env : Node = null
	for obj in Global.get_world().get_children():
		if obj is TBWEnvironment:
			env = obj
	var current_env_name := ""
	if env != null:
		current_env_name = env.environment_name
	# delete old environment
	delete_environment()
	
	# get list of envs
	var env_list : Array[String] = []
	for obj : String in SpawnableObjects.objects.keys():
		if obj.begins_with("env_"):
			env_list.append(obj)
	var current_idx : int = env_list.find(current_env_name)
	current_idx += 1
	if current_idx >= env_list.size():
		current_idx = 0
	var new_env : Node = SpawnableObjects.objects[env_list[current_idx]].instantiate()
	
	Global.get_world().add_child(new_env, true)
	current_env_name = new_env.environment_name
	editor_canvas.get_node("PauseMenu/ScrollContainer/Sections/World Properties/Environment").text = JsonHandler.find_entry_in_file(str("tbw_objects/", current_env_name))

func switch_background() -> void:
	var bg : TBWObject = null
	for obj in Global.get_world().get_children():
		if obj is TBWObject:
			if obj.tbw_object_type.begins_with("bg_"):
				bg = obj
	var current_bg_name := ""
	if bg != null:
		current_bg_name = bg.tbw_object_type
	# delete old
	delete_background()
	
	# get list of envs
	var bg_list : Array[String] = []
	for obj : String in SpawnableObjects.objects.keys():
		if obj.begins_with("bg_"):
			bg_list.append(obj)
	var current_idx : int = bg_list.find(current_bg_name)
	current_idx += 1
	if current_idx >= bg_list.size():
		# for "none" background
		current_idx = -1
	var new_bg : Node = null
	if current_idx > -1:
		new_bg = SpawnableObjects.objects[bg_list[current_idx]].instantiate()
	
	if new_bg != null:
		Global.get_world().add_child(new_bg, true)
		current_bg_name = new_bg.tbw_object_type
		editor_canvas.get_node("PauseMenu/ScrollContainer/Sections/World Properties/Background").text = JsonHandler.find_entry_in_file(str("tbw_objects/", current_bg_name))
	else:
		current_bg_name = "(none)"
		editor_canvas.get_node("PauseMenu/ScrollContainer/Sections/World Properties/Background").text = "(none)"

# Hide player and make them invulnerable.
func disable_player() -> int:
	var player : RigidPlayer = Global.get_player()
	while player == null:
		await get_tree().process_frame
		player = Global.get_player()
	player.despawn()
	await get_tree().process_frame
	return 0

const PLAYER : PackedScene = preload("res://data/scene/character/RigidPlayer.tscn")
# show player and game tools.
func enable_player(at_spot : Variant = null) -> int:
	var player : RigidPlayer = PLAYER.instantiate()
	player.name = str(1)
	Global.get_world().add_child(player, true)
	# grace period for invincibility
	await player.teleported
	await get_tree().physics_frame
	if at_spot != null:
		if at_spot is Vector3:
			player.teleport(at_spot as Vector3)
	await get_tree().process_frame
	return 0

var test_mode_world_name : String = ""
func enter_test_mode(world_name : String, at_spot : bool = false) -> void:
	test_mode = true
	var player_spot : Variant = null
	if at_spot:
		var camera : Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			if camera is Camera:
				player_spot = camera.controlled_cam_pos
	
	# save in case player makes any changes / destroys things in testing
	var ok : Variant = await Global.get_world().save_tbw(str(world_name))
	if ok == false:
		return
	test_mode_world_name = world_name
	
	# load world so that brick groups and joints are generated
	Global.get_world().load_tbw(str(test_mode_world_name), false, false)
	while Global.get_world().tbw_loading:
		await get_tree().process_frame
	
	await enable_player(player_spot)
	editor_canvas.visible = false
	var game_canvas : CanvasLayer = get_tree().current_scene.get_node("GameCanvas")
	game_canvas.visible = true
	game_canvas.hide_pause_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	UIHandler.show_alert("Changes you make in testing mode will not be saved.\nPause to return to the editor.", 10)
	
	editor_tool_inventory.set_disabled(true)

func exit_test_mode() -> void:
	test_mode = false
	# delete all bombs, rockets, etc in the world
	for obj in Global.get_world().get_children():
		if obj is Bomb || obj is Rocket || obj is ClayBall:
			obj.queue_free()
	# don't reset player and cameras
	Global.get_world().load_tbw(str(test_mode_world_name), false, false)
	
	await disable_player()
	await get_tree().process_frame
	editor_canvas.visible = true
	var game_canvas : CanvasLayer = get_tree().current_scene.get_node("GameCanvas")
	game_canvas.visible = false
	var camera : Camera3D = get_viewport().get_camera_3d()
	# in case player died and exited while respawning
	camera.locked = false
	if camera is Camera:
		camera.set_target($CameraTarget)
		camera.set_camera_mode(Camera.CameraMode.CONTROLLED)
		# reset fov in case we died
		camera.fov = UserPreferences.camera_fov
	editor_canvas.hide_pause_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	editor_tool_inventory.set_disabled(false)
	editor_tool_inventory.get_tools()[0].set_tool_active(true)

var brick_selected : Brick = null
func _process(delta : float) -> void:
	# don't release / unrelease mouse when editing text
	if Input.is_action_just_pressed("pause") && !Global.is_text_focused:
		# if pause menu is shown hide that first
		if editor_canvas.pause_menu.visible:
			editor_canvas.hide_pause_menu()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			var focused : Control = get_viewport().gui_get_focus_owner()
			# release focus of any property editor buttons
			if focused != null:
				focused.release_focus()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var camera := get_viewport().get_camera_3d()
	if camera is Camera:
		editor_canvas.coordinates_tooltip.text =\
			str("x", camera.controlled_cam_pos.x, " y", camera.controlled_cam_pos.y, " z", camera.controlled_cam_pos.z)
