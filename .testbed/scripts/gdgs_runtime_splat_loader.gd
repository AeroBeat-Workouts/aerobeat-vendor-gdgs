extends Node

signal load_started(status)
signal load_progressed(status)
signal load_finished(result)

const GaussianResourceScript = preload("res://addons/aerobeat-vendor-gdgs/runtime/resources/gaussian_resource.gd")
const GaussianResourceBuilder = preload("res://addons/aerobeat-vendor-gdgs/importers/builders/gaussian_resource_builder.gd")
const StandardPlyDecoder = preload("res://addons/aerobeat-vendor-gdgs/importers/decoders/standard_ply_decoder.gd")
const CompressedPlyDecoder = preload("res://addons/aerobeat-vendor-gdgs/importers/decoders/compressed_ply_decoder.gd")
const SplatDecoder = preload("res://addons/aerobeat-vendor-gdgs/importers/decoders/splat_decoder.gd")
const SogDecoder = preload("res://addons/aerobeat-vendor-gdgs/importers/decoders/sog_decoder.gd")
const BinaryPlyReader = preload("res://addons/aerobeat-vendor-gdgs/importers/parsers/binary_ply_reader.gd")
const BackgroundReadWorker = preload("res://scripts/gdgs_runtime_background_read_worker.gd")

const DOWNLOAD_CACHE_DIR := "user://gdgs-loader-cache"
const HTTP_OK_MIN := 200
const HTTP_OK_MAX := 299
const ASYNC_BATCH_SIZE := 4096
const STRUCT_SIZE := 60
const SH_FLOAT_COUNT := 48
const SH_C0 := 0.28209479177387814
const SQRT2 := 1.4142135623730951
const PHASE_IDLE := "idle"
const PHASE_DOWNLOADING := "downloading"
const PHASE_READING := "reading"
const PHASE_DECODING := "decoding"
const PHASE_BUILDING := "building"
const PHASE_READY := "ready"
const STATUS_IDLE := "Idle"
const STATUS_DOWNLOADING := "Downloading splat file"
const STATUS_READING := "Reading splat file"
const STATUS_READY := "Ready"

var _load_thread: Thread
var _read_worker: RefCounted
var _load_request: Dictionary = {}
var _load_status: Dictionary = {
	"pending": false,
	"progress": 0.0,
	"progress_known": false,
	"phase": PHASE_IDLE,
	"status": STATUS_IDLE
}
var _load_total_units: int = 0
var _load_completed_units: int = 0
var _http_request_completed := false
var _http_request_payload: Array = []

func load_from_source(source: String) -> Dictionary:
	if is_load_in_progress():
		return _error(ERR_BUSY, "A runtime splat load is already in progress")

	var normalized_source := _normalize_source(source)
	if normalized_source.is_empty():
		return _error(ERR_INVALID_PARAMETER, "Enter a res:// path, local file path, or web URL.")

	_load_request = {
		"source": normalized_source
	}
	_reset_load_progress()
	_set_load_status(PHASE_IDLE, "Preparing load", {
		"source": normalized_source,
		"pending": true,
		"progress": 0.0,
		"progress_known": false
	}, false)
	load_started.emit(_load_status.duplicate(true))

	var result: Dictionary
	if _is_web_url(normalized_source):
		result = await _load_from_url(normalized_source)
	else:
		result = await _load_from_path(normalized_source)

	return _finalize_load(result)

func is_load_in_progress() -> bool:
	return not _load_request.is_empty()

func get_load_status() -> Dictionary:
	return _load_status.duplicate(true)

func _exit_tree() -> void:
	if _load_thread != null:
		var thread := _load_thread
		_load_thread = null
		thread.wait_to_finish()
	_read_worker = null
	_load_request = {}
	_reset_load_progress()

func _load_from_url(url: String) -> Dictionary:
	var extension_hint := _supported_extension_for(url)
	if extension_hint.is_empty():
		return _error(ERR_FILE_UNRECOGNIZED, "URL must end with .ply, .compressed.ply, .splat, or .sog")

	var cache_dir_path := ProjectSettings.globalize_path(DOWNLOAD_CACHE_DIR)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(cache_dir_path)
	if make_dir_error != OK:
		return _error(make_dir_error, "Unable to prepare cache directory: %s" % DOWNLOAD_CACHE_DIR)

	var request := HTTPRequest.new()
	request.accept_gzip = true
	add_child(request)
	request.request_completed.connect(_on_http_request_completed, CONNECT_ONE_SHOT)

	_http_request_completed = false
	_http_request_payload.clear()
	_set_load_status(PHASE_DOWNLOADING, "%s …" % STATUS_DOWNLOADING, {
		"source": url,
		"progress": 0.0,
		"progress_known": false
	})

	var request_error := request.request(url)
	if request_error != OK:
		request.queue_free()
		return _error(request_error, "Unable to start download: %s" % url)

	while not _http_request_completed:
		var body_size := request.get_body_size()
		var downloaded_bytes := request.get_downloaded_bytes()
		if body_size > 0:
			_set_load_status(PHASE_DOWNLOADING, _download_status_text(downloaded_bytes, body_size), {
				"source": url,
				"progress": clampf(float(downloaded_bytes) / float(body_size), 0.0, 0.99),
				"progress_known": true,
				"downloaded_bytes": downloaded_bytes,
				"download_total_bytes": body_size
			})
		else:
			_set_load_status(PHASE_DOWNLOADING, "%s …" % STATUS_DOWNLOADING, {
				"source": url,
				"progress": 0.0,
				"progress_known": false,
				"downloaded_bytes": downloaded_bytes,
				"download_total_bytes": body_size
			})
		await get_tree().process_frame

	request.queue_free()

	if _http_request_payload.size() < 4:
		return _error(ERR_BUG, "Unexpected HTTP completion payload")

	var result_code := int(_http_request_payload[0])
	var response_code := int(_http_request_payload[1])
	var body: PackedByteArray = _http_request_payload[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _error(ERR_CANT_CONNECT, "Download failed for %s (result=%d, status=%d)" % [url, result_code, response_code])
	if response_code < HTTP_OK_MIN or response_code > HTTP_OK_MAX:
		return _error(ERR_CANT_OPEN, "Download returned HTTP %d for %s" % [response_code, url])

	var target_path := _download_cache_path_for(url)
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return _error(FileAccess.get_open_error(), "Unable to write download cache file: %s" % target_path)
	file.store_buffer(body)
	file = null

	return await _decode_file(target_path, url)

func _load_from_path(source: String) -> Dictionary:
	var normalized_path := _normalize_path(source)
	if normalized_path.begins_with("res://"):
		var imported_resource := load(normalized_path)
		if imported_resource != null and imported_resource.get_script() != null and imported_resource.has_method("get") and imported_resource.get("point_count") != null:
			_set_load_status(PHASE_READY, STATUS_READY, {
				"source": normalized_path,
				"resolved_source": normalized_path,
				"progress": 1.0,
				"progress_known": true
			})
			return {
				"ok": true,
				"resource": imported_resource,
				"resolved_source": normalized_path,
				"message": "Loaded imported GaussianResource from %s" % normalized_path
			}
		return await _decode_file(ProjectSettings.globalize_path(normalized_path), normalized_path)

	if normalized_path.begins_with("user://"):
		return await _decode_file(ProjectSettings.globalize_path(normalized_path), normalized_path)

	if not FileAccess.file_exists(normalized_path):
		return _error(ERR_FILE_NOT_FOUND, "File not found: %s" % normalized_path)
	return await _decode_file(normalized_path, normalized_path)

func _decode_file(local_path: String, display_source: String) -> Dictionary:
	if not FileAccess.file_exists(local_path):
		return _error(ERR_FILE_NOT_FOUND, "File not found: %s" % display_source)

	var detected_format := _detect_format(local_path)
	match detected_format:
		"ply", "compressed.ply":
			return await _decode_ply_file_async(local_path, display_source, detected_format)
		"splat", "sog":
			_set_load_status(PHASE_DECODING, "Decoding %s …" % detected_format, {
				"source": display_source,
				"resolved_source": display_source,
				"progress": 0.0,
				"progress_known": false
			})
			var decode_result := _decode_source(local_path)
			if not decode_result.get("ok", false):
				return _error(int(decode_result.get("error", ERR_INVALID_DATA)), decode_result.get("message", "Unable to decode gaussian splat"))
			_set_load_status(PHASE_BUILDING, "Building GaussianResource …", {
				"source": display_source,
				"resolved_source": display_source,
				"progress": 0.0,
				"progress_known": false
			})
			var build_result := GaussianResourceBuilder.build(decode_result["canonical"])
			if not build_result.get("ok", false):
				return _error(int(build_result.get("error", ERR_INVALID_DATA)), build_result.get("message", "Unable to build gaussian resource"))
			return {
				"ok": true,
				"resource": build_result["resource"],
				"resolved_source": display_source,
				"message": "Loaded %d gaussians from %s" % [int(build_result["resource"].get("point_count")), display_source]
			}
		_:
			return _error(ERR_FILE_UNRECOGNIZED, "Unsupported gaussian splat extension: %s" % local_path.get_extension())

func _decode_ply_file_async(local_path: String, display_source: String, format_hint: String) -> Dictionary:
	_set_load_status(PHASE_READING, STATUS_READING, {
		"source": display_source,
		"resolved_source": display_source,
		"progress": 0.0,
		"progress_known": true
	})

	var read_result := await _read_ply_in_thread(local_path, format_hint)
	if not read_result.get("ok", false):
		return _error(int(read_result.get("error", ERR_INVALID_DATA)), read_result.get("message", "Unable to read gaussian splat"))

	var detected_format := String(read_result.get("format", format_hint))
	if detected_format == "ply" and _is_compressed_ply(local_path, read_result.get("ply", {})):
		detected_format = "compressed.ply"
		read_result["format"] = detected_format

	var build_result: Dictionary
	match detected_format:
		"compressed.ply":
			build_result = await _decode_compressed_ply_async(read_result)
		"ply":
			build_result = await _decode_standard_ply_async(read_result)
		_:
			return _error(ERR_FILE_UNRECOGNIZED, "Unsupported gaussian splat extension: %s" % local_path.get_extension())

	if not build_result.get("ok", false):
		return _error(int(build_result.get("error", ERR_INVALID_DATA)), build_result.get("message", "Unable to build gaussian resource"))

	return {
		"ok": true,
		"resource": build_result["resource"],
		"resolved_source": display_source,
		"message": "Loaded %d gaussians from %s" % [int(build_result["resource"].point_count), display_source],
		"point_count": int(build_result["resource"].point_count),
		"aabb": build_result.get("aabb", AABB())
	}

func _read_ply_in_thread(local_path: String, format_hint: String) -> Dictionary:
	_read_worker = BackgroundReadWorker.new()
	var request := {
		"path": local_path,
		"format": format_hint
	}
	_load_thread = Thread.new()
	var start_error := _load_thread.start(Callable(_read_worker, "read_ply").bind(request))
	if start_error != OK:
		_load_thread = null
		_read_worker = null
		return _error(start_error, "Failed to start async splat read for %s" % local_path)

	while _load_thread != null and _load_thread.is_alive():
		await get_tree().process_frame

	if _load_thread == null:
		return _error(ERR_BUG, "Async splat read ended unexpectedly")

	var thread := _load_thread
	_load_thread = null
	var read_result = thread.wait_to_finish()
	_read_worker = null
	if read_result is not Dictionary:
		return _error(ERR_BUG, "Async splat read returned an unexpected payload")
	return read_result

func _decode_standard_ply_async(read_result: Dictionary) -> Dictionary:
	var ply: Dictionary = read_result.get("ply", {})
	var vertex := _get_element(ply, "vertex")
	if vertex.is_empty():
		return _error(ERR_INVALID_DATA, "PLY file does not contain a vertex element")

	var property_map: Dictionary = vertex.get("property_map", {})
	var required := [
		"x", "y", "z",
		"f_dc_0", "f_dc_1", "f_dc_2",
		"opacity",
		"scale_0", "scale_1",
		"rot_0", "rot_1", "rot_2", "rot_3"
	]
	for name in required:
		if not property_map.has(name):
			return _error(ERR_INVALID_DATA, "PLY file is missing required property '%s'" % name)

	var count := int(vertex.get("count", 0))
	_begin_load_progress(1 + count + count + count)
	_set_load_status(PHASE_DECODING, "Decoding vertices (0/%d)" % count)

	var stride := int(vertex.get("stride", 0))
	var data: PackedByteArray = vertex.get("data", PackedByteArray())
	var canonical := GaussianResourceBuilder.create_canonical(count)
	var positions: PackedVector3Array = canonical["positions"]
	var scales_linear: PackedVector3Array = canonical["scales_linear"]
	var rotations: Array = canonical["rotations"]
	var opacities: PackedFloat32Array = canonical["opacities"]
	var sh_coeffs: PackedFloat32Array = canonical["sh_coeffs"]
	var reported_vertices := 0

	for i in range(count):
		var base := i * stride
		positions[i] = Vector3(
			float(_read_property(data, base, property_map, "x", 0.0)),
			float(_read_property(data, base, property_map, "y", 0.0)),
			float(_read_property(data, base, property_map, "z", 0.0))
		)

		var scale_2 := float(_read_property(data, base, property_map, "scale_2", log(1e-6)))
		scales_linear[i] = Vector3(
			exp(float(_read_property(data, base, property_map, "scale_0", 0.0))),
			exp(float(_read_property(data, base, property_map, "scale_1", 0.0))),
			exp(scale_2)
		)

		rotations[i] = Quaternion(
			float(_read_property(data, base, property_map, "rot_1", 0.0)),
			float(_read_property(data, base, property_map, "rot_2", 0.0)),
			float(_read_property(data, base, property_map, "rot_3", 0.0)),
			float(_read_property(data, base, property_map, "rot_0", 1.0))
		).normalized()

		opacities[i] = _sigmoid(float(_read_property(data, base, property_map, "opacity", 0.0)))

		var sh_offset := i * SH_FLOAT_COUNT
		sh_coeffs[sh_offset + 0] = float(_read_property(data, base, property_map, "f_dc_0", 0.0))
		sh_coeffs[sh_offset + 1] = float(_read_property(data, base, property_map, "f_dc_1", 0.0))
		sh_coeffs[sh_offset + 2] = float(_read_property(data, base, property_map, "f_dc_2", 0.0))

		for coeff_idx in range(15):
			var coeff_offset := sh_offset + 3 + coeff_idx * 3
			sh_coeffs[coeff_offset + 0] = float(_read_property(data, base, property_map, "f_rest_%d" % coeff_idx, 0.0))
			sh_coeffs[coeff_offset + 1] = float(_read_property(data, base, property_map, "f_rest_%d" % (coeff_idx + 15), 0.0))
			sh_coeffs[coeff_offset + 2] = float(_read_property(data, base, property_map, "f_rest_%d" % (coeff_idx + 30), 0.0))

		if _should_yield(i, count):
			var processed_vertices := i + 1
			_advance_load_progress(processed_vertices - reported_vertices, PHASE_DECODING, "Decoding vertices (%d/%d)" % [processed_vertices, count])
			reported_vertices = processed_vertices
			await get_tree().process_frame

	return await _build_resource_async(read_result["path"], read_result["format"], canonical)

func _decode_compressed_ply_async(read_result: Dictionary) -> Dictionary:
	var ply: Dictionary = read_result.get("ply", {})
	var chunk_element := _get_element(ply, "chunk")
	var vertex_element := _get_element(ply, "vertex")
	if chunk_element.is_empty() or vertex_element.is_empty():
		return _error(ERR_INVALID_DATA, "Compressed PLY must contain 'chunk' and 'vertex' elements")

	var vertex_map: Dictionary = vertex_element.get("property_map", {})
	for property_name in ["packed_position", "packed_rotation", "packed_scale", "packed_color"]:
		if not vertex_map.has(property_name):
			return _error(ERR_INVALID_DATA, "Compressed PLY is missing '%s'" % property_name)

	var chunk_map: Dictionary = chunk_element.get("property_map", {})
	var chunk_required := [
		"min_x", "min_y", "min_z",
		"max_x", "max_y", "max_z",
		"min_scale_x", "min_scale_y", "min_scale_z",
		"max_scale_x", "max_scale_y", "max_scale_z",
		"min_r", "min_g", "min_b",
		"max_r", "max_g", "max_b"
	]
	for property_name in chunk_required:
		if not chunk_map.has(property_name):
			return _error(ERR_INVALID_DATA, "Compressed PLY chunk metadata is missing '%s'" % property_name)

	var count := int(vertex_element.get("count", 0))
	var chunk_count := int(chunk_element.get("count", 0))
	_begin_load_progress(1 + chunk_count + count + count + count)
	_set_load_status(PHASE_DECODING, "Decoding compressed chunks (0/%d)" % chunk_count)

	var expected_chunks := int(ceili(count / 256.0))
	if chunk_count < expected_chunks:
		return _error(ERR_INVALID_DATA, "Compressed PLY does not contain enough chunk records")

	var chunk_stride := int(chunk_element.get("stride", 0))
	var chunk_data: PackedByteArray = chunk_element.get("data", PackedByteArray())
	var chunks: Array = []
	chunks.resize(chunk_count)
	var reported_chunks := 0
	for i in range(chunks.size()):
		var base := i * chunk_stride
		chunks[i] = {
			"min_x": float(_read_required_property(chunk_data, base, chunk_map, "min_x")),
			"min_y": float(_read_required_property(chunk_data, base, chunk_map, "min_y")),
			"min_z": float(_read_required_property(chunk_data, base, chunk_map, "min_z")),
			"max_x": float(_read_required_property(chunk_data, base, chunk_map, "max_x")),
			"max_y": float(_read_required_property(chunk_data, base, chunk_map, "max_y")),
			"max_z": float(_read_required_property(chunk_data, base, chunk_map, "max_z")),
			"min_scale_x": float(_read_required_property(chunk_data, base, chunk_map, "min_scale_x")),
			"min_scale_y": float(_read_required_property(chunk_data, base, chunk_map, "min_scale_y")),
			"min_scale_z": float(_read_required_property(chunk_data, base, chunk_map, "min_scale_z")),
			"max_scale_x": float(_read_required_property(chunk_data, base, chunk_map, "max_scale_x")),
			"max_scale_y": float(_read_required_property(chunk_data, base, chunk_map, "max_scale_y")),
			"max_scale_z": float(_read_required_property(chunk_data, base, chunk_map, "max_scale_z")),
			"min_r": float(_read_required_property(chunk_data, base, chunk_map, "min_r")),
			"min_g": float(_read_required_property(chunk_data, base, chunk_map, "min_g")),
			"min_b": float(_read_required_property(chunk_data, base, chunk_map, "min_b")),
			"max_r": float(_read_required_property(chunk_data, base, chunk_map, "max_r")),
			"max_g": float(_read_required_property(chunk_data, base, chunk_map, "max_g")),
			"max_b": float(_read_required_property(chunk_data, base, chunk_map, "max_b"))
		}
		if _should_yield(i, chunks.size()):
			var processed_chunks := i + 1
			_advance_load_progress(processed_chunks - reported_chunks, PHASE_DECODING, "Decoding compressed chunks (%d/%d)" % [processed_chunks, chunk_count])
			reported_chunks = processed_chunks
			await get_tree().process_frame

	var sh_element := _get_element(ply, "sh")
	var sh_stride := 0
	var sh_coeffs_per_channel := 0
	var sh_data := PackedByteArray()
	if not sh_element.is_empty():
		var sh_map: Dictionary = sh_element.get("property_map", {})
		sh_coeffs_per_channel = int(sh_map.size() / 3)
		sh_stride = int(sh_element.get("stride", 0))
		sh_data = sh_element.get("data", PackedByteArray())
		if int(sh_element.get("count", 0)) != count:
			return _error(ERR_INVALID_DATA, "Compressed PLY SH element count does not match vertex count")
		if sh_coeffs_per_channel < 0 or sh_coeffs_per_channel > 15:
			return _error(ERR_INVALID_DATA, "Compressed PLY SH payload has an unsupported size")

	var canonical := GaussianResourceBuilder.create_canonical(count)
	var positions: PackedVector3Array = canonical["positions"]
	var scales_linear: PackedVector3Array = canonical["scales_linear"]
	var rotations: Array = canonical["rotations"]
	var opacities: PackedFloat32Array = canonical["opacities"]
	var sh_coeffs: PackedFloat32Array = canonical["sh_coeffs"]

	var vertex_stride := int(vertex_element.get("stride", 0))
	var vertex_data: PackedByteArray = vertex_element.get("data", PackedByteArray())
	var reported_vertices := 0
	_set_load_status(PHASE_DECODING, "Decoding vertices (0/%d)" % count)

	for i in range(count):
		var base := i * vertex_stride
		var chunk: Dictionary = chunks[int(i / 256)]

		var packed_position := int(_read_required_property(vertex_data, base, vertex_map, "packed_position"))
		var packed_rotation := int(_read_required_property(vertex_data, base, vertex_map, "packed_rotation"))
		var packed_scale := int(_read_required_property(vertex_data, base, vertex_map, "packed_scale"))
		var packed_color := int(_read_required_property(vertex_data, base, vertex_map, "packed_color"))

		var position_norm := _unpack_111011(packed_position)
		positions[i] = Vector3(
			_lerp_range(chunk["min_x"], chunk["max_x"], position_norm.x),
			_lerp_range(chunk["min_y"], chunk["max_y"], position_norm.y),
			_lerp_range(chunk["min_z"], chunk["max_z"], position_norm.z)
		)

		var log_scale_norm := _unpack_111011(packed_scale)
		scales_linear[i] = Vector3(
			exp(_lerp_range(chunk["min_scale_x"], chunk["max_scale_x"], log_scale_norm.x)),
			exp(_lerp_range(chunk["min_scale_y"], chunk["max_scale_y"], log_scale_norm.y)),
			exp(_lerp_range(chunk["min_scale_z"], chunk["max_scale_z"], log_scale_norm.z))
		)

		rotations[i] = _unpack_packed_rotation(packed_rotation)

		var packed_rgba := _unpack_8888(packed_color)
		var dc_r := _lerp_range(chunk["min_r"], chunk["max_r"], packed_rgba.x)
		var dc_g := _lerp_range(chunk["min_g"], chunk["max_g"], packed_rgba.y)
		var dc_b := _lerp_range(chunk["min_b"], chunk["max_b"], packed_rgba.z)

		var sh_offset := i * SH_FLOAT_COUNT
		sh_coeffs[sh_offset + 0] = (dc_r - 0.5) / SH_C0
		sh_coeffs[sh_offset + 1] = (dc_g - 0.5) / SH_C0
		sh_coeffs[sh_offset + 2] = (dc_b - 0.5) / SH_C0
		opacities[i] = packed_rgba.w

		if not sh_element.is_empty():
			var sh_base := i * sh_stride
			for coeff_idx in range(sh_coeffs_per_channel):
				var dst := sh_offset + 3 + coeff_idx * 3
				sh_coeffs[dst + 0] = _decode_quantized_sh(sh_data[sh_base + coeff_idx])
				sh_coeffs[dst + 1] = _decode_quantized_sh(sh_data[sh_base + coeff_idx + sh_coeffs_per_channel])
				sh_coeffs[dst + 2] = _decode_quantized_sh(sh_data[sh_base + coeff_idx + sh_coeffs_per_channel * 2])

		if _should_yield(i, count):
			var processed_vertices := i + 1
			_advance_load_progress(processed_vertices - reported_vertices, PHASE_DECODING, "Decoding vertices (%d/%d)" % [processed_vertices, count])
			reported_vertices = processed_vertices
			await get_tree().process_frame

	return await _build_resource_async(read_result["path"], read_result["format"], canonical)

func _build_resource_async(asset_path: String, format: String, canonical: Dictionary) -> Dictionary:
	var count := int(canonical.get("count", 0))
	var positions: PackedVector3Array = canonical.get("positions", PackedVector3Array())
	var scales_linear: PackedVector3Array = canonical.get("scales_linear", PackedVector3Array())
	var rotations: Array = canonical.get("rotations", [])
	var opacities: PackedFloat32Array = canonical.get("opacities", PackedFloat32Array())
	var sh_coeffs: PackedFloat32Array = canonical.get("sh_coeffs", PackedFloat32Array())

	if count < 0:
		return _error(ERR_INVALID_DATA, "Canonical gaussian count is invalid")
	if positions.size() != count or scales_linear.size() != count or rotations.size() != count or opacities.size() != count:
		return _error(ERR_INVALID_DATA, "Canonical gaussian arrays are inconsistent")
	if sh_coeffs.size() != count * SH_FLOAT_COUNT:
		return _error(ERR_INVALID_DATA, "Canonical SH coefficient buffer has an unexpected size")

	var center := Vector3.ZERO
	var reported_center := 0
	_set_load_status(PHASE_BUILDING, "Computing center (0/%d)" % count)
	if count > 0:
		for i in range(count):
			center += positions[i]
			if _should_yield(i, count):
				var processed_center := i + 1
				_advance_load_progress(processed_center - reported_center, PHASE_BUILDING, "Computing center (%d/%d)" % [processed_center, count])
				reported_center = processed_center
				await get_tree().process_frame
		center /= float(count)

	var points := PackedFloat32Array()
	points.resize(count * STRUCT_SIZE)
	var xyz := PackedVector3Array()
	xyz.resize(count)
	var aabb_min_v := Vector3(INF, INF, INF)
	var aabb_max_v := Vector3(-INF, -INF, -INF)
	var reported_points := 0
	_set_load_status(PHASE_BUILDING, "Packing resource data (0/%d)" % count)

	for i in range(count):
		var pos: Vector3 = positions[i] - center
		var scale_linear: Vector3 = scales_linear[i]
		var rotation_value = rotations[i]
		var rotation := Quaternion(0.0, 0.0, 0.0, 1.0)
		if rotation_value is Quaternion:
			rotation = rotation_value.normalized()

		scale_linear = Vector3(
			maxf(scale_linear.x, 1e-6),
			maxf(scale_linear.y, 1e-6),
			maxf(scale_linear.z, 1e-6)
		)

		xyz[i] = pos
		aabb_min_v = aabb_min_v.min(pos)
		aabb_max_v = aabb_max_v.max(pos)

		var base := i * STRUCT_SIZE
		points[base + 0] = pos.x
		points[base + 1] = pos.y
		points[base + 2] = pos.z
		points[base + 3] = 0.0

		var scale_mat := Basis.from_scale(scale_linear)
		var rot_mat := Basis(rotation).transposed()
		var cov_3d := (scale_mat * rot_mat).transposed() * (scale_mat * rot_mat)

		points[base + 4] = cov_3d.x[0]
		points[base + 5] = cov_3d.y[0]
		points[base + 6] = cov_3d.z[0]
		points[base + 7] = cov_3d.y[1]
		points[base + 8] = cov_3d.z[1]
		points[base + 9] = cov_3d.z[2]

		points[base + 10] = clampf(opacities[i], 0.0, 1.0)
		points[base + 11] = 0.0

		var sh_offset := i * SH_FLOAT_COUNT
		for j in range(SH_FLOAT_COUNT):
			points[base + 12 + j] = sh_coeffs[sh_offset + j]

		if _should_yield(i, count):
			var processed_points := i + 1
			_advance_load_progress(processed_points - reported_points, PHASE_BUILDING, "Packing resource data (%d/%d)" % [processed_points, count])
			reported_points = processed_points
			await get_tree().process_frame

	var resource = GaussianResourceScript.new()
	resource.point_count = count
	resource.point_data_float = points
	resource.point_data_byte = points.to_byte_array()
	resource.xyz = xyz
	resource.aabb = AABB(aabb_min_v, aabb_max_v - aabb_min_v) if count > 0 else AABB()

	return {
		"ok": true,
		"path": asset_path,
		"format": format,
		"resource": resource,
		"point_count": resource.point_count,
		"aabb": resource.aabb
	}

func _decode_source(local_path: String) -> Dictionary:
	var lower_path := local_path.to_lower()
	if lower_path.ends_with(".splat"):
		return SplatDecoder.decode(local_path)
	if lower_path.ends_with(".sog"):
		return SogDecoder.decode(local_path)
	if lower_path.ends_with(".ply"):
		var header := BinaryPlyReader.read(local_path, false)
		if not header.get("ok", false):
			return header
		if _is_compressed_ply(local_path, header):
			return CompressedPlyDecoder.decode(local_path)
		return StandardPlyDecoder.decode(local_path)
	return _error(ERR_FILE_UNRECOGNIZED, "Unsupported gaussian splat extension: %s" % local_path.get_extension())

func _is_compressed_ply(source_file: String, header: Dictionary) -> bool:
	if source_file.to_lower().ends_with(".compressed.ply"):
		return true

	var chunk_element := BinaryPlyReader.get_element(header, "chunk")
	var vertex_element := BinaryPlyReader.get_element(header, "vertex")
	if chunk_element.is_empty() or vertex_element.is_empty():
		return false

	var property_map: Dictionary = vertex_element.get("property_map", {})
	return property_map.has("packed_position") and property_map.has("packed_rotation") and property_map.has("packed_scale") and property_map.has("packed_color")

func _finalize_load(result: Dictionary) -> Dictionary:
	var final_result := result.duplicate(true)
	final_result["pending"] = false
	if final_result.get("ok", false):
		final_result["phase"] = PHASE_READY
		final_result["status"] = STATUS_READY
		final_result["progress"] = 1.0
		final_result["progress_known"] = true
		_load_status = final_result.duplicate(true)
	else:
		final_result["phase"] = _load_status.get("phase", PHASE_IDLE)
		final_result["status"] = final_result.get("message", _load_status.get("status", "Load failed"))
		final_result["progress"] = clampf(float(_load_status.get("progress", 0.0)), 0.0, 1.0)
		final_result["progress_known"] = bool(_load_status.get("progress_known", false))
		_load_status = final_result.duplicate(true)
	_load_request = {}
	load_finished.emit(final_result.duplicate(true))
	return final_result

func _normalize_source(source: String) -> String:
	return source.strip_edges()

func _normalize_path(source: String) -> String:
	var trimmed := source.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return trimmed
	if _looks_like_absolute_path(trimmed):
		return trimmed
	return "res://%s" % trimmed.trim_prefix("/")

func _is_web_url(source: String) -> bool:
	var lower_source := source.to_lower()
	return lower_source.begins_with("http://") or lower_source.begins_with("https://")

func _looks_like_absolute_path(path: String) -> bool:
	return path.begins_with("/") or (path.length() > 2 and path[1] == ":")

func _supported_extension_for(path: String) -> String:
	var lower_path := path.to_lower()
	if lower_path.ends_with(".compressed.ply"):
		return "compressed.ply"
	var extension := lower_path.get_extension()
	if extension in ["ply", "splat", "sog"]:
		return extension
	return ""

func _detect_format(asset_path: String) -> String:
	var lower := asset_path.to_lower()
	if lower.ends_with(".compressed.ply"):
		return "compressed.ply"
	return lower.get_extension()

func _download_cache_path_for(url: String) -> String:
	var extension_hint := _supported_extension_for(url)
	var filename := "%s.%s" % [url.md5_text(), extension_hint]
	return ProjectSettings.globalize_path("%s/%s" % [DOWNLOAD_CACHE_DIR, filename])

func _download_status_text(downloaded_bytes: int, total_bytes: int) -> String:
	return "Downloading splat file (%.1f / %.1f MiB)" % [
		float(downloaded_bytes) / 1048576.0,
		float(total_bytes) / 1048576.0
	]

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_request_completed = true
	_http_request_payload = [result, response_code, headers, body]

func _get_element(ply: Dictionary, name: String) -> Dictionary:
	var elements: Array = ply.get("elements", [])
	for element in elements:
		if element.get("name", "") == name:
			return element
	return {}

func _read_property(data: PackedByteArray, base: int, property_map: Dictionary, property_name: String, default_value: Variant) -> Variant:
	var prop: Dictionary = property_map.get(property_name, {})
	if prop.is_empty():
		return default_value
	return BinaryPlyReader.decode_scalar(data, base + int(prop["offset"]), String(prop["type"]))

func _read_required_property(data: PackedByteArray, base: int, property_map: Dictionary, property_name: String) -> Variant:
	var prop: Dictionary = property_map[property_name]
	return BinaryPlyReader.decode_scalar(data, base + int(prop["offset"]), String(prop["type"]))

func _should_yield(index: int, count: int) -> bool:
	return count > 0 and ((index + 1) % ASYNC_BATCH_SIZE == 0 or index + 1 == count)

func _unpack_111011(value: int) -> Vector3:
	return Vector3(
		float((value >> 21) & 0x7FF) / 2047.0,
		float((value >> 11) & 0x3FF) / 1023.0,
		float(value & 0x7FF) / 2047.0
	)

func _unpack_8888(value: int) -> Vector4:
	return Vector4(
		float((value >> 24) & 0xFF) / 255.0,
		float((value >> 16) & 0xFF) / 255.0,
		float((value >> 8) & 0xFF) / 255.0,
		float(value & 0xFF) / 255.0
	)

func _unpack_packed_rotation(value: int) -> Quaternion:
	var largest := (value >> 30) & 0x3
	var packed := [
		(value >> 20) & 0x3FF,
		(value >> 10) & 0x3FF,
		value & 0x3FF
	]
	var components := [0.0, 0.0, 0.0, 0.0]
	var packed_idx := 0
	var sum_sq := 0.0
	for component_idx in range(4):
		if component_idx == largest:
			continue
		var decoded := ((float(packed[packed_idx]) / 1023.0) - 0.5) * SQRT2
		components[component_idx] = decoded
		sum_sq += decoded * decoded
		packed_idx += 1
	components[largest] = sqrt(maxf(0.0, 1.0 - sum_sq))
	return Quaternion(components[1], components[2], components[3], components[0]).normalized()

func _decode_quantized_sh(value: int) -> float:
	return (((float(value) + 0.5) / 256.0) - 0.5) * 8.0

func _lerp_range(min_value: float, max_value: float, normalized: float) -> float:
	return min_value + (max_value - min_value) * normalized

func _sigmoid(value: float) -> float:
	return 1.0 / (1.0 + exp(-value))

func _begin_load_progress(total_units: int) -> void:
	_load_total_units = max(total_units + 1, 2)
	_load_completed_units = 1
	_set_load_status(PHASE_DECODING, _load_status.get("status", STATUS_READING), {
		"progress_known": true
	})

func _advance_load_progress(delta_units: int, phase: String, status_text: String) -> void:
	if delta_units > 0:
		_load_completed_units = min(_load_total_units, _load_completed_units + delta_units)
	_set_load_status(phase, status_text, {
		"progress_known": true
	})

func _set_load_status(phase: String, status_text: String, extra: Dictionary = {}, emit_signal: bool = true) -> void:
	var status := _load_request.duplicate(true)
	for key in extra.keys():
		status[key] = extra[key]
	status["pending"] = status.get("pending", is_load_in_progress())
	status["phase"] = phase
	status["status"] = status_text
	status["progress"] = clampf(_compute_load_progress(), 0.0, 1.0) if not extra.has("progress") else clampf(float(extra["progress"]), 0.0, 1.0)
	status["progress_known"] = bool(status.get("progress_known", _load_total_units > 0))
	_load_status = status
	if emit_signal:
		load_progressed.emit(status.duplicate(true))

func _compute_load_progress() -> float:
	if _load_total_units <= 0:
		return 0.0
	return float(_load_completed_units) / float(_load_total_units)

func _reset_load_progress() -> void:
	_load_total_units = 0
	_load_completed_units = 0
	_load_status = {
		"pending": false,
		"progress": 0.0,
		"progress_known": false,
		"phase": PHASE_IDLE,
		"status": STATUS_IDLE
	}

func _error(code: int, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message
	}
