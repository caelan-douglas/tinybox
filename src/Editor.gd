# Runs all Editor functions.
extends Map
class_name Editor
signal item_picked

@onready var editor_canvas : CanvasLayer = get_tree().current_scene.get_node("EditorCanvas")
@onready var editor_tool_inventory : EditorToolInventory = get_node("EditorToolInventory")

func _ready() -> void:
	super()
	
	# hide player and make them invulnerable
	var player : RigidPlayer = Global.get_player()
	while player == null:
		await get_tree().process_frame
		player = Global.get_player()
	player.global_position = Vector3(0, -1000, 0)
	player.change_state(RigidPlayer.DUMMY)
	player.locked = true
	player.editor_mode = true
	player.visible = false
	player.get_tool_inventory().delete_all_tools()
	player.get_tool_inventory().set_disabled(true)
	
	# for when a new .tbw map is loaded
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera is Camera:
		camera.set_target($CameraTarget)
		camera.set_camera_mode(Camera.CameraMode.CONTROLLED)
	
	# load default world
	Global.get_world().load_tbw("editor_default", true)

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
