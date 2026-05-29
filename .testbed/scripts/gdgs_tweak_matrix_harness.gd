extends Node3D

const DISPLAY_MODE_NAMES := [
	"Compositor",
	"Direct Texture (World Overlay)",
	"Direct Texture (Canvas Overlay)",
	"No Present"
]

const DEBUG_VIEW_NAMES := [
	"Composite",
	"GS Alpha",
	"GS Color",
	"GS Depth",
	"Scene Depth",
	"Depth Reject Mask"
]

const POSITION_PRESETS := [
	{
		"name": "Origin",
		"value": Vector3(0.0, 0.0, 0.0)
	},
	{
		"name": "Stage Right",
		"value": Vector3(1.25, 0.5, 0.0)
	},
	{
		"name": "Stage Left / Back",
		"value": Vector3(-1.5, 0.25, -1.0)
	}
]

const ROTATION_PRESETS := [
	{
		"name": "Neutral",
		"value": Vector3(0.0, 0.0, 0.0)
	},
	{
		"name": "Yaw 45 Pitch -15",
		"value": Vector3(-15.0, 45.0, 0.0)
	},
	{
		"name": "Roll 30",
		"value": Vector3(0.0, 0.0, 30.0)
	}
]

const SCALE_PRESETS := [
	{
		"name": "1x",
		"value": Vector3(1.0, 1.0, 1.0)
	},
	{
		"name": "Uniform 0.75x",
		"value": Vector3(0.75, 0.75, 0.75)
	},
	{
		"name": "Non-uniform",
		"value": Vector3(1.35, 0.8, 1.1)
	}
]

const MANAGER_NODE_NAME := "_GdgsGaussianRenderManager"

var _position_preset_index := 0
var _rotation_preset_index := 0
var _scale_preset_index := 0

@onready var _splat_anchor := $SplatAnchor as Node3D
@onready var _splat_node := $SplatAnchor/GaussianSplatNode as Node3D
@onready var _world_environment := $WorldEnvironment as WorldEnvironment
@onready var _hud_label := $CanvasLayer/HudMargin/HudLabel as RichTextLabel

func _ready() -> void:
	_sync_transform_preset_indices()
	_update_hud()
	print("[gdgs-harness] Controls: C toggle compositor effect, M cycle display mode, D cycle debug view, I toggle composite depth bypass, P cycle parent position preset, R cycle parent rotation preset, S cycle parent scale preset, V print transform verification snapshot")
	call_deferred("_refresh_registry_snapshot_after_registration")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_C:
			var effect := _get_effect()
			if effect == null:
				return
			effect.enabled = not effect.enabled
			print("[gdgs-harness] effect.enabled=%s" % effect.enabled)
			_update_hud()
		KEY_M:
			var effect := _get_effect()
			if effect == null:
				return
			effect.display_mode = (int(effect.display_mode) + 1) % DISPLAY_MODE_NAMES.size()
			print("[gdgs-harness] display_mode=%s" % _display_mode_name(int(effect.display_mode)))
			_update_hud()
		KEY_D:
			var effect := _get_effect()
			if effect == null:
				return
			effect.debug_view = (int(effect.debug_view) + 1) % DEBUG_VIEW_NAMES.size()
			print("[gdgs-harness] debug_view=%s" % _debug_view_name(int(effect.debug_view)))
			_update_hud()
		KEY_I:
			var effect := _get_effect()
			if effect == null:
				return
			effect.ignore_scene_depth_in_composite = not bool(effect.ignore_scene_depth_in_composite)
			print("[gdgs-harness] ignore_scene_depth_in_composite=%s" % effect.ignore_scene_depth_in_composite)
			_update_hud()
		KEY_P:
			_cycle_position_preset()
		KEY_R:
			_cycle_rotation_preset()
		KEY_S:
			_cycle_scale_preset()
		KEY_V:
			_print_transform_snapshot()

func _cycle_position_preset() -> void:
	_position_preset_index = (_position_preset_index + 1) % POSITION_PRESETS.size()
	_apply_anchor_transform_presets("position")

func _cycle_rotation_preset() -> void:
	_rotation_preset_index = (_rotation_preset_index + 1) % ROTATION_PRESETS.size()
	_apply_anchor_transform_presets("rotation")

func _cycle_scale_preset() -> void:
	_scale_preset_index = (_scale_preset_index + 1) % SCALE_PRESETS.size()
	_apply_anchor_transform_presets("scale")

func _apply_anchor_transform_presets(changed_dimension: String) -> void:
	if _splat_anchor == null:
		return
	_splat_anchor.position = _position_preset()["value"]
	_splat_anchor.rotation_degrees = _rotation_preset()["value"]
	_splat_anchor.scale = _scale_preset()["value"]
	print("[gdgs-harness] anchor %s preset => position=%s rotation_degrees=%s scale=%s" % [
		changed_dimension,
		_var_to_pretty(_splat_anchor.position),
		_var_to_pretty(_splat_anchor.rotation_degrees),
		_var_to_pretty(_splat_anchor.scale)
	])
	_update_hud()
	call_deferred("_print_transform_snapshot")

func _position_preset() -> Dictionary:
	return POSITION_PRESETS[_position_preset_index]

func _rotation_preset() -> Dictionary:
	return ROTATION_PRESETS[_rotation_preset_index]

func _scale_preset() -> Dictionary:
	return SCALE_PRESETS[_scale_preset_index]

func _sync_transform_preset_indices() -> void:
	if _splat_anchor == null:
		return
	_position_preset_index = _find_vector3_preset_index(POSITION_PRESETS, _splat_anchor.position)
	_rotation_preset_index = _find_vector3_preset_index(ROTATION_PRESETS, _splat_anchor.rotation_degrees)
	_scale_preset_index = _find_vector3_preset_index(SCALE_PRESETS, _splat_anchor.scale)

func _find_vector3_preset_index(presets: Array, target: Vector3) -> int:
	for i in range(presets.size()):
		var preset: Dictionary = presets[i]
		if (preset["value"] as Vector3).is_equal_approx(target):
			return i
	return 0

func _get_effect() -> CompositorEffect:
	if _world_environment == null or _world_environment.compositor == null:
		return null
	var effects := _world_environment.compositor.compositor_effects
	if effects.is_empty():
		return null
	return effects[0]

func _update_hud() -> void:
	if _hud_label == null:
		return

	var effect := _get_effect()
	if effect == null:
		_hud_label.text = "[b]GDGS tweak matrix harness[/b]\nCompositor effect not found."
		return

	var anchor_state := "unavailable"
	var global_state := "unavailable"
	var registry_state := "pending manager registration"
	if _splat_anchor != null:
		anchor_state = "preset=%s / %s / %s\n  position=%s\n  rotation_degrees=%s\n  scale=%s" % [
			_position_preset()["name"],
			_rotation_preset()["name"],
			_scale_preset()["name"],
			_var_to_pretty(_splat_anchor.position),
			_var_to_pretty(_splat_anchor.rotation_degrees),
			_var_to_pretty(_splat_anchor.scale)
		]
	if _splat_node != null:
		global_state = "origin=%s\n  basis=%s" % [
			_var_to_pretty(_splat_node.global_transform.origin),
			_var_to_pretty(_splat_node.global_transform.basis)
		]
		registry_state = _format_registry_state(_get_registry_snapshot_for_splat())

	_hud_label.text = "[b]GDGS render-path tweak harness[/b]\nSample: res://samples/assets/demo.compressed.ply\n\nControls\n- [b]C[/b]: toggle compositor effect enabled\n- [b]M[/b]: cycle display_mode\n- [b]D[/b]: cycle debug_view\n- [b]I[/b]: toggle ignore_scene_depth_in_composite\n- [b]P[/b]: cycle parent [i]position[/i] preset\n- [b]R[/b]: cycle parent [i]rotation[/i] preset\n- [b]S[/b]: cycle parent [i]scale[/i] preset\n- [b]V[/b]: print transform verification snapshot\n\nDisplay modes\n- Compositor\n- Direct Texture (World Overlay)\n- Direct Texture (Canvas Overlay)\n- No Present\n\nCurrent\n- effect enabled: %s\n- display_mode: %s\n- debug_view: %s\n- ignore scene depth in composite: %s\n\nParent anchor\n- %s\n\nSplat global transform\n- %s\n\nRegistry upload snapshot\n- %s" % [
		str(effect.enabled),
		_display_mode_name(int(effect.display_mode)),
		_debug_view_name(int(effect.debug_view)),
		str(bool(effect.ignore_scene_depth_in_composite)),
		anchor_state,
		global_state,
		registry_state
	]

func _get_registry_snapshot_for_splat() -> Dictionary:
	if _splat_node == null:
		return {}
	var manager := _get_manager()
	if manager == null or not manager.has_method("get_debug_instance_entry"):
		return {}
	return manager.get_debug_instance_entry(_splat_node)

func _format_registry_state(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return "pending manager registration"
	var model_transform: Transform3D = snapshot.get("model_transform", Transform3D.IDENTITY)
	return "instance_index=%s visible=%s point_count=%s\n  origin=%s\n  basis=%s" % [
		str(snapshot.get("instance_index", -1)),
		str(snapshot.get("visible", false)),
		str(snapshot.get("point_count", 0)),
		_var_to_pretty(model_transform.origin),
		_var_to_pretty(model_transform.basis)
	]

func _print_transform_snapshot() -> void:
	if _splat_anchor == null or _splat_node == null:
		return
	var snapshot := _get_registry_snapshot_for_splat()
	print("[gdgs-harness] transform snapshot => anchor(position=%s, rotation_degrees=%s, scale=%s) splat_global(origin=%s, basis=%s) registry=%s" % [
		_var_to_pretty(_splat_anchor.position),
		_var_to_pretty(_splat_anchor.rotation_degrees),
		_var_to_pretty(_splat_anchor.scale),
		_var_to_pretty(_splat_node.global_transform.origin),
		_var_to_pretty(_splat_node.global_transform.basis),
		_var_to_pretty(snapshot)
	])
	_update_hud()

func _refresh_registry_snapshot_after_registration() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	await tree.process_frame
	_print_transform_snapshot()

func _get_manager() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(MANAGER_NODE_NAME)

func _display_mode_name(value: int) -> String:
	if value >= 0 and value < DISPLAY_MODE_NAMES.size():
		return DISPLAY_MODE_NAMES[value]
	return "Unknown(%d)" % value

func _debug_view_name(value: int) -> String:
	if value >= 0 and value < DEBUG_VIEW_NAMES.size():
		return DEBUG_VIEW_NAMES[value]
	return "Unknown(%d)" % value

func _var_to_pretty(value: Variant) -> String:
	return var_to_str(value)
