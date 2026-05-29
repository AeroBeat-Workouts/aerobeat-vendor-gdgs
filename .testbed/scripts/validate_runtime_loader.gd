extends SceneTree

const SCENE_PATH := "res://scenes/gdgs_happy_path_control.tscn"
const IN_PROJECT_SOURCE := "res://assets/splats/demo.compressed.ply"
const EXTERNAL_COPY_DIR := "user://gdgs-validation"
const EXTERNAL_COPY_PATH := "user://gdgs-validation/external-demo.compressed.ply"

var _progress_events: Array = []
var _finished_events: Array = []

func _initialize() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		_fail("Failed to load scene: %s" % SCENE_PATH)
		return

	var root := scene.instantiate()
	get_root().add_child(root)

	await process_frame
	await process_frame

	var loader := root.get_node_or_null("RuntimeSplatLoader")
	var splat := root.get_node_or_null("SplatAnchor/GaussianSplatNode")
	var progress_bar := root.get_node_or_null("CanvasLayer/HudMargin/HudPanel/HudVBox/LoaderControls/LoadingProgressBar") as ProgressBar
	if loader == null:
		_fail("Scene is missing RuntimeSplatLoader")
		return
	if splat == null:
		_fail("Scene is missing persistent GaussianSplatNode")
		return
	if progress_bar == null:
		_fail("Scene is missing LoadingProgressBar")
		return

	if loader.has_signal("load_progressed"):
		loader.load_progressed.connect(_on_loader_progressed)
	if loader.has_signal("load_finished"):
		loader.load_finished.connect(_on_loader_finished)

	var in_project_result: Dictionary = await loader.load_from_source(IN_PROJECT_SOURCE)
	if not in_project_result.get("ok", false):
		_fail("In-project load failed: %s" % in_project_result.get("message", "Unknown error"))
		return
	if not await _assign_and_validate_resource(splat, in_project_result["resource"]):
		_fail("In-project load produced an invalid GaussianResource")
		return

	var external_prep_error := _prepare_external_copy()
	if external_prep_error != OK:
		_fail("Failed to prepare external validation copy: %s" % error_string(external_prep_error))
		return

	_progress_events.clear()
	_finished_events.clear()
	var external_result: Dictionary = await loader.load_from_source(ProjectSettings.globalize_path(EXTERNAL_COPY_PATH))
	if not external_result.get("ok", false):
		_fail("External-path load failed: %s" % external_result.get("message", "Unknown error"))
		return
	if not await _assign_and_validate_resource(splat, external_result["resource"]):
		_fail("External-path load produced an invalid GaussianResource")
		return
	if not _saw_async_progress(_progress_events):
		_fail("External-path async load did not emit determinate decode/build progress events")
		return
	if progress_bar.value < 99.0:
		_fail("LoadingProgressBar did not finish near 100%% after async load")
		return
	if progress_bar.indeterminate:
		_fail("LoadingProgressBar stayed indeterminate after async load completion")
		return
	if _finished_events.is_empty() or not bool((_finished_events.back() as Dictionary).get("ok", false)):
		_fail("RuntimeSplatLoader did not emit a successful load_finished event")
		return

	splat.set("gaussian", null)
	await process_frame
	if splat.get("gaussian") != null:
		_fail("Unload did not clear GaussianSplatNode.gaussian")
		return

	print("[gdgs-validate-loader] PASS in_project=%s external=%s async_progress_events=%d" % [
		String(in_project_result.get("resolved_source", IN_PROJECT_SOURCE)),
		String(external_result.get("resolved_source", ProjectSettings.globalize_path(EXTERNAL_COPY_PATH))),
		_progress_events.size()
	])
	quit(0)

func _prepare_external_copy() -> Error:
	var source_path := ProjectSettings.globalize_path(IN_PROJECT_SOURCE)
	if not FileAccess.file_exists(source_path):
		return ERR_FILE_NOT_FOUND
	var target_dir := ProjectSettings.globalize_path(EXTERNAL_COPY_DIR)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(target_dir)
	if make_dir_error != OK:
		return make_dir_error
	var copy_error := DirAccess.copy_absolute(source_path, ProjectSettings.globalize_path(EXTERNAL_COPY_PATH))
	if copy_error != OK:
		return copy_error
	return OK

func _assign_and_validate_resource(splat: Node, resource: Resource) -> bool:
	if resource == null:
		return false
	splat.set("gaussian", resource)
	await process_frame
	var assigned_resource: Resource = splat.get("gaussian")
	if assigned_resource == null:
		return false
	return int(assigned_resource.get("point_count")) > 0

func _saw_async_progress(progress_events: Array) -> bool:
	for event in progress_events:
		var status := event as Dictionary
		if not bool(status.get("progress_known", false)):
			continue
		var phase := String(status.get("phase", ""))
		var progress := float(status.get("progress", 0.0))
		if phase in ["decoding", "building"] and progress > 0.0 and progress < 1.0:
			return true
	return false

func _on_loader_progressed(status: Dictionary) -> void:
	_progress_events.append(status.duplicate(true))

func _on_loader_finished(result: Dictionary) -> void:
	_finished_events.append(result.duplicate(true))

func _fail(message: String) -> void:
	printerr("[gdgs-validate-loader] FAIL %s" % message)
	quit(1)
