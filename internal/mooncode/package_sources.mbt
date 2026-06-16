///|
pub fn package_candidate_paths(context_path : String) -> Array[String] {
  if context_path == "" {
    ["tools/", "apps/", "book/site/generated/", "portable/app-tool/"]
  } else {
    [context_path]
  }
}

///|
pub fn package_kind_for_path(context_path : String) -> String {
  if context_path.has_prefix("tools/") {
    "tool"
  } else if context_path.has_prefix("apps/") {
    "miniapp"
  } else if context_path.has_prefix("book/site/generated/") ||
    context_path.has_prefix("site/generated/") {
    "generated-site"
  } else if context_path.has_prefix("portable/app-tool/") {
    "app-tool"
  } else {
    "app-tool-candidate"
  }
}

///|
pub fn package_source_missing_record(path : String) -> Json {
  { "path": path, "exists": false, "kind": "missing", "package_ready": false }
}

///|
pub fn package_source_invalid_record(path : String) -> Json {
  { "path": path, "exists": false, "kind": "invalid", "package_ready": false }
}

///|
pub fn package_source_unknown_record(path : String) -> Json {
  { "path": path, "exists": true, "kind": "unknown", "package_ready": false }
}

///|
pub fn package_source_directory_record(path : String) -> Json {
  {
    "path": path,
    "exists": true,
    "kind": "directory",
    "package_ready": true,
    "promoted": false,
    "promotion": {
      "promoted": false,
      "status": "directory-source",
      "source_path": path,
    },
  }
}

///|
pub fn package_source_promotion_path(
  package_root : String,
  command_id : String,
  source_path : String,
) -> String {
  let safe_command = artifact_safe_id(command_id, fallback="command")
  "\{package_root}/sources/\{safe_command}/\{source_path}"
}

///|
pub fn package_source_non_text_promotion(
  source_path : String,
  promoted_path : String,
  promoted_absolute_path : String,
) -> Json {
  {
    "promoted": false,
    "status": "non-text-source",
    "source_path": source_path,
    "promoted_path": promoted_path,
    "promoted_absolute_path": promoted_absolute_path,
  }
}

///|
pub fn package_source_failed_promotion(
  source_path : String,
  promoted_path : String,
  promoted_absolute_path : String,
  error : String,
) -> Json {
  {
    "promoted": false,
    "status": "failed",
    "source_path": source_path,
    "promoted_path": promoted_path,
    "promoted_absolute_path": promoted_absolute_path,
    "error": error,
  }
}

///|
pub fn package_source_promoted_promotion(
  source_path : String,
  promoted_path : String,
  promoted_absolute_path : String,
  content : String,
) -> Json {
  {
    "promoted": true,
    "status": "promoted",
    "source_path": source_path,
    "promoted_path": promoted_path,
    "promoted_absolute_path": promoted_absolute_path,
    "size_bytes": content.length(),
    "sha256": @crypto.bytes_to_hex_string(
      @crypto.sha256(@encoding/utf8.encode(content)),
    ),
  }
}

///|
pub fn package_source_file_record(
  path : String,
  size_bytes : Int,
  sha256 : String,
  promotion : Json,
) -> Json {
  {
    "path": path,
    "exists": true,
    "kind": "file",
    "size_bytes": size_bytes,
    "sha256": sha256,
    "promotion": promotion,
    "promoted": json_bool(promotion, "promoted", default=false),
    "promoted_path": json_string(promotion, "promoted_path", default=""),
    "promoted_absolute_path": json_string(
      promotion,
      "promoted_absolute_path",
      default="",
    ),
    "package_ready": true,
  }
}

///|
pub fn package_manifest_list_contains(
  manifests : Array[Json],
  manifest_path : String,
) -> Bool {
  if manifest_path == "" {
    return false
  }
  for manifest in manifests {
    if json_string(manifest, "manifest_path", default="") == manifest_path {
      return true
    }
  }
  false
}
