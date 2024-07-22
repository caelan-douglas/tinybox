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
signal item_picked
signal deselected

@onready var editor_canvas : CanvasLayer = get_tree().current_scene.get_node("EditorCanvas")
@onready var editor_tool_inventory : EditorToolInventory = get_node("EditorToolInventory")
@onready var selector : Node = get_node("SelectArea/Selector")
@onready var select_area : Area3D = get_node("SelectArea")
@onready var property_editor : PropertyEditor = get_tree().current_scene.get_node("EditorCanvas/PropertyEditor") 

var hovered_editable_object : Node = null
var can_select_object : bool = true
var selected_item_properties : Dictionary = {}

func _ready() -> void:
	super()
	
	await disable_player()
	
	# for when a new .tbw map is loaded
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	# for when an editable object is hovered
	select_area.connect("body_entered", _on_body_selected)
	select_area.connect("area_entered", _on_body_selected)
	# for when selection leaves body
	select_area.connect("body_exited", _on_body_deselected)
	select_area.connect("area_exited", _on_body_deselected)
	property_editor.connect("property_updated", _on_property_updated)
	
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera is Camera:
		camera.set_target($CameraTarget)
		camera.set_camera_mode(Camera.CameraMode.CONTROLLED)
	
	# load default world
	Global.get_world().load_tbw("editor_default", false, false)

func _on_property_updated(properties : Dictionary) -> void:
	if property_editor.properties_from_tool == self:
		if hovered_editable_object != null:
			if hovered_editable_object is TBWObject || hovered_editable_object is Brick:
				for property : String in selected_item_properties.keys():
					hovered_editable_object.set_property(property, selected_item_properties[property])

func _on_body_selected(body : Node3D) -> void:
	var selectable_body : Node3D = null
	if body is Area3D:
		if body.owner is TBWObject:
			if !(body.owner is Water):
				selectable_body = body.owner
	else:
		if body is Brick || body is TBWObject:
			selectable_body = body
	
	if can_select_object:
		if selectable_body != null:
			hovered_editable_object = selectable_body
			# show props for that object
			selected_item_properties = property_editor.list_object_properties(selectable_body, self)

func _on_body_deselected(body : Node3D) -> void:
	# check currently hovering bodies
	if !select_area.has_overlapping_bodies() && !select_area.has_overlapping_areas():
		# clear list
		property_editor.clear_list()
		# allow any tools to re show their list
		emit_signal("deselected")

func _on_tbw_loaded() -> void:
	# Check if map has water
	for obj in Global.get_world().get_children():
		if obj is Water:
			active_water = obj
			# update height display
			water_height = active_water.global_position.y
			adjust_water_height(0)
	# Update environment text
	var env : Node = get_environment()
	if env != null:
		editor_canvas.get_node("WorldProperties/Menu/Environment").text = env.environment_name
	# Update background text
	var bg : TBWObject = get_background()
	if bg != null:
		editor_canvas.get_node("WorldProperties/Menu/Background").text = bg.tbw_object_type

func show_item_chooser() -> void:
	editor_tool_inventory.set_disabled(true)
	editor_canvas.get_node("ItemChooser").visible = true
	for b in editor_canvas.get_node("ItemChooser/Menu/ScrollContainer/ItemGrid").get_children():
		b.connect("pressed", _on_item_chosen.bind(b.internal_name, b.text), 8)

func hide_item_chooser() -> void:
	editor_tool_inventory.set_disabled(false)
	editor_canvas.get_node("ItemChooser").visible = false
	for b in editor_canvas.get_node("ItemChooser/Menu/ScrollContainer/ItemGrid").get_children():
		b.disconnect("pressed", _on_item_chosen.bind(b.internal_name, b.text))

func get_item_chooser_visible() -> bool:
	return editor_canvas.get_node("ItemChooser").visible

func _on_item_chosen(item_name_internal : String, item_name_display : String) -> void:
	emit_signal("item_picked", item_name_internal, item_name_display)
	hide_item_chooser()

func get_object_properties_visible() -> bool:
	return editor_canvas.get_node("PropertyEditor").visible

var active_water : Node3D = null
var water_height : float = 42
@onready var obj_water : PackedScene = preload("res://data/scene/editor_obj/WorldWater.tscn")
func toggle_water() -> void:
	if active_water != null:
		active_water.queue_free()
		active_water = null
	else:
		var water_inst : Node3D = obj_water.instantiate()
		Global.get_world().add_child(water_inst, true)
		water_inst.global_position = Vector3(0, water_height, 0)
		active_water = water_inst

func adjust_water_height(amt : float) -> void:
	water_height += amt
	if active_water != null:
		active_water.global_position.y = water_height
	editor_canvas.get_node("WorldProperties/Menu/WaterHeightAdjuster/DynamicLabel").text = str("Water height: ", water_height)

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
	
	var new_env : Node = null
	match (current_env_name):
		# switch from > to
		"env_sunny":
			new_env = SpawnableObjects.objects["env_sunset"].instantiate()
		"env_sunset":
			new_env = SpawnableObjects.objects["env_night"].instantiate()
		"env_night":
			new_env = SpawnableObjects.objects["env_molten"].instantiate()
		"env_molten":
			new_env = SpawnableObjects.objects["env_warp"].instantiate()
		# default load sunny
		_:
			new_env = SpawnableObjects.objects["env_sunny"].instantiate()
	Global.get_world().add_child(new_env, true)
	current_env_name = new_env.environment_name
	editor_canvas.get_node("WorldProperties/Menu/Environment").text = current_env_name

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
	
	var new_bg : TBWObject = null
	match (current_bg_name):
		# switch from frozen field -> warp
		"bg_frozen_field":
			# we deleted the environment so just end here
			new_bg = SpawnableObjects.objects["bg_warp"].instantiate()
			pass
		# switch from warp -> none
		"bg_warp":
			new_bg = null
			pass
		# switch from none
		_:
			new_bg = SpawnableObjects.objects["bg_frozen_field"].instantiate()
			pass
	if new_bg != null:
		Global.get_world().add_child(new_bg, true)
		current_bg_name = new_bg.tbw_object_type
	else:
		current_bg_name = "(none)"
	editor_canvas.get_node("WorldProperties/Menu/Background").text = current_bg_name

func disable_player() -> int:
	# hide player and make them invulnerable
	var player : RigidPlayer = Global.get_player()
	while player == null:
		await get_tree().process_frame
		player = Global.get_player()
	player.teleport(Vector3(0, -1000, 0))
	player.change_state(RigidPlayer.DUMMY)
	player.locked = true
	player.editor_mode = true
	player.visible = false
	player.get_tool_inventory().delete_all_tools()
	player.get_tool_inventory().set_disabled(true)
	return 0

func enable_player() -> int:
	# show player and game tools
	var player : RigidPlayer = Global.get_player()
	while player == null:
		await get_tree().process_frame
		player = Global.get_player()
	player.go_to_spawn()
	# grace period for invincibility
	await get_tree().create_timer(0.15).timeout
	player.change_state(RigidPlayer.IDLE)
	player.locked = false
	player.editor_mode = false
	player.visible = true
	player.get_tool_inventory().give_all_tools()
	player.get_tool_inventory().set_disabled(false)
	return 0

var test_mode_world_name : String = ""
func enter_test_mode(world_name : String) -> void:
	# save in case player makes any changes / destroys things in testing
	var ok : Variant = await Global.get_world().save_tbw(str(world_name))
	if ok == false:
		return
	test_mode_world_name = world_name
	
	# load world so that brick groups and joints are generated
	Global.get_world().load_tbw(str(test_mode_world_name), false, false)
	while Global.get_world().tbw_loading:
		await get_tree().process_frame
	
	await enable_player()
	editor_canvas.visible = false
	var game_canvas : CanvasLayer = get_tree().current_scene.get_node("GameCanvas")
	game_canvas.visible = true
	var camera : Camera3D = get_viewport().get_camera_3d()
	var player : RigidPlayer = Global.get_player()
	if camera is Camera:
		camera.set_camera_mode(Camera.CameraMode.FREE)
		camera.set_target(player.target)
	game_canvas.hide_pause_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	UIHandler.show_alert("Changes you make in testing mode will not be saved.\nPause to return to the editor.", 10)

func exit_test_mode() -> void:
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
	editor_canvas.hide_pause_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func select_brick() -> Brick:
	# Don't show props of bricks that we hover
	can_select_object = false
	# Reset selected brick
	brick_selected = null
	editor_tool_inventory.set_disabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Keep track of where player was
	var camera : Camera = get_viewport().get_camera_3d()
	var last_pos : Vector3 = camera.controlled_cam_pos
	# Wait for brick to be selected
	while (brick_selected == null):
		await get_tree().process_frame
	# Brick has been selected
	editor_tool_inventory.set_disabled(false, 0.1)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.controlled_cam_pos = last_pos
	# allow objects to be selectable again
	can_select_object = true
	
	return brick_selected

var brick_selected : Brick = null
func _process(delta : float) -> void:
	# don't release / unrelease mouse when editing text
	if Input.is_action_just_pressed("editor_release_mouse") && !Global.is_text_focused:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("click"):
		for body in select_area.get_overlapping_bodies():
			if body is Brick:
				brick_selected = body as Brick

func _physics_process(delta : float) -> void:
	if select_area != null:
		select_area.global_position = get_viewport().get_camera_3d().controlled_cam_pos
