///|
async fn write_mooncode_review_receipt(
  session : Json,
  action : String,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(session, command_packet)
  if book_root == "" {
    fail("MoonCode review receipt needs a MoonBook workspace root")
  }
  let session_id = json_string(
    session,
    "id",
    default=json_string(command_packet, "session_id", default="session"),
  )
  let command_id = json_string(command_packet, "command_id", default="command")
  let relative = @mooncode.review_receipt_relative_path(
    session_id, command_id, action,
  )
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let recorded_at = @async.now().to_string()
  let receipt = @mooncode.review_receipt_manifest(
    session,
    action,
    command_packet,
    context_path,
    detail,
    command_created_at,
    command_id~,
    recorded_at~,
    receipt_path=relative,
    absolute_receipt_path=absolute,
  )
  @fsx.write_to_file(absolute, receipt.stringify(indent=2) + "\n")
  receipt
}

///|
async fn write_mooncode_package_manifest_for_receipt(
  session : Json,
  receipt : Json,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(session, command_packet)
  if book_root == "" {
    fail("MoonCode package manifest needs a MoonBook workspace root")
  }
  let session_id = json_string(
    session,
    "id",
    default=json_string(command_packet, "session_id", default="session"),
  )
  let command_id = json_string(command_packet, "command_id", default="command")
  let relative = @mooncode.package_manifest_relative_path(
    session_id, command_id,
  )
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let recorded_at = @async.now().to_string()
  let candidate_paths = @mooncode.package_candidate_paths(context_path)
  let source_inventory = mooncode_package_source_inventory(
    book_root,
    candidate_paths,
    package_root=@pathx.dirname(relative).to_owned(),
    command_id~,
  )
  let manifest = @mooncode.package_manifest(
    session, receipt, command_packet, context_path, detail, command_created_at, recorded_at,
    relative, absolute, source_inventory,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  let index_manifest = write_mooncode_package_index_manifest(
    session, session_id, manifest,
  )
  @mooncode.session_with_package_manifest_events(
    session,
    manifest,
    @mooncode.package_manifest_projected_event(
      manifest, context_path, recorded_at, command_packet,
    ),
    index_manifest,
    @mooncode.package_index_manifest_projected_event(index_manifest),
  )
}

///|
async fn write_mooncode_package_index_manifest(
  session : Json,
  session_id : String,
  latest_manifest : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(latest_manifest, "command_packet"),
  )
  if book_root == "" {
    fail("MoonCode package index needs a MoonBook workspace root")
  }
  let relative = @mooncode.package_index_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let packages = mooncode_package_candidate_manifests(session, session_id)
  let latest_path = json_string(latest_manifest, "manifest_path", default="")
  if latest_path != "" &&
    !@mooncode.package_manifest_list_contains(packages, latest_path) {
    packages.push(latest_manifest)
  }
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.package_index_manifest(
    session,
    session_id,
    latest_manifest,
    packages,
    recorded_at,
    relative,
    absolute,
    @pathx.dirname(relative).to_owned(),
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn mooncode_package_source_inventory(
  book_root : String,
  candidate_paths : Array[String],
  package_root~ : String,
  command_id~ : String,
) -> Array[Json] {
  let records : Array[Json] = []
  for candidate in candidate_paths {
    records.push(
      mooncode_package_source_record(
        book_root,
        candidate,
        package_root~,
        command_id~,
      ),
    )
  }
  records
}

///|
async fn mooncode_package_source_record(
  book_root : String,
  candidate : String,
  package_root~ : String,
  command_id~ : String,
) -> Json {
  match resolve_workspace_path(book_root, candidate) {
    Some((absolute, relative)) =>
      if !@fs.exists(absolute) {
        @mooncode.package_source_missing_record(relative)
      } else {
        let kind = @fs.kind(absolute) catch {
          _ => return @mooncode.package_source_unknown_record(relative)
        }
        match kind {
          @fs.FileKind::Directory =>
            @mooncode.package_source_directory_record(relative)
          _ =>
            mooncode_package_file_record(
              absolute,
              relative,
              book_root~,
              package_root~,
              command_id~,
            )
        }
      }
    None => @mooncode.package_source_invalid_record(candidate)
  }
}

///|
async fn mooncode_package_file_record(
  absolute : String,
  relative : String,
  book_root~ : String,
  package_root~ : String,
  command_id~ : String,
) -> Json {
  let bytes = @fs.read_file(absolute).binary() catch {
    _ => return @mooncode.package_source_unknown_record(relative)
  }
  let text = @fs.read_file(absolute).text() catch { _ => "" }
  let promotion = mooncode_promote_package_source(
    book_root,
    package_root,
    command_id,
    relative,
    text,
    can_promote=text != "",
  )
  @mooncode.package_source_file_record(
    relative,
    bytes.length(),
    @crypto.bytes_to_hex_string(@crypto.sha256(bytes.to_fixedarray())),
    promotion,
  )
}

///|
async fn mooncode_promote_package_source(
  book_root : String,
  package_root : String,
  command_id : String,
  relative : String,
  content : String,
  can_promote~ : Bool,
) -> Json {
  let promoted_path = @mooncode.package_source_promotion_path(
    package_root, command_id, relative,
  )
  let promoted_absolute = @pathx.join(book_root, promoted_path)
  if !can_promote {
    return @mooncode.package_source_non_text_promotion(
      relative, promoted_path, promoted_absolute,
    )
  }
  @fsx.make_directory(
    @pathx.dirname(promoted_absolute),
    recursive=true,
    exists_ok=true,
  ) catch {
    error =>
      return @mooncode.package_source_failed_promotion(
        relative,
        promoted_path,
        promoted_absolute,
        "\{error}",
      )
  }
  @fsx.write_to_file(promoted_absolute, content) catch {
    error =>
      return @mooncode.package_source_failed_promotion(
        relative,
        promoted_path,
        promoted_absolute,
        "\{error}",
      )
  }
  @mooncode.package_source_promoted_promotion(
    relative, promoted_path, promoted_absolute, content,
  )
}

///|
async fn mooncode_package_candidates_projection(
  session : Json,
  session_id : String,
) -> Json {
  let packages = mooncode_package_candidate_manifests(session, session_id)
  let index_manifest = mooncode_package_index_manifest(session, session_id)
  @mooncode.package_candidates_projection(
    session, session_id, packages, index_manifest,
  )
}

///|
async fn mooncode_package_index_manifest(
  session : Json,
  session_id : String,
) -> Json {
  match json_object_field(session, "mooncode_last_package_index_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-package-index" {
        return manifest
      }
    None => ()
  }
  let book_root = json_string(session, "workspace_root", default="")
  if book_root == "" {
    return Json::object({})
  }
  let absolute = @pathx.join(
    book_root,
    @mooncode.package_index_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch {
    _ => return Json::object({})
  }
  let manifest = @json.parse(text) catch { _ => return Json::object({}) }
  if json_string(manifest, "kind", default="") == "mooncode-package-index" {
    manifest
  } else {
    Json::object({})
  }
}

///|
async fn mooncode_package_candidate_manifests(
  session : Json,
  session_id : String,
) -> Array[Json] {
  let manifests : Array[Json] = []
  let book_root = json_string(session, "workspace_root", default="")
  if book_root != "" {
    let root = @pathx.join(
      book_root,
      @mooncode.package_session_root_relative_path(session_id),
    )
    for name in read_directory_names(root, include_hidden=false) {
      if name.has_prefix("package-") && name.has_suffix(".json") {
        let manifest = read_json_file_or_object(@pathx.join(root, name))
        if json_string(manifest, "kind", default="") ==
          "mooncode-package-manifest" {
          manifests.push(manifest)
        }
      }
    }
  }
  let last = json_object_field_or_empty(
    session, "mooncode_last_package_manifest",
  )
  if json_string(last, "kind", default="") == "mooncode-package-manifest" {
    let path = json_string(last, "manifest_path", default="")
    if !@mooncode.package_manifest_list_contains(manifests, path) {
      manifests.push(last)
    }
  }
  manifests
}

///|
fn mooncode_review_receipt_book_root(
  session : Json,
  command_packet : Json,
) -> String {
  let from_session = json_string(session, "workspace_root", default="")
  if from_session != "" {
    return @pathx.normalize(from_session)
  }
  let from_packet = json_string(command_packet, "workspace_root", default="")
  if from_packet != "" {
    return @pathx.normalize(from_packet)
  }
  let cwd = json_string(session, "cwd", default="")
  if cwd != "" {
    @pathx.normalize(cwd)
  } else {
    ""
  }
}

///|
