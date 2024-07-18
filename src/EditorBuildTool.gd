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

extends EditorTool

var selected_item : PackedScene = null
var selected_item_name_internal : String = ""
var selected_item_properties : Dictionary = {}
var item_offset := Vector3(0, 0, 0)

@onready var editor_canvas : CanvasLayer = get_tree().current_scene.get_node("EditorCanvas")
@onready var editor_props_list : VBoxContainer = get_tree().current_scene.get_node("EditorCanvas/ObjectProperties/Menu") 
@onready var preview_node : Node3D = $PreviewNode
@onready var preview_delete_area : Area3D = $PreviewNode/DeleteArea
@onready var preview_cube : MeshInstance3D = $PreviewNode/Cube

func _ready() -> void:
	init("(empty)")

func set_tool_active(mode : bool, from_click : bool = false) -> void:
	super(mode, from_click)
	if mode == false:
		if preview_node != null:
			preview_node.visible = false
	else:
		if preview_node != null:
			preview_node.visible = true
		if selected_item == null:
			pick_item()
		# update object property list
		if selected_item_properties.keys().size() > 0:
			relist_object_properties()

func pick_item() -> void:
	var editor : Map = Global.get_world().get_current_map()
	if editor is Editor:
		if !editor.get_item_chooser_visible() && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			get_parent().set_disabled(true)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			editor.show_item_chooser()
			editor.connect("item_picked", _on_item_picked, 8)
			await Signal(editor, "item_picked")
			editor.disconnect("item_picked", _on_item_picked)
			get_parent().set_disabled(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			get_parent().set_disabled(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			editor.hide_item_chooser()
	else:
		get_parent().set_disabled(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func list_object_properties(instance : Node) -> void:
	# clear properties for new item
	selected_item_properties = {}
	
	for child : Node in editor_props_list.get_children():
		child.queue_free()
	var title : Label = Label.new()
	title.text = str("- Object properties -\n\n")
	editor_props_list.add_child(title)
	if instance is Brick || instance is TBWObject:
		for prop_name : String in instance.properties_to_save:
			# don't list pos rot or scale
			if prop_name != "global_position" && prop_name != "global_rotation" && prop_name != "scale":
				var prop : Variant = instance.get(prop_name)
				add_object_property_entry(prop_name, prop)

func relist_object_properties() -> void:
	# delete current list
	for child : Node in editor_props_list.get_children():
		child.queue_free()
	# reload list
	for property : String in selected_item_properties.keys():
		add_object_property_entry(property, selected_item_properties[property])

var colour_picker : PackedScene = preload("res://data/scene/ui/ColourPicker.tscn")
var adjuster : PackedScene = preload("res://data/scene/ui/Adjuster.tscn")
func add_object_property_entry(prop_name : String, prop : Variant) -> void:
	selected_item_properties[prop_name] = prop
	var entry : Control = null
	# Add colour picker
	if prop is Color:
		entry = colour_picker.instantiate()
		entry.get_node("ColorPickerButton").color = prop
		entry.get_node("ColorPickerButton").connect("color_changed", update_object_property.bind(prop_name))
	# Add adjuster for floats and ints
	if prop is float || prop is int:
		entry = adjuster.instantiate()
		var label : Label = entry.get_node("DynamicLabel")
		label.text = str(prop_name, ": ", prop)
		entry.get_node("DownBig").connect("pressed", update_object_property.bind(-10, prop_name, true, label))
		entry.get_node("Down").connect("pressed", update_object_property.bind(-1, prop_name, true, label))
		entry.get_node("Up").connect("pressed", update_object_property.bind(1, prop_name, true, label))
		entry.get_node("UpBig").connect("pressed", update_object_property.bind(10, prop_name, true, label))
	if entry != null:
		editor_props_list.add_child(entry)

func update_object_property(new_value : Variant, prop_name : String, increment : bool = false, update_label : Label = null) -> void:
	if selected_item_properties.has(prop_name):
		if increment:
			selected_item_properties[prop_name] += new_value
		else:
			selected_item_properties[prop_name] = new_value
		if update_label:
			update_label.text = str(prop_name, ": ", selected_item_properties[prop_name])

func _on_item_picked(item_name_internal : String, item_name_display : String) -> void:
	ui_tool_name = item_name_display
	ui_partner.text = str(item_name_display)
	item_offset = Vector3.ZERO
	if !SpawnableObjects.objects.has(item_name_internal):
		return
	selected_item = SpawnableObjects.objects[item_name_internal]
	selected_item_name_internal = item_name_internal
	# show editable properties
	var instance : Node3D = selected_item.instantiate()
	list_object_properties(instance)
	# offset objects down a bit, also update preview
	if item_name_internal.begins_with("obj"):
		if item_name_internal != "obj_water":
			item_offset = Vector3(0, -0.5, 0)
		
		var new_mesh : MeshInstance3D = find_item_mesh(Global.get_all_children(instance) as Array)
		if new_mesh is MeshInstance3D:
			var preview_mesh : MeshInstance3D = preview_node.get_node("ObjPreview")
			preview_mesh.mesh = new_mesh.mesh
			# match any mesh position, rotation, scale settings
			preview_mesh.position = new_mesh.position
			preview_mesh.scale = new_mesh.scale
			preview_mesh.rotation = new_mesh.rotation
			# apply construction material
			for i in range(preview_mesh.get_surface_override_material_count()):
				preview_mesh.set_surface_override_material(i, preview_cube.get_surface_override_material(0))
			# offset preview to account for item offset
			preview_mesh.position += item_offset
			preview_mesh.visible = true
			return
		else:
			preview_node.get_node("ObjPreview").visible = false

func find_item_mesh(array : Array) -> MeshInstance3D:
	for c : Variant in array:
		if c is MeshInstance3D:
			return c
		elif c is Array:
			return find_item_mesh(c as Array)
	return null

func _physics_process(delta : float) -> void:
	if active:
		var camera : Camera3D = get_viewport().get_camera_3d()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# place
			if Input.is_action_pressed("click"):
				if preview_delete_area != null:
					# if there is something where we are trying to place
					var valid : bool = true
					
					if preview_delete_area.has_overlapping_bodies():
						valid = false
					
					# if it's trying to place underwater, that's fine
					for body in preview_delete_area.get_overlapping_areas():
						if body.owner is TBWObject:
							if body.owner.tbw_object_type == "obj_water":
								valid = true
							else:
								valid = false
								break
						else:
							valid = false
							break
					
					# place if valid
					if valid:
						var inst : Node3D = selected_item.instantiate()
						Global.get_world().add_child(inst, true)
						inst.global_position = camera.controlled_cam_pos + item_offset
						inst.global_rotation = preview_node.global_rotation
						if !(inst is Brick):
							inst.scale = preview_node.scale
						if inst is TBWObject || inst is Brick:
							for property : String in selected_item_properties.keys():
								inst.set_property(property, selected_item_properties[property])
					# if trying to spawn a brick in an invalid location
					# and not dragging
					elif !$InvalidAudio.playing && Input.is_action_just_pressed("click"):
							$InvalidAudio.play()
			# delete
			elif Input.is_action_just_pressed("editor_delete"):
				# Delete the hovered object
				if preview_delete_area != null:
					# bricks, decor objects
					for body in preview_delete_area.get_overlapping_bodies():
						if body is Brick || body is TBWObject:
							body.queue_free()
					# Lifters
					for area in preview_delete_area.get_overlapping_areas():
						if area.owner is Water:
							continue
						elif area.owner is TBWObject:
							area.owner.queue_free()
		if Input.is_action_just_pressed("editor_select_item"):
			pick_item()
		if preview_node != null:
			preview_node.global_position = camera.controlled_cam_pos
			# rotation
			if Input.is_action_just_pressed("editor_rotate_left"):
				preview_node.rotate_y(deg_to_rad(-22.5))
			elif Input.is_action_just_pressed("editor_rotate_right"):
				preview_node.rotate_y(deg_to_rad(22.5))
