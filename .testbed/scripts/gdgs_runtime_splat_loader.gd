extends Node

const GaussianResourceBuilder = preload("res://addons/gdgs/importers/builders/gaussian_resource_builder.gd")
const StandardPlyDecoder = preload("res://addons/gdgs/importers/decoders/standard_ply_decoder.gd")
const CompressedPlyDecoder = preload("res://addons/gdgs/importers/decoders/compressed_ply_decoder.gd")
const SplatDecoder = preload("res://addons/gdgs/importers/decoders/splat_decoder.gd")
const SogDecoder = preload("res://addons/gdgs/importers/decoders/sog_decoder.gd")
const BinaryPlyReader = preload("res://addons/gdgs/importers/parsers/binary_ply_reader.gd")

const DOWNLOAD_CACHE_DIR := "user://gdgs-loader-cache"
const HTTP_OK_MIN := 200
const HTTP_OK_MAX := 299

func load_from_source(source: String) -> Dictionary:
	var normalized_source := _normalize_source(source)
	if normalized_source.is_empty():
		return _error(ERR_INVALID_PARAMETER, "Enter a res:// path, local file path, or web URL.")

	if _is_web_url(normalized_source):
		return await _load_from_url(normalized_source)

	return _load_from_path(normalized_source)

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

	var request_error := request.request(url)
	if request_error != OK:
		request.queue_free()
		return _error(request_error, "Unable to start download: %s" % url)

	var completed: Array = await request.request_completed
	request.queue_free()

	if completed.size() < 4:
		return _error(ERR_BUG, "Unexpected HTTP completion payload")

	var result_code := int(completed[0])
	var response_code := int(completed[1])
	var body: PackedByteArray = completed[3]
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

	return _decode_file(target_path, url)

func _load_from_path(source: String) -> Dictionary:
	var normalized_path := _normalize_path(source)
	if normalized_path.begins_with("res://"):
		var imported_resource := load(normalized_path)
		if imported_resource != null and imported_resource.get_script() != null and imported_resource.has_method("get") and imported_resource.get("point_count") != null:
			return {
				"ok": true,
				"resource": imported_resource,
				"resolved_source": normalized_path,
				"message": "Loaded imported GaussianResource from %s" % normalized_path
			}
		return _decode_file(ProjectSettings.globalize_path(normalized_path), normalized_path)

	if normalized_path.begins_with("user://"):
		return _decode_file(ProjectSettings.globalize_path(normalized_path), normalized_path)

	if not FileAccess.file_exists(normalized_path):
		return _error(ERR_FILE_NOT_FOUND, "File not found: %s" % normalized_path)
	return _decode_file(normalized_path, normalized_path)

func _decode_file(local_path: String, display_source: String) -> Dictionary:
	if not FileAccess.file_exists(local_path):
		return _error(ERR_FILE_NOT_FOUND, "File not found: %s" % display_source)

	var decode_result := _decode_source(local_path)
	if not decode_result.get("ok", false):
		return _error(int(decode_result.get("error", ERR_INVALID_DATA)), decode_result.get("message", "Unable to decode gaussian splat"))

	var build_result := GaussianResourceBuilder.build(decode_result["canonical"])
	if not build_result.get("ok", false):
		return _error(int(build_result.get("error", ERR_INVALID_DATA)), build_result.get("message", "Unable to build gaussian resource"))

	return {
		"ok": true,
		"resource": build_result["resource"],
		"resolved_source": display_source,
		"message": "Loaded %d gaussians from %s" % [int(build_result["resource"].get("point_count")), display_source]
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

func _download_cache_path_for(url: String) -> String:
	var extension_hint := _supported_extension_for(url)
	var filename := "%s.%s" % [url.md5_text(), extension_hint]
	return ProjectSettings.globalize_path("%s/%s" % [DOWNLOAD_CACHE_DIR, filename])

func _error(code: Error, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message
	}
