extends Node3D

@onready var ground_plane: MeshInstance3D = $Ground
@onready var red_button: Button = $Red
@onready var blue_button: Button = $Blue
@onready var green_button: Button = $Green
@onready var player_button: Button = $Player
@onready var preview_button: Button = $Preview
@onready var export_button: Button = $Export
@onready var import_button: Button = $Import

var player_scene = preload("res://Player.tscn")
var hover_box_scene = preload("res://HoverBox.tscn")
var camera: Camera3D
var grid_size = 1.0
var selected_color: Color = Color(1, 1, 1)
var is_preview_mode: bool = false
var is_player_mode: bool = false
var hover_box_instance: Node3D = null
var player_instance: Node3D = null

# Dictionary to store block and player positions
var saved_positions: Dictionary = {}

func _ready():
	camera = $Camera3D
	red_button.connect("pressed", Callable(self, "_on_red_button_pressed"))
	blue_button.connect("pressed", Callable(self, "_on_blue_button_pressed"))
	green_button.connect("pressed", Callable(self, "_on_green_button_pressed"))
	player_button.connect("pressed", Callable(self, "_on_player_button_pressed"))
	preview_button.connect("pressed", Callable(self, "_on_preview_button_pressed"))
	export_button.connect("pressed", Callable(self, "_on_export_button_pressed"))
	import_button.connect("pressed", Callable(self, "_on_import_button_pressed"))

	hover_box_instance = hover_box_scene.instantiate()
	add_child(hover_box_instance)
	hover_box_instance.visible = false

# Save positions of all blocks and player
func save_positions():
	# Save player position
	if player_instance != null:
		saved_positions["player"] = player_instance.position
	
	# Save positions of all blocks (using unique names)
	for child in get_children():
		if child is MeshInstance3D and child != player_instance:
			saved_positions[child.name] = child.position
	print("Positions saved: ", saved_positions)

# Restore positions of blocks and player
func restore_positions():
	# Restore player position
	if "player" in saved_positions:
		var player_pos = saved_positions["player"]
		if player_instance == null:
			player_instance = player_scene.instantiate()
			add_child(player_instance)
		player_instance.position = player_pos
		player_instance.position.y = 0.5  # Ensure the player is on the ground
		print("Player position restored to: ", player_pos)
	
	# Restore positions of blocks
	for name in saved_positions.keys():
		if name != "player":
			var block = get_node(name)  # Assuming blocks are named uniquely
			if block:
				block.position = saved_positions[name]
				print("Block position restored: ", saved_positions[name])

func _on_red_button_pressed():
	selected_color = Color(1, 0, 0)
	is_player_mode = false
	print("Selected Color: Red")

func _on_blue_button_pressed():
	selected_color = Color(0, 0, 1)
	is_player_mode = false
	print("Selected Color: Blue")

func _on_green_button_pressed():
	selected_color = Color(0, 1, 0)
	is_player_mode = false
	print("Selected Color: Green")

func _on_player_button_pressed():
	is_player_mode = !is_player_mode
	print("Player Mode: ", is_player_mode)

	# Reset hover box visibility
	if not is_player_mode:
		hover_box_instance.visible = false

func _on_export_button_pressed():
	save()  # Call the save function when the export button is pressed
	print("Game data exported (saved).")

func _on_import_button_pressed():
	load_data()  # Call the load_data function when the Import button is pressed
	print("Game data imported (loaded).")
	
func _on_preview_button_pressed():
	is_preview_mode = !is_preview_mode
	
	if is_preview_mode:
		# Save positions before going into preview mode
		save_positions()

		camera.rotation_degrees = Vector3(-60, 0, 0)
		camera.position.z = 5
		hover_box_instance.visible = false  # Hide the preview box in preview mode
	else:
		# Restore positions when returning to edit mode
		restore_positions()

		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.position.z = 0
		hover_box_instance.visible = true  # Ensure hover box is visible in normal mode

func _process(delta):
	if is_preview_mode:
		hover_box_instance.visible = false  # Ensure preview box is hidden in preview mode
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == $Ground/StaticBody3D:
		var pos = result.position
		pos.x = snap_to_grid(pos.x)
		pos.z = snap_to_grid(pos.z)
		hover_box_instance.visible = true
		hover_box_instance.position = Vector3(pos.x, 0.5, pos.z)
	else:
		hover_box_instance.visible = false

func _unhandled_input(event):
	if is_preview_mode:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
		
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider == $Ground/StaticBody3D:
			var pos = result.position
			pos.x = snap_to_grid(pos.x)
			pos.z = snap_to_grid(pos.z)
			
			if is_player_mode and player_instance == null:
				# Place player
				player_instance = player_scene.instantiate()
				add_child(player_instance)
				player_instance.position = pos
				player_instance.position.y = 0.5
				print("Player Placed at: ", pos)
			elif not is_player_mode:
				# Create and place a colored box
				var box_instance = MeshInstance3D.new()
				box_instance.mesh = BoxMesh.new()
				box_instance.mesh.size = Vector3(1, 1, 1)  # Set box dimensions
				box_instance.material_override = StandardMaterial3D.new()
				box_instance.material_override.albedo_color = selected_color
				box_instance.name = "box_" + str(randi())  # Give it a unique name
				add_child(box_instance)
				box_instance.position = pos
				box_instance.position.y = 0.5
				print("Box Placed at: ", pos)

func snap_to_grid(value: float) -> float:
	return round(value / grid_size) * grid_size

func _input(event):
	if not is_preview_mode or player_instance == null:
		return

	if event is InputEventKey and event.pressed:
		var direction = Vector3()
		if event.keycode == KEY_W:  # W key
			direction.z -= 1
		elif event.keycode == KEY_S:  # S key
			direction.z += 1
		elif event.keycode == KEY_A:  # A key
			direction.x -= 1
		elif event.keycode == KEY_D:  # D key
			direction.x += 1

		if direction != Vector3():
			move_player(direction)


func move_player(direction: Vector3):
	if player_instance == null:
		return

	# Move player by one grid unit in the given direction
	var new_position = player_instance.position + direction * grid_size
	player_instance.position = Vector3(
		snap_to_grid(new_position.x),
		player_instance.position.y,  # Maintain the same Y level
		snap_to_grid(new_position.z)
	)
	print("Player moved to: ", player_instance.position)

func save():
	var file_path = "res://save_game.dat"  # Use the user data directory for saving
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# Save player position
		if player_instance != null:
			print("Saving player position:", player_instance.position)
			file.store_var(player_instance.position)
		
		# Save positions of all blocks (excluding player)
		var block_positions: Dictionary = {}
		for child in get_children():
			if child is MeshInstance3D and child != player_instance:
				print("Saving block position:", child.position)
				# Store each block's position with its unique name
				block_positions[child.name] = child.position

		# Store the positions dictionary of blocks
		file.store_var(block_positions)

		# Store the saved positions dictionary
		file.store_var(saved_positions)

		file.close()
		print("Data saved.")
	else:
		print("Failed to open file for saving.")


		
func load_data():
	if FileAccess.file_exists("res://save_game.dat"):
		var file = FileAccess.open("res://save_game.dat", FileAccess.READ)
		if file:
			# Load player position
			if player_instance == null:
				player_instance = player_scene.instantiate()
				add_child(player_instance)
			player_instance.position = file.get_var()
			print("Player position restored to: ", player_instance.position)

			# Load block positions (store the data from the file into a dictionary)
			var block_positions = file.get_var()
			for name in block_positions.keys():
				# Check if the block exists in the scene, if not, create it
				var block = get_node_or_null(name)
				if block == null:
					# Block doesn't exist, so we need to create it
					var new_block = MeshInstance3D.new()
					new_block.mesh = BoxMesh.new()
					new_block.material_override = StandardMaterial3D.new()
					new_block.material_override.albedo_color = selected_color  # Assuming color is available
					new_block.name = name  # Use the same name as saved
					add_child(new_block)
					block = new_block  # Now we have the new block reference
				# Set the position of the block
				block.position = block_positions[name]
				print("Block position restored: ", block_positions[name])

			file.close()
			print("Data loaded.")
		else:
			print("Failed to open file for loading.")




