@tool
extends EditorPlugin

const ray_length = 1000

var selection = get_editor_interface().get_selection()
var selected : Node3D = null

var origin = Vector3()

func _enter_tree():
	selection.connect("selection_changed", _on_selection_changed)
	print("_enter_tree")

func _exit_tree():
	print("_exit_tree")
	
func _handles(object):
	if object is Node3D:
		return true
	return false

func _forward_3d_draw_over_viewport(overlay):
	#overlay.draw_style_box(Rect2(overlay.get_local_mouse_position()), 16)
	#overlay.draw_arc(overlay.get_local_mouse_position(), 16.0, deg2rad(0), deg2rad(360), 16, Color.YELLOW)
#	print(overlay.get_local_mouse_position(), " ", Vector2(origin.x, origin.z))
#	overlay.draw_circle(overlay.get_local_mouse_position(), 16, Color.YELLOW)
#	overlay.draw_circle(Vector2(origin.x, origin.z), 4, Color.YELLOW)
	pass

func _forward_3d_gui_input(camera, event):
	if event is InputEventMouse and selected != null:
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * ray_length
		var direction = camera.project_ray_normal(event.position)
		
		if event.button_mask != MOUSE_BUTTON_LEFT:
			var meshes = find_meshes(selected)
			origin = find_closest_point(meshes, from, direction)
			#update_overlays()
			return false
		elif Input.is_key_pressed(KEY_V):
			if origin != null:
				var ids = RenderingServer.instances_cull_ray(from, to, selected.get_world_3d().scenario)
				var meshes = []
				for id in ids:
					var obj = instance_from_id(id)
					if obj != selected and obj.get_parent() != selected and obj is Node3D:
						meshes += find_meshes(obj)
 
				var target = find_closest_point(meshes, from, direction)
				if target != Vector3.ZERO:
					selected.translate(target - origin)
					origin = target
				return true
				
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
	var points = []
	var closest = Vector3.ZERO
	for mesh in meshes:
		var faces = mesh.get_mesh().get_faces()
		for i in range(0, faces.size(), 3):
			var p1: Vector3 = mesh.global_transform * faces[i]
			var p2: Vector3 = mesh.global_transform * faces[i + 1]
			var p3: Vector3 = mesh.global_transform * faces[i + 2]
			if Geometry3D.ray_intersects_triangle(from, direction, p1, p2, p3) != null:
				points += [p1, p2, p3]

	for point in points:
		if closest == Vector3.ZERO or from.distance_to(closest) > from.distance_to(point):
			closest = point
			
	return closest
