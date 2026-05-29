extends SceneTree

const SCENE_PATH := "res://scenes/gdgs_happy_path_control.tscn"
const CAMERA_MOVE_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E]
const BASE_MOVE_FRAME_COUNT := 3

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
		{"key": KEY_W, "direction": -camera_rig.global_basis.z, "name": "W", "flatten": true},
		{"key": KEY_A, "direction": -camera_rig.global_basis.x, "name": "A", "flatten": true},
		{"key": KEY_S, "direction": camera_rig.global_basis.z, "name": "S", "flatten": true},
		{"key": KEY_D, "direction": camera_rig.global_basis.x, "name": "D", "flatten": true},
		{"key": KEY_Q, "direction": Vector3.UP, "name": "Q", "flatten": false},
		{"key": KEY_E, "direction": Vector3.DOWN, "name": "E", "flatten": false},
	]

	var base_forward_distance := 0.0
	for movement_check in movement_checks:
		camera_rig.global_position = Vector3(0.0, 0.0, 4.0)
		await process_frame
		var before := camera_rig.global_position
		_press_key(int(movement_check["key"]), true)
		await _advance_frames(BASE_MOVE_FRAME_COUNT)
		_press_key(int(movement_check["key"]), false)
		var delta := camera_rig.global_position - before
		if delta.length() <= 0.001:
			_fail("%s did not move the camera while drag-look was active" % String(movement_check["name"]))
			return
		if not _movement_matches_expected(delta, movement_check):
			_fail("%s moved the camera in the wrong direction" % String(movement_check["name"]))
			return
		if int(movement_check["key"]) == KEY_W:
			base_forward_distance = delta.length()

	if base_forward_distance <= 0.001:
		_fail("Failed to capture baseline W movement distance")
		return

	camera_rig.global_position = Vector3(0.0, 0.0, 4.0)
	await process_frame
	var boosted_before := camera_rig.global_position
	_press_key(KEY_SHIFT, true)
	_press_key(KEY_W, true)
	await _advance_frames(BASE_MOVE_FRAME_COUNT)
	_press_key(KEY_W, false)
	_press_key(KEY_SHIFT, false)
	var boosted_delta := camera_rig.global_position - boosted_before
	if not _movement_matches_expected(boosted_delta, {"direction": -camera_rig.global_basis.z, "flatten": true}):
		_fail("Shift + W moved the camera in the wrong direction")
		return
	if boosted_delta.length() <= base_forward_distance * 1.5:
		_fail("Shift speed boost did not materially increase forward movement")
		return

	var left_up := InputEventMouseButton.new()
	left_up.button_index = MOUSE_BUTTON_LEFT
	left_up.pressed = false
	root._unhandled_input(left_up)

	camera_rig.global_position = Vector3(0.0, 0.0, 4.0)
	await process_frame
	var gated_before := camera_rig.global_position
	_press_key(KEY_W, true)
	await _advance_frames(BASE_MOVE_FRAME_COUNT)
	_press_key(KEY_W, false)
	var gated_delta := camera_rig.global_position - gated_before
	if gated_delta.length() > 0.001:
		_fail("Camera movement should stay gated behind left-drag")
		return

	for keycode in CAMERA_MOVE_KEYS:
		_press_key(keycode, false)
	_press_key(KEY_SHIFT, false)

	print("[gdgs-validate-controls] PASS yaw=%.4f pitch=%.4f base_forward=%.4f boosted_forward=%.4f" % [
		camera_rig.rotation.y,
		camera_pitch.rotation.x,
		base_forward_distance,
		boosted_delta.length()
	])
	quit(0)

func _advance_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame

func _movement_matches_expected(delta: Vector3, movement_check: Dictionary) -> bool:
	var expected: Vector3 = movement_check["direction"]
	var measured := delta
	if bool(movement_check.get("flatten", false)):
		expected.y = 0.0
		measured.y = 0.0
	if expected.length() <= 0.001 or measured.length() <= 0.001:
		return false
	expected = expected.normalized()
	measured = measured.normalized()
	return measured.dot(expected) >= 0.8

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _fail(message: String) -> void:
	printerr("[gdgs-validate-controls] FAIL %s" % message)
	quit(1)
