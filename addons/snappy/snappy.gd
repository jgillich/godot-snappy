@tool
extends EditorPlugin

const RAY_LENGTH = 1000
# Workaround for Vector3.INF GDScript issue https://github.com/godotengine/godot/issues/61643
const VECTOR_INF = Vector3(INF, INF, INF)

@onready var undo_redo = get_undo_redo()
var undo_position = null

var selection = get_editor_interface().get_selection()
var selected : Node3D = null
var dragging = false
var origin = Vector3()
var origin_2d = null

func _enter_tree():
	selection.connect("selection_changed", _on_selection_changed)

func _handles(object):
	if object is Node3D:
		return true
	return false

func _forward_3d_draw_over_viewport(overlay):
	if origin_2d != null:
		overlay.draw_circle(origin_2d, 4, Color.YELLOW)
	pass

func _forward_3d_gui_input(camera, event):
	# We need mouse events to get the cursor position
	# This means pressing V when no mouse events are being sent does nothing
	# It's rarely noticable though
	if selected == null or not event is InputEventMouse:
		return false

	#if event is InputEventMouse:
	var now_dragging = event.button_mask == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_V)
	if dragging and not now_dragging and origin != VECTOR_INF:
		undo_redo.create_action("Snap vertex")
		undo_redo.add_do_property(selected, "position", selected.position)
		undo_redo.add_undo_property(selected, "position", undo_position)
		undo_redo.commit_action()
	dragging = now_dragging


	if Input.is_key_pressed(KEY_V):
		var from = camera.project_ray_origin(event.position)
		var direction = camera.project_ray_normal(event.position)
		var to = from + direction * RAY_LENGTH

		if not dragging:
			var meshes = find_meshes(selected)
			origin = find_closest_point(meshes, from, direction)
			undo_position = selected.position

			if origin != VECTOR_INF:
				origin_2d = camera.unproject_position(origin)
			else:
				origin_2d = null
			update_overlays()
		elif origin != VECTOR_INF:
			origin_2d = camera.unproject_position(origin)
			update_overlays()
			var ids = RenderingServer.instances_cull_ray(from, to, selected.get_world_3d().scenario)
			var meshes = []
			for id in ids:
				var obj = instance_from_id(id)
				if obj != selected and obj.get_parent() != selected and obj is Node3D:
					meshes += find_meshes(obj)

			var target = find_closest_point(meshes, from, direction)
			if target != VECTOR_INF:
				selected.global_position -= origin - target
				origin = target
			return true
	else:
		origin = VECTOR_INF
		origin_2d = null
		update_overlays()
	return false

func _on_selection_changed():
	var nodes = selection.get_selected_nodes()
	if nodes.size() > 0 and nodes[0] is Node3D:
		selected = nodes[0]
	else:
		selected = null
		origin = null

func find_meshes(node : Node3D) -> Array:
	var meshes : Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		if child is Node3D:
			meshes += find_meshes(child)
	return meshes

func find_closest_point(meshes : Array, from : Vector3, direction : Vector3) -> Vector3:
	var closest := VECTOR_INF
	var closest_distance := INF

	# We will not use the distance between the vertex and the from position,
	# (that would always be the vertex closest to the camera). Instead we
	# use the distance between the vertex and the ray under the mouse cursor.
	# Ideally we would use the 2d distance of the unprojected vertices,
	# however unprojecting every vertex can have a performance penalty for
	# large meshes. This is a good balance between performance and accuracy.
	var segment_start := from
	var segment_end := from + direction

	for mesh in meshes:
		var vertices = mesh.get_mesh().get_faces()
		for i in range(vertices.size()):
			var current_point: Vector3 = mesh.global_transform * vertices[i]
			var current_on_ray := Geometry3D.get_closest_point_to_segment_uncapped(
				current_point, segment_start, segment_end)
			var current_distance := current_on_ray.distance_to(current_point)
			if closest == VECTOR_INF or current_distance < closest_distance:
				closest = current_point
				closest_distance = current_distance

	return closest
