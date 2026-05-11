extends RigidBody3D
class_name Ball

signal stroke_added(count: int)
signal entered_hole

@export var ball_color: Color = Color(1, 0.2, 0.2, 1)

var stroke_count := 0

func setup_replication_config():
	var sync = $MultiplayerSynchronizer
	var config = sync.replication_config
	
	if config.has_property(NodePath(":global_position")):
		return

	config.add_property(NodePath(":global_position"))
	config.add_property(NodePath(":global_rotation"))
	config.add_property(NodePath(":linear_velocity"))
	config.add_property(NodePath(":angular_velocity"))
	
	if not multiplayer.is_server():
		print("I am client! %s" % multiplayer.get_unique_id())
		sync.replication_interval = 9999.0
		sync.public_visibility = false
	
	if multiplayer.is_server():
		print("I am server! %s" % multiplayer.get_unique_id())
		sync.replication_interval = 0.05
		config.property_set_replication_mode(
			NodePath(":linear_velocity"), 
			SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		)
		config.property_set_replication_mode(
			NodePath(":angular_velocity"), 
			SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		)

		config.property_set_replication_mode(
			NodePath(":global_position"), 
			SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		)
		config.property_set_replication_mode(
			NodePath(":global_rotation"), 
			SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		)

func _ready() -> void:
	await get_tree().process_frame
	
	if multiplayer.is_server():
		# Хост: полная физика
		freeze = false
		sleeping = false
		contact_monitor = true
		max_contacts_reported = 10
		linear_damp = 0.5
		angular_damp = 0.5
	else:
		# Клиент: отключаем физику
		freeze = true
		sleeping = true
		collision_layer = 0
		collision_mask = 0

	setup_replication_config()
	_apply_color()

func _apply_color() -> void:
	var mesh := $MeshInstance3D as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ball_color
		mesh.set_surface_override_material(0, mat)

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return

	if linear_velocity.length() < 0.1 and linear_velocity != Vector3.ZERO:
		linear_velocity = Vector3.ZERO

func do_spawn(pos: Vector3) -> void:
	global_position = pos

func apply_stroke(power: float, direction: Vector3) -> void:
	apply_impulse(direction * power)
	stroke_count += 1
	stroke_added.emit(stroke_count)

func do_reset(pos: Vector3) -> void:
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	stroke_count = 0
	stroke_added.emit(stroke_count)

func _input(event):
	if Input.is_key_pressed(KEY_F1):
		debug_sync_state()

func debug_sync_state():
	var sync = $MultiplayerSynchronizer
	print("=== Sync Debug for ", name, " ===")
	print("Multiplayer authority: ", get_multiplayer_authority())
	print("Is multiplayer authority: ", is_multiplayer_authority())
	print("My peer ID: ", multiplayer.get_unique_id())
	print("Replication interval: ", sync.replication_interval)
	print("Visible to peers: ", sync.get_visibility_for(1))
	print("Properties synced: ", sync.replication_config.get_properties())
	print("Global position: ", global_position)

	if multiplayer.is_server():
		print("SENDING state to clients")
	else:
		print("RECEIVING state from host")
