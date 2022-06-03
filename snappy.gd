@tool
extends EditorPlugin

const ray_length = 1000

var selection = get_editor_interface().get_selection()
var selected : Node3D = null

@onready var Marker = preload("res://addons/snappy/marker.tscn")

var origin = Vector3()
var origin_2d = null



func _enter_tree():
	selection.connect("selection_changed", _on_selection_changed)

#func _exit_tree():
	
	
func _handles(object):
	if object is Node3D:
		return true
	return false

func _forward_3d_draw_over_viewport(overlay):
	if origin_2d != null:
		overlay.draw_circle(origin_2d, 4, Color.YELLOW)
	pass

func _forward_3d_gui_input(camera, event):
	if event is InputEventMouse and selected != null and Input.is_key_pressed(KEY_V):
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * ray_length
		var direction = camera.project_ray_normal(event.position)

		if event.button_mask != MOUSE_BUTTON_LEFT:
			var meshes = find_meshes(selected)
			origin = find_closest_point(meshes, from, direction)

			if origin != Vector3.ZERO:
				origin_2d = camera.unproject_position(origin)
			else:
				origin_2d = null
			update_overlays()
		else:
			if origin != Vector3.ZERO:
				origin_2d = camera.unproject_position(origin)
				update_overlays()
				var ids = RenderingServer.instances_cull_ray(from, to, selected.get_world_3d().scenario)
				var meshes = []
				for id in ids:
					var obj = instance_from_id(id)
					if obj != selected and obj.get_parent() != selected and obj is Node3D:
						meshes += find_meshes(obj)
 
				var target = find_closest_point(meshes, from, direction)
				if target != Vector3.ZERO:
					selected.translate((target * selected.global_transform.basis) - (origin * selected.global_transform.basis))
					origin = target
					
				return true
	if not Input.is_key_pressed(KEY_V):
		origin_2d = null
		update_overlays()
	return false

func _on_selection_changed():
	var nodes = selection.get_selected_nodes()
	if nodes.size() == 1 and nodes[0] is Node3D:
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
	
func find_closest_point(meshes : Array, from : Vector3, direction) -> Vector3:
	var closest := Vector3.ZERO
	
	for mesh in meshes:
		var faces = mesh.get_mesh().get_faces()
		for i in range(0, faces.size(), 3):
			var p1: Vector3 = mesh.global_transform * faces[i]
			var p2: Vector3 = mesh.global_transform * faces[i + 1]
			var p3: Vector3 = mesh.global_transform * faces[i + 2]
			var intersection = Geometry3D.ray_intersects_triangle(from, direction, p1, p2, p3)
			if intersection != null:
				var vertex_point = null
				for point in [p1, p2, p3]:
					if vertex_point == null or intersection.distance_to(vertex_point) > intersection.distance_to(point):
						vertex_point = point
				if closest == Vector3.ZERO or from.distance_to(closest) > from.distance_to(vertex_point):
					closest = vertex_point
	
	return closest
