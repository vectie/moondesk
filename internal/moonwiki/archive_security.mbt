///|
priv struct ArchiveImportLimits {
  max_entries : Int
  max_file_bytes : Int
  max_total_bytes : Int
}

///|
fn archive_import_limits() -> ArchiveImportLimits {
  {
    max_entries: 256,
    max_file_bytes: 8 * 1024 * 1024,
    max_total_bytes: 32 * 1024 * 1024,
  }
}

///|
fn archive_entry_path(path : String) -> Result[String, String] {
  if path.has_prefix("/") || @pathx.is_absolute(path) || path.contains("\\") {
    return Err("Archive entry path must be relative")
  }
  let trimmed = path.trim(chars=['/']).to_owned()
  if trimmed == "" {
    return Err("Archive entry path is empty")
  }
  for segment in trimmed.split("/") {
    if segment == "" || segment == "." || segment == ".." {
      return Err("Archive entry path is not confined")
    }
  }
  let normalized = @pathx.normalize(trimmed)
  if normalized != trimmed || normalized == ".." || normalized.has_prefix("../") {
    Err("Archive entry path is not confined")
  } else {
    Ok(normalized)
  }
}

///|
fn archive_entries_receipt(entries : Array[Json]) -> Json {
  let limits = archive_import_limits()
  let accepted : Array[Json] = []
  let renamed : Array[Json] = []
  let rejected : Array[Json] = []
  let quarantined : Array[Json] = []
  let seen : Array[String] = []
  let mut total_bytes = 0
  for index, entry in entries {
    let path = json_string(entry, "path", default="")
    let kind = json_string(entry, "kind", default="file")
    let size = json_int(entry, "expanded_size", default=0)
    let clean = archive_entry_path(path)
    if index >= limits.max_entries {
      quarantined.push({ "path": path, "reason": "entry-limit" })
    } else if clean is Err(reason) {
      rejected.push({ "path": path, "reason": reason })
    } else if kind != "file" {
      rejected.push({ "path": path, "reason": "unsupported-entry-type" })
    } else if size < 0 ||
      size > limits.max_file_bytes ||
      total_bytes + size > limits.max_total_bytes {
      quarantined.push({ "path": path, "reason": "expanded-size-limit" })
    } else {
      guard clean is Ok(clean_path) else { continue }
      let collision_key = clean_path.to_lower()
      if seen.contains(collision_key) {
        rejected.push({
          "path": path,
          "reason": "duplicate-or-normalization-collision",
        })
      } else {
        seen.push(collision_key)
        total_bytes += size
        accepted.push({ "path": clean_path, "expanded_size": size })
      }
    }
  }
  {
    "kind": "moondesk.archive-import-receipt.v1",
    "staging_required": true,
    "promotion_policy": "all-accepted-entries-verified-before-promotion",
    "overwrite_policy": "refuse",
    "accepted": accepted,
    "renamed": renamed,
    "rejected": rejected,
    "quarantined": quarantined,
    "expanded_bytes": total_bytes,
  }
}
