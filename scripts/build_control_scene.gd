extends SceneTree

const SCENE_PATH := "res://scenes/gdgs_happy_path_control.tscn"
const SAMPLE_ASSET_PATHS := [
	"res://samples/assets/demo.compressed.ply",
	"res://samples/assets/demo.ply",
	"res://samples/assets/demo.sog",
]
const COMPOSITOR_EFFECT_SCRIPT_PATH := "res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd"
const GAUSSIAN_SPLAT_NODE_SCRIPT_PATH := "res://addons/gdgs/runtime/nodes/gaussian_splat_node.gd"

func _initialize() -> void:
	var sample := _load_sample_resource()
	if sample == null:
		printerr("Failed to load any imported GDGS sample resource from: %s" % [str(SAMPLE_ASSET_PATHS)])
		quit(1)
		return

	var root := Node3D.new()
	root.name = "GdgsHappyPathControl"

	var gaussian_splat_node_script := load(GAUSSIAN_SPLAT_NODE_SCRIPT_PATH)
	if gaussian_splat_node_script == null:
		printerr("Failed to load GaussianSplatNode script: %s" % GAUSSIAN_SPLAT_NODE_SCRIPT_PATH)
		quit(1)
		return
	var gaussian_splat_node: Node = gaussian_splat_node_script.new()
	gaussian_splat_node.name = "GaussianSplatNode"
	gaussian_splat_node.gaussian = sample
	root.add_child(gaussian_splat_node)
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

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 0.0, 4.0)
	camera.near = 0.05
	camera.far = 100.0
	root.add_child(camera)
	camera.owner = root

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	root.add_child(sun)
	sun.owner = root

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "CanvasLayer"
	root.add_child(canvas_layer)
	canvas_layer.owner = root

	var margin := MarginContainer.new()
	margin.name = "HudMargin"
	margin.offset_left = 16.0
	margin.offset_top = 16.0
	margin.offset_right = 520.0
	margin.offset_bottom = 220.0
	canvas_layer.add_child(margin)
	margin.owner = root

	var info := RichTextLabel.new()
	info.name = "HudLabel"
	info.fit_content = true
	info.scroll_active = false
	info.bbcode_enabled = true
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "[b]GDGS vendor happy-path control[/b]\nSample: res://samples/assets/demo.compressed.ply\nREADME shape: GaussianSplatNode + WorldEnvironment + Compositor + gdgs CompositorEffect\nRenderer requirement: Forward Plus + desktop GPU compute support."
	margin.add_child(info)
	info.owner = root

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
