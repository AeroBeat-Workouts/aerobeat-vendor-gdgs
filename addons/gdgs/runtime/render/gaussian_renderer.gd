@tool
extends RefCounted
class_name GaussianRenderer

const RenderingDeviceContext := preload("res://addons/gdgs/runtime/render/gaussian_rendering_device_context.gd")
const RADIX := 256
const MAX_SORT_ELEMENTS_PER_SPLAT := 10

enum RasterDebugStage {
	FULL_PIPELINE,
	PREPARED_NO_DISPATCH,
	PROJECTION_ONLY,
	RADIX_ONLY,
	BOUNDARIES_ONLY,
	RENDER_ONLY
}

var _once_logs := {}

func render_for_compositor(
	state_cache: GaussianGpuStateCache,
	scene_registry: GaussianSceneRegistry,
	texture_size: Vector2i,
	camera_transform: Transform3D,
	camera_projection: Projection,
	camera_world_position: Vector3,
	depth_capture_alpha: float = 0.5,
	debug_raster_stage: int = RasterDebugStage.FULL_PIPELINE
) -> Dictionary:
	state_cache.flush_pending_cleanup()

	if not scene_registry.has_gpu_data():
		if state_cache.has_render_states():
			state_cache.cleanup_all()
		return {}

	var point_count := scene_registry.get_point_count()
	var safe_size := Vector2i(maxi(texture_size.x, 1), maxi(texture_size.y, 1))
	var state = state_cache.get_or_create_render_state(safe_size)
	_update_camera_from_transform(state, camera_transform, camera_projection)
	state.camera_world_position = camera_world_position
	state.depth_capture_alpha = clampf(depth_capture_alpha, 0.0, 1.0)

	var unique_data_size := scene_registry.get_point_data_byte().size()

	if state.context == null or state.needs_gpu_rebuild:
		state_cache.rebuild_gpu_state(state, point_count, unique_data_size, scene_registry.get_instance_count())
	if state.context == null:
		return {}

	if state.needs_splat_upload:
		state_cache.upload_splats(state, scene_registry.get_point_data_byte(), scene_registry.get_splat_instance_ids_byte())
	if state.needs_instance_upload:
		state_cache.upload_instance_transforms(state, scene_registry.get_instance_transforms_byte())

	if state.camera_push_constants.is_empty():
		return {}

	_log_once(
		"rd_seam_correction",
		"[gdgs] seam correction compositor_path_uses_global_rd=%s raster_path_uses_global_rd=%s local_device_submit_sync_exercised=%s" % [
			str(RenderingServer.get_rendering_device() != null),
			str(state.context.device == RenderingServer.get_rendering_device()),
			"false"
		]
	)
	_log_once(
		"direct_dispatch_isolation",
		"[gdgs] renderer using direct dispatch isolation for radix/boundary passes"
	)
	_log_once(
		"raster_stage_gate",
		"[gdgs] renderer raster stage gate=%s" % _raster_stage_name(debug_raster_stage)
	)

	_rasterize_state(state, point_count, debug_raster_stage)
	if state.descriptors.has("render_texture") and state.descriptors.has("depth_texture"):
		var color_texture: RID = state.descriptors["render_texture"].rid
		var depth_texture: RID = state.descriptors["depth_texture"].rid
		_log_once(
			"render_targets_ready",
			"[gdgs] renderer prepared compositor textures color_valid=%s depth_valid=%s texture_size=%s point_count=%d" % [
				str(color_texture.is_valid()),
				str(depth_texture.is_valid()),
				str(state.texture_size),
				point_count
			]
		)
		return {
			"color_alpha_texture": color_texture,
			"depth_texture": depth_texture
		}
	return {}

func _rasterize_state(state, point_count: int, debug_raster_stage: int) -> void:
	if state.context == null:
		return

	var uniforms := RenderingDeviceContext.create_push_constant([
		state.camera_world_position.x,
		state.camera_world_position.y,
		state.camera_world_position.z,
		Time.get_ticks_msec() * 1e-3,
		state.texture_size.x,
		state.texture_size.y,
		point_count,
		0
	])
	state.context.device.buffer_update(state.descriptors["uniforms"].rid, 0, 8 * 4, uniforms)
	state.context.device.buffer_clear(state.descriptors["histogram"].rid, 0, 4 + 4 * RADIX * 4)
	state.context.device.buffer_clear(state.descriptors["tile_bounds"].rid, 0, state.tile_dims.x * state.tile_dims.y * 2 * 4)
	_log_stage("prepared", state, point_count, {"raster_stage_gate": _raster_stage_name(debug_raster_stage)})

	if debug_raster_stage == RasterDebugStage.PREPARED_NO_DISPATCH:
		_log_stage("prepared_no_dispatch_gate", state, point_count)
		return

	var compute_list: int = state.context.compute_list_begin()
	_log_stage("projection_begin", state, point_count)
	state.pipelines["gsplat_projection"].call(state.context, compute_list, state.camera_push_constants)
	_log_stage("projection_end", state, point_count, {"push_constant_bytes": state.camera_push_constants.size()})
	state.context.compute_list_end()

	if debug_raster_stage == RasterDebugStage.PROJECTION_ONLY:
		_log_stage("projection_only_gate", state, point_count)
		return

	compute_list = state.context.compute_list_begin()
	for radix_shift_pass in range(4):
		var radix_input_offset := point_count * MAX_SORT_ELEMENTS_PER_SPLAT * (radix_shift_pass % 2)
		var radix_output_offset := point_count * MAX_SORT_ELEMENTS_PER_SPLAT * (1 - (radix_shift_pass % 2))
		_log_stage(
			"radix_pass_begin",
			state,
			point_count,
			{
				"pass": radix_shift_pass,
				"radix_input_offset": radix_input_offset,
				"radix_output_offset": radix_output_offset
			}
		)
		state.pipelines["radix_sort_upsweep"].call(
			state.context,
			compute_list,
			RenderingDeviceContext.create_exact_push_constant([
				radix_shift_pass,
				radix_input_offset
			])
		)
		state.pipelines["radix_sort_spine"].call(
			state.context,
			compute_list,
			RenderingDeviceContext.create_exact_push_constant([radix_shift_pass])
		)
		state.pipelines["radix_sort_downsweep"].call(
			state.context,
			compute_list,
			RenderingDeviceContext.create_exact_push_constant([
				radix_shift_pass,
				radix_input_offset,
				radix_output_offset
			])
		)
		_log_stage(
			"radix_pass_end",
			state,
			point_count,
			{
				"pass": radix_shift_pass,
				"radix_input_offset": radix_input_offset,
				"radix_output_offset": radix_output_offset
			}
		)
	state.context.compute_list_end()

	if debug_raster_stage == RasterDebugStage.RADIX_ONLY:
		_log_stage("radix_only_gate", state, point_count)
		return

	compute_list = state.context.compute_list_begin()
	_log_stage("boundaries_begin", state, point_count, {"tile_dims": str(state.tile_dims)})
	state.pipelines["gsplat_boundaries"].call(state.context, compute_list, PackedByteArray())
	_log_stage("boundaries_end", state, point_count, {"tile_dims": str(state.tile_dims)})
	state.context.compute_list_end()

	if debug_raster_stage == RasterDebugStage.BOUNDARIES_ONLY:
		_log_stage("boundaries_only_gate", state, point_count)
		return

	compute_list = state.context.compute_list_begin()
	var render_push_constant := RenderingDeviceContext.create_push_constant([0.0, -1, state.depth_capture_alpha, 0.0])
	_log_stage("render_begin", state, point_count, {"push_constant_bytes": render_push_constant.size()})
	state.pipelines["gsplat_render"].call(
		state.context,
		compute_list,
		render_push_constant
	)
	_log_stage("render_end", state, point_count, {"push_constant_bytes": render_push_constant.size()})
	state.context.compute_list_end()

	if debug_raster_stage == RasterDebugStage.RENDER_ONLY:
		_log_stage("render_only_gate", state, point_count)
		return

	_log_stage("rasterize_state_return", state, point_count)

func _update_camera_from_transform(state, camera_transform: Transform3D, camera_projection: Projection) -> void:
	var view := Projection(camera_transform.affine_inverse())
	if view != state.camera_view or camera_projection != state.camera_projection:
		state.camera_view = view
		state.camera_projection = camera_projection
		state.camera_push_constants = RenderingDeviceContext.create_push_constant(
			_projection_to_column_major_floats(view) + _projection_to_column_major_floats(camera_projection)
		)

func _projection_to_column_major_floats(matrix: Projection) -> Array:
	return [
		matrix.x[0], matrix.x[1], matrix.x[2], matrix.x[3],
		matrix.y[0], matrix.y[1], matrix.y[2], matrix.y[3],
		matrix.z[0], matrix.z[1], matrix.z[2], matrix.z[3],
		matrix.w[0], matrix.w[1], matrix.w[2], matrix.w[3]
	]

func _log_once(key: String, message: String) -> void:
	if _once_logs.get(key, false):
		return
	_once_logs[key] = true
	print(message)

func _log_stage(stage: String, state, point_count: int, extras: Dictionary = {}) -> void:
	var details := [
		"[gdgs] renderer stage=%s" % stage,
		"point_count=%d" % point_count,
		"texture_size=%s" % str(state.texture_size),
		"tile_dims=%s" % str(state.tile_dims)
	]
	for key in extras.keys():
		details.append("%s=%s" % [str(key), str(extras[key])])
	print(" ".join(details))

func _raster_stage_name(value: int) -> String:
	match value:
		RasterDebugStage.FULL_PIPELINE:
			return "full_pipeline"
		RasterDebugStage.PREPARED_NO_DISPATCH:
			return "prepared_no_dispatch"
		RasterDebugStage.PROJECTION_ONLY:
			return "projection_only"
		RasterDebugStage.RADIX_ONLY:
			return "radix_only"
		RasterDebugStage.BOUNDARIES_ONLY:
			return "boundaries_only"
		RasterDebugStage.RENDER_ONLY:
			return "render_only"
		_:
			return "unknown(%d)" % value
