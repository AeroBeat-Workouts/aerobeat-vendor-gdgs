extends Node3D

const DISPLAY_MODE_NAMES := [
	"Compositor",
	"Direct Texture"
]

const DEBUG_VIEW_NAMES := [
	"Composite",
	"GS Alpha",
	"GS Color",
	"GS Depth",
	"Scene Depth",
	"Depth Reject Mask"
]

@onready var _world_environment := $WorldEnvironment as WorldEnvironment
@onready var _hud_label := $CanvasLayer/HudMargin/HudLabel as RichTextLabel

func _ready() -> void:
	_update_hud()
	print("[gdgs-harness] Controls: C toggle compositor effect, M cycle display mode, D cycle debug view, I toggle composite depth bypass")

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

	_hud_label.text = "[b]GDGS render-path tweak harness[/b]\nSample: res://samples/assets/demo.compressed.ply\n\nControls\n- [b]C[/b]: toggle compositor effect enabled\n- [b]M[/b]: cycle display_mode\n- [b]D[/b]: cycle debug_view\n- [b]I[/b]: toggle ignore_scene_depth_in_composite\n\nCurrent\n- effect enabled: %s\n- display_mode: %s\n- debug_view: %s\n- ignore scene depth in composite: %s" % [
		str(effect.enabled),
		_display_mode_name(int(effect.display_mode)),
		_debug_view_name(int(effect.debug_view)),
		str(bool(effect.ignore_scene_depth_in_composite))
	]

func _display_mode_name(value: int) -> String:
	if value >= 0 and value < DISPLAY_MODE_NAMES.size():
		return DISPLAY_MODE_NAMES[value]
	return "Unknown(%d)" % value

func _debug_view_name(value: int) -> String:
	if value >= 0 and value < DEBUG_VIEW_NAMES.size():
		return DEBUG_VIEW_NAMES[value]
	return "Unknown(%d)" % value
