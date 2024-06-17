# Runs all Editor functions.
extends Map
class_name Editor
signal item_picked

@onready var editor_canvas = get_tree().current_scene.get_node("EditorCanvas")

func _ready():
	super()
	await get_tree().process_frame
	
	# hide player and make them invulnerable
	var player = Global.get_player()
	player.global_position = Vector3(0, 50, 0)
	player.change_state(RigidPlayer.DUMMY)
	player.invulnerable = true
	player.visible = false
	player.get_tool_inventory().delete_all_tools()
	player.get_tool_inventory().set_disabled(true)
	
	var camera = get_viewport().get_camera_3d()
	if camera is Camera:
		camera.set_target($CameraTarget)
		camera.set_camera_mode(Camera.CameraMode.CONTROLLED)

func show_item_chooser() -> void:
	editor_canvas.get_node("ItemChooser").visible = true
	for b in editor_canvas.get_node("ItemChooser/Menu/ItemGrid").get_children():
		b.connect("pressed", _on_item_chosen.bind(b.text), 8)

func _on_item_chosen(item_name) -> void:
	emit_signal("item_picked", item_name)
	editor_canvas.get_node("ItemChooser").visible = false

var active_water = null
var water_height = 42
@onready var obj_water = preload("res://data/scene/editor_obj/WorldWater.tscn")
func toggle_water():
	if active_water != null:
		active_water.queue_free()
		active_water = null
	else:
		var water_inst = obj_water.instantiate()
		Global.get_world().add_child(water_inst)
		water_inst.global_position = Vector3(0, water_height, 0)
		active_water = water_inst

func adjust_water_height(amt):
	water_height += amt
	if active_water != null:
		active_water.global_position.y = water_height
	editor_canvas.get_node("WorldProperties/Menu/WaterHeightAdjuster/DynamicLabel").text = str("Water height: ", water_height)
