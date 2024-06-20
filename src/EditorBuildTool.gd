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

var selected_item = null
var item_offset = Vector3(0, 0, 0)

@onready var preview_node = $PreviewNode
@onready var preview_delete_area = $PreviewNode/DeleteArea
@onready var preview_cube = $PreviewNode/Cube

func _ready():
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

func pick_item() -> void:
	var editor = Global.get_world().get_current_map()
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

func _on_item_picked(item_name_internal : String, item_name_display) -> void:
	ui_tool_name = item_name_display
	ui_partner.text = str(item_name_display)
	item_offset = Vector3.ZERO
	if !SpawnableObjects.objects.has(item_name_internal):
		return
	selected_item = SpawnableObjects.objects[item_name_internal]
	# offset objects down a bit, also update preview
	if item_name_internal.begins_with("obj"):
		if item_name_internal != "obj_water":
			item_offset = Vector3(0, -0.49, 0)
		# update preview of mesh
		var instance = selected_item.instantiate()
		var new_mesh = find_item_mesh(Global.get_all_children(instance))
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

func find_item_mesh(array):
	for c in array:
		if c is MeshInstance3D:
			return c
		elif c is Array:
			return find_item_mesh(c)

func _physics_process(delta):
	if active:
		var camera = get_viewport().get_camera_3d()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# place
			if Input.is_action_pressed("click"):
				if preview_delete_area != null:
					if !preview_delete_area.has_overlapping_bodies() && !preview_delete_area.has_overlapping_areas():
						var inst = selected_item.instantiate()
						Global.get_world().add_child(inst, true)
						inst.global_position = camera.controlled_cam_pos + item_offset
						inst.global_rotation = preview_node.global_rotation
						if !(inst is Brick):
							inst.scale = preview_node.scale
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
			# scale
			if Input.is_action_just_pressed("editor_scale_up"):
				preview_node.scale += Vector3(0.5, 0.5, 0.5)
			elif Input.is_action_just_pressed("editor_scale_down"):
				preview_node.scale -= Vector3(0.5, 0.5, 0.5)
			preview_node.scale = clamp(preview_node.scale, Vector3(0.5, 0.5, 0.5), Vector3(5, 5, 5))
