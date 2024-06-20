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
	if item_name_internal != "obj_water":
		# offset objects down a bit
		if item_name_internal.begins_with("obj"):
			item_offset = Vector3(0, -0.49, 0)

func _physics_process(delta):
	if active:
		var camera = get_viewport().get_camera_3d()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# place
			if Input.is_action_pressed("click"):
				if preview_delete_area != null:
					if !preview_delete_area.has_overlapping_bodies():
						var inst = selected_item.instantiate()
						Global.get_world().add_child(inst, true)
						inst.global_position = camera.controlled_cam_pos + item_offset
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
						if area.owner is TBWObject:
							area.owner.queue_free()
		if Input.is_action_just_pressed("editor_select_item"):
			pick_item()
		if preview_node != null:
			preview_node.global_position = camera.controlled_cam_pos
