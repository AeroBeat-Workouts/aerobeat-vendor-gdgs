extends SceneTree

const SCENE_PATH := "res://scenes/gdgs_happy_path_control.tscn"
const SAMPLE_ASSET_PATHS := [
	"res://assets/splats/demo.compressed.ply",
	"res://assets/splats/demo.ply",
	"res://assets/splats/demo.sog",
]
const DEFAULT_SOURCE_PATH := "res://assets/splats/demo.compressed.ply"
const COMPOSITOR_EFFECT_SCRIPT_PATH := "res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd"
const GAUSSIAN_SPLAT_NODE_SCRIPT_PATH := "res://addons/gdgs/runtime/nodes/gaussian_splat_node.gd"
const HARNESS_SCRIPT_PATH := "res://scripts/gdgs_tweak_matrix_harness.gd"
const RUNTIME_LOADER_SCRIPT_PATH := "res://scripts/gdgs_runtime_splat_loader.gd"

func _initialize() -> void:
	var sample := _load_sample_resource()
	if sample == null:
		printerr("Failed to load any imported GDGS sample resource from: %s" % [str(SAMPLE_ASSET_PATHS)])
		quit(1)
		return

	var root := Node3D.new()
	root.name = "GdgsHappyPathControl"
	root.set_script(load(HARNESS_SCRIPT_PATH))

	var gaussian_splat_node_script := load(GAUSSIAN_SPLAT_NODE_SCRIPT_PATH)
	if gaussian_splat_node_script == null:
		printerr("Failed to load GaussianSplatNode script: %s" % GAUSSIAN_SPLAT_NODE_SCRIPT_PATH)
		quit(1)
		return

	var splat_anchor := Node3D.new()
	splat_anchor.name = "SplatAnchor"
	root.add_child(splat_anchor)
	splat_anchor.owner = root

	var gaussian_splat_node: Node = gaussian_splat_node_script.new()
	gaussian_splat_node.name = "GaussianSplatNode"
	gaussian_splat_node.gaussian = sample
	splat_anchor.add_child(gaussian_splat_node)
	gaussian_splat_node.owner = root

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.04, 0.06, 1.0)
	world_environment.environment = environment
	var compositor := Compositor.new()
	var effect := CompositorEffect.new()
	effect.set_script(load(COMPOSITOR_EFFECT_SCRIPT_PATH))
	compositor.compositor_effects = [effect]
	world_environment.compositor = compositor
	root.add_child(world_environment)
	world_environment.owner = root

	var camera_rig := Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.position = Vector3(0.0, 0.0, 4.0)
	root.add_child(camera_rig)
	camera_rig.owner = root

	var camera_pitch := Node3D.new()
	camera_pitch.name = "CameraPitch"
	camera_rig.add_child(camera_pitch)
	camera_pitch.owner = root

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.near = 0.05
	camera.far = 100.0
	camera_pitch.add_child(camera)
	camera.owner = root

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	root.add_child(sun)
	sun.owner = root

	var runtime_loader := Node.new()
	runtime_loader.name = "RuntimeSplatLoader"
	runtime_loader.set_script(load(RUNTIME_LOADER_SCRIPT_PATH))
	root.add_child(runtime_loader)
	runtime_loader.owner = root

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "CanvasLayer"
	root.add_child(canvas_layer)
	canvas_layer.owner = root

	var margin := MarginContainer.new()
	margin.name = "HudMargin"
	margin.offset_left = 16.0
	margin.offset_top = 16.0
	margin.offset_right = 900.0
	margin.offset_bottom = 700.0
	canvas_layer.add_child(margin)
	margin.owner = root

	var panel := PanelContainer.new()
	panel.name = "HudPanel"
	margin.add_child(panel)
	panel.owner = root

	var hud_vbox := VBoxContainer.new()
	hud_vbox.name = "HudVBox"
	panel.add_child(hud_vbox)
	hud_vbox.owner = root

	var info := RichTextLabel.new()
	info.name = "HudLabel"
	info.fit_content = true
	info.scroll_active = false
	info.bbcode_enabled = true
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size = Vector2(700.0, 0.0)
	info.text = "[b]GDGS render-path tweak harness[/b]\nLoaded source: %s" % DEFAULT_SOURCE_PATH
	hud_vbox.add_child(info)
	info.owner = root

	var separator := HSeparator.new()
	separator.name = "HudSeparator"
	hud_vbox.add_child(separator)
	separator.owner = root

	var loader_controls := VBoxContainer.new()
	loader_controls.name = "LoaderControls"
	hud_vbox.add_child(loader_controls)
	loader_controls.owner = root

	var source_row := HBoxContainer.new()
	source_row.name = "SourceRow"
	loader_controls.add_child(source_row)
	source_row.owner = root

	var source_line_edit := LineEdit.new()
	source_line_edit.name = "SourceLineEdit"
	source_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_line_edit.placeholder_text = "res://assets/splats/demo.compressed.ply | /absolute/path/file.ply | https://example.com/file.sog"
	source_line_edit.text = DEFAULT_SOURCE_PATH
	source_row.add_child(source_line_edit)
	source_line_edit.owner = root

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	loader_controls.add_child(action_row)
	action_row.owner = root

	var browse_button := Button.new()
	browse_button.name = "BrowseButton"
	browse_button.text = "Browse…"
	action_row.add_child(browse_button)
	browse_button.owner = root

	var load_button := Button.new()
	load_button.name = "LoadButton"
	load_button.text = "Load"
	action_row.add_child(load_button)
	load_button.owner = root

	var unload_button := Button.new()
	unload_button.name = "UnloadButton"
	unload_button.text = "Unload"
	action_row.add_child(unload_button)
	unload_button.owner = root

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Ready."
	loader_controls.add_child(status_label)
	status_label.owner = root

	var browse_dialog := FileDialog.new()
	browse_dialog.name = "BrowseDialog"
	browse_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	browse_dialog.access = FileDialog.ACCESS_FILESYSTEM
	browse_dialog.title = "Choose a Gaussian Splat file"
	browse_dialog.filters = PackedStringArray([
		"*.ply ; Binary PLY",
		"*.splat ; Legacy SPLAT",
		"*.sog ; SOG archive"
	])
	canvas_layer.add_child(browse_dialog)
	browse_dialog.owner = root

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		printerr("Failed to pack scene: %s" % error_string(pack_error))
		quit(1)
		return

	var save_error := ResourceSaver.save(packed, SCENE_PATH)
	if save_error != OK:
		printerr("Failed to save scene %s: %s" % [SCENE_PATH, error_string(save_error)])
		quit(1)
		return

	root.free()
	sample = null
	packed = null
	print("Saved %s" % SCENE_PATH)
	quit(0)

func _load_sample_resource() -> Resource:
	for path in SAMPLE_ASSET_PATHS:
		var resource := load(path)
		if resource != null:
			return resource
	return null
