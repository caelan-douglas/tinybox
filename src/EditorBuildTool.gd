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

@onready var tool_inventory : EditorToolInventory = get_parent()
@onready var editor : Editor = Global.get_world().get_current_map()
@onready var editor_canvas : CanvasLayer = get_tree().current_scene.get_node("EditorCanvas")
@onready var property_editor : PropertyEditor = get_tree().current_scene.get_node("EditorCanvas/LeftPanel/PropertyEditor") 
@onready var preview_node : Node3D = $PreviewNode
@onready var preview_cube : MeshInstance3D = $PreviewNode/Cube

func _ready() -> void:
	init("(empty)")
	var camera : Camera = get_viewport().get_camera_3d()
	property_editor.connect("property_updated", _on_property_updated)
	editor.connect("deselected", _on_editor_deselected)

func _on_property_updated(properties : Dictionary) -> void:
	if property_editor.properties_from_tool == self:
		selected_item_properties = properties

func set_tool_active(mode : bool, from_click : bool = false) -> void:
	super(mode, from_click)
	if mode == false:
		editor.hide_item_chooser()
		if editor.is_connected("item_picked", _on_item_picked):
			editor.disconnect("item_picked", _on_item_picked)
		if preview_node != null:
			preview_node.visible = false
		# deselecting tool, remove any properties from list
		if property_editor.properties_from_tool == self:
			property_editor.clear_list()
	else:
		editor.show_item_chooser()
		editor.connect("item_picked", _on_item_picked)
		if preview_node != null:
			preview_node.visible = true
		# update object property list
		property_editor.relist_object_properties(selected_item_properties, self)
		# editing a new object, not a hovered one (show notif)
		property_editor.editing_hovered = false

# when the editor stops hovering over something
func _on_editor_deselected() -> void:
	if active:
		# if there are copied properties, copy them over now
		if property_editor.copied_properties.size() > 0:
			# copy each property over, if the paste destination (our selected obj) has it
			for property : String in property_editor.copied_properties.keys():
				if selected_item_properties.has(property):
					selected_item_properties[property] = property_editor.copied_properties[property]
			property_editor.copied_properties = {}
		# update object property list
		property_editor.relist_object_properties(selected_item_properties, self)
		# editing a new object, not a hovered one (show notif)
		property_editor.editing_hovered = false

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
	selected_item_properties = property_editor.list_object_properties(instance, self)
	property_editor.editing_hovered = false
	# only bricks can have scale, reset if not a brick
	if !item_name_internal.begins_with("brick") || selected_item_name_internal == "brick_motor_seat":
		preview_node.scale = Vector3(1, 1, 1)
	# offset objects down a bit, also update preview
	if item_name_internal.begins_with("obj"):
		if item_name_internal != "obj_water" && item_name_internal != "obj_camera_preview_point":
			item_offset = Vector3(0, -0.5, 0)
		
		var new_mesh : MeshInstance3D = find_item_mesh(Global.get_all_children(instance) as Array)
		if new_mesh is MeshInstance3D:
			var preview_mesh : MeshInstance3D = preview_node.get_node("ObjPreview")
			preview_mesh.mesh = new_mesh.mesh
			# match any mesh position, rotation, scale settings
			# offset slightly to avoid z-fighting
			preview_mesh.position = new_mesh.position + Vector3.UP * 0.004
			preview_mesh.scale = new_mesh.scale * 1.004
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
	# if switching to non-obj (ex. a brick) don't show any preview
	else:
		var preview_mesh : MeshInstance3D = preview_node.get_node("ObjPreview")
		preview_mesh.visible = false
	# clear temp instance
	instance.queue_free()

func find_item_mesh(array : Array) -> MeshInstance3D:
	for c : Variant in array:
		if c is MeshInstance3D:
			return c
		elif c is Array:
			return find_item_mesh(c as Array)
	return null

func _physics_process(delta : float) -> void:
	var camera := get_viewport().get_camera_3d()
	if preview_node != null:
		preview_node.global_position = camera.controlled_cam_pos
		# rotation
		if Input.is_action_just_pressed("editor_rotate_reset"):
			preview_node.rotation = Vector3.ZERO
		elif Input.is_action_just_pressed("editor_rotate_left"):
			preview_node.rotate(Vector3.UP, deg_to_rad(22.5))
		elif Input.is_action_just_pressed("editor_rotate_right"):
			preview_node.rotate(Vector3.UP, deg_to_rad(-22.5))
		elif Input.is_action_just_pressed("editor_rotate_up"):
			preview_node.rotate(camera.basis.x.round(), deg_to_rad(-22.5))
		elif Input.is_action_just_pressed("editor_rotate_down"):
			preview_node.rotate(camera.basis.x.round(), deg_to_rad(22.5))
		preview_node.rotation = Vector3(snapped(preview_node.rotation.x, deg_to_rad(22.5)) as float, snapped(preview_node.rotation.y, deg_to_rad(22.5)) as float, snapped(preview_node.rotation.z, deg_to_rad(22.5)) as float)
		# scale
		if selected_item_name_internal.begins_with("brick") && selected_item_name_internal != "brick_motor_seat":
			if Input.is_action_just_pressed("editor_scale_up"):
				# flip on vertical
				var cam_basis := camera.basis.y.round()
				cam_basis = Vector3(abs(cam_basis.x) as float, abs(cam_basis.y) as float, abs(cam_basis.z) as float)
				preview_node.scale += cam_basis * 2
			elif Input.is_action_just_pressed("editor_scale_down"):
				var cam_basis := camera.basis.y.round()
				cam_basis = Vector3(abs(cam_basis.x) as float, abs(cam_basis.y) as float, abs(cam_basis.z) as float)
				preview_node.scale -= cam_basis * 2
		preview_node.scale = preview_node.scale.clamp(Vector3(1, 1, 1), Vector3(31, 31, 31))
	if active:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# place
			if Input.is_action_pressed("click"):
				if editor.select_area != null:
					# if there is something where we are trying to place
					var valid : bool = true
					
					# if it's trying to place underwater, that's fine
					for body in editor.select_area.get_overlapping_areas():
						if body.owner is TBWObject:
							if body.owner.tbw_object_type == "obj_water":
								valid = true
							else:
								valid = false
								break
						else:
							valid = false
							break
					
					# however if there are any overlapping bodies it's no longer valid
					if editor.select_area.has_overlapping_bodies():
						valid = false
					
					# place if valid
					if valid && selected_item != null:
						var inst : Node3D = selected_item.instantiate()
						Global.get_world().add_child(inst, true)
						inst.global_position = get_viewport().get_camera_3d().controlled_cam_pos
						inst.global_rotation = preview_node.global_rotation
						
						inst.translate_object_local(item_offset)
						if inst is Brick:
							inst.set_property("brick_scale", preview_node.scale)
						# rotate wheels because they have different rotation direction than
						# facing direction
						if inst is MotorBrick:
							inst.rotate_object_local(Vector3.UP, -PI/2)
						if inst is TBWObject || inst is Brick:
							for property : String in selected_item_properties.keys():
								inst.set_property(property, selected_item_properties[property])
					# if trying to spawn a brick in an invalid location
					# and not dragging
					elif !$InvalidAudio.playing && Input.is_action_just_pressed("click"):
						$InvalidAudio.play()
						# show alert that nothing is selected
						if selected_item == null:
							UIHandler.show_alert("Select something to place from the left.\n(Press ESC to free your mouse.)", 3, false, UIHandler.alert_colour_error)
						else:
							UIHandler.show_alert("Can't place there! Selection (green)\nmust be unobstructed", 4, false, UIHandler.alert_colour_error)
