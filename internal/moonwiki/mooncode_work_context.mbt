///|
fn mooncode_work_context_path_supported(path : String) -> Bool {
  mooncode_work_context_captured_digest(path) is Some(_)
}

///|
fn mooncode_work_context_captured_digest(path : String) -> String? {
  let prefix = ".moonsuite/products/moonproj/execution-context/"
  let suffix = "/context.md"
  if !path.has_prefix(prefix) || !path.has_suffix(suffix) {
    return None
  }
  let capture = path[prefix.length():path.length() - suffix.length()].to_owned()
  if capture.length() == 64 &&
    capture.iter().all(c => c.is_ascii_digit() || (c >= 'a' && c <= 'f')) {
    Some(capture)
  } else {
    None
  }
}

///|
fn mooncode_work_context_state(
  path : String,
  state : String,
  message : String,
) -> Json {
  let expected = mooncode_work_context_captured_digest(path)
  {
    "state": state,
    "path": path,
    "message": message,
    "text": null,
    "actual_sha256": null,
    "expected_sha256": match expected {
      Some(value) => value.to_json()
      None => Json::null()
    },
    "size_bytes": null,
    "integrity": if expected is Some(_) {
      "not_checked"
    } else {
      "captured_digest_unavailable"
    },
  }
}

///|
async fn mooncode_work_read_context(
  workspace : @desk.DeskWorkspace,
  descriptor : Json,
) -> Json {
  let path = json_string(
    json_object_field_or_empty(descriptor, "original_command"),
    "context_path",
    default="",
  )
  if path.is_empty() {
    return mooncode_work_context_state(
      path, "absent", "This original native command has no captured context path",
    )
  }
  if !mooncode_work_context_path_supported(path) {
    return mooncode_work_context_state(
      path, "unsupported_path", "The captured context reference is outside MoonProj's immutable context directory; generic internal-file access is not enabled",
    )
  }
  let root = @fs.realpath(workspace.root_path) catch {
    _ =>
      return mooncode_work_context_state(
        path, "unavailable", "The resolved MoonBook cannot currently be read",
      )
  }
  let absolute = @pathx.join(root, path)
  if !@fs.exists(absolute) {
    return mooncode_work_context_state(
      path, "missing", "The exact captured context file is missing; the original work remains resolved",
    )
  }
  let canonical = @fs.realpath(absolute) catch {
    _ =>
      return mooncode_work_context_state(
        path, "unavailable", "The captured context path cannot currently be resolved",
      )
  }
  let root_prefix = if root == "/" { "/" } else { root + "/" }
  if canonical != absolute || !canonical.has_prefix(root_prefix) {
    return mooncode_work_context_state(
      path, "unavailable", "The captured context path is not a direct file inside the verified MoonBook",
    )
  }
  let bytes = try {
    let file = @fs.open(canonical, mode=@fs.ReadOnly)
    defer file.close()
    if file.size() > 4L * 1024L * 1024L {
      return mooncode_work_context_state(
        path, "unavailable", "The captured context exceeds the 4 MiB inspection limit",
      )
    }
    file.read_all().binary()
  } catch {
    _ =>
      return mooncode_work_context_state(
        path, "unavailable", "The captured context file cannot currently be read",
      )
  }
  // The verified Proj generator names this exact schema using SHA-256(bytes).
  // Only that C0-recorded content-addressed path, never a query hint, is evidence.
  let expected = mooncode_work_context_captured_digest(path).unwrap()
  let actual = @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
  let matches = actual == expected
  let text = if matches {
    @encoding/utf8.decode(bytes) catch {
      _ =>
        return mooncode_work_context_state(
          path, "unavailable", "The captured context is not valid UTF-8 text",
        )
    }
  } else {
    ""
  }
  {
    "state": if matches {
      "ready"
    } else {
      "mismatch"
    },
    "path": path,
    "text": if matches {
      text.to_json()
    } else {
      Json::null()
    },
    "expected_sha256": expected,
    "actual_sha256": actual,
    "size_bytes": bytes.length(),
    "integrity": if matches {
      "verified"
    } else {
      "mismatch"
    },
    "message": if matches {
      "Context bytes match the content-addressed path captured by the original native command"
    } else {
      "The referenced context file no longer matches the original captured digest; changed bytes are not presented as original requirements"
    },
  }
}
