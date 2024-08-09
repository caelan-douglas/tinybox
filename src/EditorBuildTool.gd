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
var active_preview_instance : Node3D = null
var drag_start_point : Vector3 = Vector3.ZERO
var b_scale : Vector3 = Vector3.ZERO
var drag_end_point : Vector3 = Vector3.ZERO
var last_rotation : Vector3 = Vector3.ZERO

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

func _on_item_picked(item_name_internal : String, item_name_display : String = "", relist_properties : bool = true) -> void:
	ui_tool_name = item_name_display
	if item_name_display != "":
		ui_partner.text = str(item_name_display)
	item_offset = Vector3.ZERO
	if !SpawnableObjects.objects.has(item_name_internal):
		return
	selected_item = SpawnableObjects.objects[item_name_internal]
	selected_item_name_internal = item_name_internal
	# show editable properties
	var inst : Node3D = selected_item.instantiate()
	# relist properties while instance has script
	if relist_properties:
		selected_item_properties = property_editor.list_object_properties(inst, self)
	# disable script
	inst.set_script(null)
	for c : Node in preview_node.get_children():
		if c.name != "Display":
			c.queue_free()
	# add instance as preview
	preview_node.add_child(inst)
	inst.global_position -= item_offset
	inst.rotation = last_rotation
	active_preview_instance = inst
	property_editor.editing_hovered = false
	# offset objects down a bit, also update preview
	if item_name_internal.begins_with("obj"):
		if item_name_internal != "obj_water" && item_name_internal != "obj_camera_preview_point":
			item_offset = Vector3(0, -0.5, 0)
	var new_mesh : MeshInstance3D = find_item_mesh(Global.get_all_children(inst) as Array)
	if new_mesh != null:
		# apply construction material
		for i in range(new_mesh.get_surface_override_material_count()):
			new_mesh.set_surface_override_material(i, load("res://data/materials/editor_placement_material.tres") as Material)

func find_item_mesh(array : Array) -> MeshInstance3D:
	for c : Variant in array:
		if c is MeshInstance3D:
			return c
		elif c is Array:
			return find_item_mesh(c as Array)
	return null

func selected_item_is_draggable() -> bool:
	if selected_item_name_internal.begins_with("brick") && selected_item_name_internal != "brick_motor_seat":
		return true
	else: return false

func selected_item_is_scalable() -> bool:
	if selected_item_name_internal.begins_with("obj"):
		return true
	else: return false

func _physics_process(delta : float) -> void:
	var camera := get_viewport().get_camera_3d()
	if active:
		if preview_node != null:
			preview_node.global_position = camera.controlled_cam_pos
			var rot_amount : float = 22.5
			if selected_item_is_draggable():
				rot_amount = 90
			if active_preview_instance != null:
				# rotation
				if Input.is_action_just_pressed("editor_rotate_reset"):
					active_preview_instance.rotation = Vector3.ZERO
				elif Input.is_action_just_pressed("editor_rotate_left"):
					active_preview_instance.rotate(Vector3.UP, deg_to_rad(rot_amount))
				elif Input.is_action_just_pressed("editor_rotate_right"):
					active_preview_instance.rotate(Vector3.UP, deg_to_rad(-rot_amount))
				elif Input.is_action_just_pressed("editor_rotate_up"):
					active_preview_instance.rotate(camera.basis.x.round(), deg_to_rad(-rot_amount))
				elif Input.is_action_just_pressed("editor_rotate_down"):
					active_preview_instance.rotate(camera.basis.x.round(), deg_to_rad(rot_amount))
				elif Input.is_action_just_pressed("editor_scale_up"):
					if selected_item_is_scalable():
						active_preview_instance.scale += Vector3(1, 1, 1)
						active_preview_instance.scale = clamp(active_preview_instance.scale, Vector3(1, 1, 1), Vector3(10, 10, 10))
				elif Input.is_action_just_pressed("editor_scale_down"):
					if selected_item_is_scalable():
						active_preview_instance.scale -= Vector3(1, 1, 1)
						active_preview_instance.scale = clamp(active_preview_instance.scale, Vector3(1, 1, 1), Vector3(10, 10, 10))
				active_preview_instance.rotation = Vector3(snapped(active_preview_instance.rotation.x, deg_to_rad(22.5)) as float, snapped(active_preview_instance.rotation.y, deg_to_rad(22.5)) as float, snapped(active_preview_instance.rotation.z, deg_to_rad(22.5)) as float)
				last_rotation = active_preview_instance.rotation 
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# place
			if Input.is_action_just_pressed("click"):
				drag_start_point = get_viewport().get_camera_3d().controlled_cam_pos
			if Input.is_action_pressed("click"):
				if selected_item_is_draggable():
					# Click and drag to scale bricks
					drag_end_point = get_viewport().get_camera_3d().controlled_cam_pos
					active_preview_instance.global_position = drag_start_point.lerp(drag_end_point, 0.5)
					b_scale = abs(drag_end_point - drag_start_point) + Vector3(1, 1, 1)
					b_scale = b_scale.clamp(Vector3(1, 1, 1), Vector3(2000, 2000, 2000))
					active_preview_instance.scale = Vector3(1, 1, 1)
					active_preview_instance.global_scale(b_scale)
					if b_scale != Vector3(1, 1, 1):
						editor_canvas.scale_tooltip.text = str(b_scale.x, " x ", b_scale.y, " x ", b_scale.z)
			if Input.is_action_just_released("click"):
				# when recapturing mouse with click
				if editor.editor_canvas.mouse_just_captured:
					return
				editor_canvas.scale_tooltip.text = ""
				# if the selected item isn't scalable, ignore drag and just place
				# at the same place as the end point
				if !selected_item_is_draggable():
					drag_start_point = get_viewport().get_camera_3d().controlled_cam_pos
				drag_end_point = get_viewport().get_camera_3d().controlled_cam_pos
				if editor.select_area != null:
					# if there is something where we are trying to place
					var valid : bool = true
					
					# if it's trying to place underwater, that's fine
					for body in editor.select_area.get_overlapping_areas():
						if body.owner is TBWObject:
							if body.owner.tbw_object_type == "obj_water":
								valid = true
							elif body.owner != active_preview_instance:
								valid = false
								break
						elif body.owner != active_preview_instance:
							valid = false
							break
					
					# however if there are any overlapping bodies it's no longer valid
					for body in editor.select_area.get_overlapping_bodies():
						if body != active_preview_instance:
							valid = false
					
					# place if valid
					if valid && selected_item != null:
						var inst : Node3D = selected_item.instantiate()
						Global.get_world().add_child(inst, true)
						inst.global_position = drag_start_point.lerp(drag_end_point, 0.5)
						inst.global_rotation = active_preview_instance.global_rotation
						if selected_item_is_draggable():
							if selected_item_properties.has("brick_scale"):
								if selected_item_name_internal == "brick_cylinder":
									# x is forward on wheels
									selected_item_properties["brick_scale"] = Vector3(active_preview_instance.scale.z, active_preview_instance.scale.y, active_preview_instance.scale.x)
								else:
									selected_item_properties["brick_scale"] = active_preview_instance.scale
						else:
							# match global transform for objects
							inst.global_transform = active_preview_instance.global_transform
						#inst.global_position += item_offset
						if inst is TBWObject || inst is Brick:
							for property : String in selected_item_properties.keys():
								inst.set_property(property, selected_item_properties[property])
					# if trying to spawn a brick in an invalid location
					# and not dragging
					elif !$InvalidAudio.playing && Input.is_action_just_released("click"):
						$InvalidAudio.play()
						# show alert that nothing is selected
						if selected_item == null:
							UIHandler.show_alert("Select something to place from the left.\n(Press ESC to free your mouse.)", 3, false, UIHandler.alert_colour_error)
						else:
							UIHandler.show_alert("Can't place there! Selection (green)\nmust be unobstructed", 4, false, UIHandler.alert_colour_error)
				# regenerate after placement
				if selected_item_is_draggable():
					_on_item_picked(selected_item_name_internal, "", false)
