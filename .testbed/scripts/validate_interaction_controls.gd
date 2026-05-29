extends SceneTree

const SCENE_PATH := "res://scenes/gdgs_happy_path_control.tscn"
const CAMERA_MOVE_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D]

func _initialize() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		_fail("Failed to load scene: %s" % SCENE_PATH)
		return

	var root := scene.instantiate()
	get_root().add_child(root)

	await process_frame
	await process_frame

	var camera_rig := root.get_node_or_null("CameraRig") as Node3D
	var camera_pitch := root.get_node_or_null("CameraRig/CameraPitch") as Node3D
	if camera_rig == null or camera_pitch == null:
		_fail("Scene is missing CameraRig/CameraPitch")
		return

	var initial_yaw := camera_rig.rotation.y
	var initial_pitch := camera_pitch.rotation.x

	var left_down := InputEventMouseButton.new()
	left_down.button_index = MOUSE_BUTTON_LEFT
	left_down.pressed = true
	root._unhandled_input(left_down)

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(32.0, -18.0)
	root._unhandled_input(motion)
	await process_frame

	if is_equal_approx(camera_rig.rotation.y, initial_yaw):
		_fail("Left-click drag did not rotate camera yaw")
		return
	if is_equal_approx(camera_pitch.rotation.x, initial_pitch):
		_fail("Left-click drag did not rotate camera pitch")
		return

	var movement_checks := [
		{"key": KEY_W, "direction": -camera_rig.global_basis.z, "name": "W"},
		{"key": KEY_A, "direction": -camera_rig.global_basis.x, "name": "A"},
		{"key": KEY_S, "direction": camera_rig.global_basis.z, "name": "S"},
		{"key": KEY_D, "direction": camera_rig.global_basis.x, "name": "D"},
	]

	for movement_check in movement_checks:
		camera_rig.global_position = Vector3(0.0, 0.0, 4.0)
		await process_frame
		var before := camera_rig.global_position
		_press_key(int(movement_check["key"]), true)
		await process_frame
		await process_frame
		await process_frame
		_press_key(int(movement_check["key"]), false)
		var delta := camera_rig.global_position - before
		if delta.length() <= 0.001:
			_fail("%s did not move the camera while drag-look was active" % String(movement_check["name"]))
			return
		var flattened_expected: Vector3 = (movement_check["direction"] as Vector3)
		flattened_expected.y = 0.0
		flattened_expected = flattened_expected.normalized()
		var flattened_delta := delta
		flattened_delta.y = 0.0
		flattened_delta = flattened_delta.normalized()
		if flattened_delta.dot(flattened_expected) < 0.8:
			_fail("%s moved the camera in the wrong direction" % String(movement_check["name"]))
			return

	var left_up := InputEventMouseButton.new()
	left_up.button_index = MOUSE_BUTTON_LEFT
	left_up.pressed = false
	root._unhandled_input(left_up)

	for keycode in CAMERA_MOVE_KEYS:
		_press_key(keycode, false)

	print("[gdgs-validate-controls] PASS yaw=%.4f pitch=%.4f" % [camera_rig.rotation.y, camera_pitch.rotation.x])
	quit(0)

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _fail(message: String) -> void:
	printerr("[gdgs-validate-controls] FAIL %s" % message)
	quit(1)
