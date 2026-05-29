extends SceneTree

const SCENE_PATH := "res://scenes/gdgs_happy_path_control.tscn"
const MANAGER_NODE_NAME := "_GdgsGaussianRenderManager"

func _initialize() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		_fail("Failed to load scene: %s" % SCENE_PATH)
		return

	var root := scene.instantiate()
	get_root().add_child(root)

	await process_frame
	await process_frame

	var anchor := root.get_node_or_null("SplatAnchor") as Node3D
	var splat := root.get_node_or_null("SplatAnchor/GaussianSplatNode") as Node3D
	if anchor == null:
		_fail("Scene is missing SplatAnchor parent")
		return
	if splat == null:
		_fail("Scene is missing SplatAnchor/GaussianSplatNode")
		return

	var initial_snapshot := await _await_snapshot_for(splat)
	if initial_snapshot.is_empty():
		_fail("Manager never published an initial debug snapshot for GaussianSplatNode")
		return

	anchor.position = Vector3(1.25, 0.5, 0.0)
	anchor.rotation_degrees = Vector3(-15.0, 45.0, 0.0)
	anchor.scale = Vector3(1.35, 0.8, 1.1)

	var transformed_snapshot := await _await_snapshot_for(splat)
	if transformed_snapshot.is_empty():
		_fail("Manager never published a transformed debug snapshot for GaussianSplatNode")
		return
	if not _transform_equal_approx(transformed_snapshot.get("model_transform", Transform3D.IDENTITY), splat.global_transform):
		_fail("Registry model_transform did not match splat.global_transform after applying parent transform")
		return
	if int(transformed_snapshot.get("instance_index", -1)) < 0:
		_fail("Registry debug snapshot missing a valid instance_index")
		return
	if int(transformed_snapshot.get("point_count", 0)) <= 0:
		_fail("Registry debug snapshot reported no uploaded points")
		return

	splat.visible = false
	var hidden_snapshot := await _await_snapshot_for(splat)
	if bool(hidden_snapshot.get("visible", true)):
		_fail("Registry debug snapshot did not track hidden visibility")
		return

	splat.visible = true
	var restored_snapshot := await _await_snapshot_for(splat)
	if not bool(restored_snapshot.get("visible", false)):
		_fail("Registry debug snapshot did not restore visible=true")
		return

	print("[gdgs-validate] PASS parent=%s splat=%s instance_index=%s point_count=%s origin=%s" % [
		str(anchor.get_path()),
		str(splat.get_path()),
		str(restored_snapshot.get("instance_index", -1)),
		str(restored_snapshot.get("point_count", 0)),
		var_to_str((restored_snapshot.get("model_transform", Transform3D.IDENTITY) as Transform3D).origin)
	])
	quit(0)

func _await_snapshot_for(splat: Node3D) -> Dictionary:
	for _i in range(16):
		await process_frame
		var manager := get_root().get_node_or_null(MANAGER_NODE_NAME)
		if manager == null or not manager.has_method("get_debug_instance_entry"):
			continue
		var snapshot: Dictionary = manager.get_debug_instance_entry(splat)
		if not snapshot.is_empty():
			return snapshot
	return {}

func _transform_equal_approx(a: Transform3D, b: Transform3D) -> bool:
	return _basis_equal_approx(a.basis, b.basis) and a.origin.is_equal_approx(b.origin)

func _basis_equal_approx(a: Basis, b: Basis) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z)

func _fail(message: String) -> void:
	printerr("[gdgs-validate] FAIL %s" % message)
	quit(1)
