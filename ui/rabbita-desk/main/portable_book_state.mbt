///|
struct PortableBookExport {
  export_id : String
  path : String
  version : String
  package_sha256 : String
  package_size_bytes : Int32
} derive(FromJson, ToJson, Eq, Debug)

///|
struct PortableBookCatalog {
  workspace_id : String
  expected_library : String
  available : Bool
  message : String
  exports : Array[PortableBookExport]
} derive(FromJson)

///|
struct PortableBookMember {
  path : String
  role : String
  digest : String
  size_bytes : Int32
  review_status : String
  sensitivity : String
} derive(FromJson, ToJson, Eq, Debug)

///|
struct PortableBookExclusion {
  path : String
  reason : String
} derive(FromJson, ToJson, Eq, Debug)

///|
struct PortableBookInspection {
  contract : String
  agent_id : String
  version : String
  book_revision : String
  bundle_digest : String
  file_count : Int32
  total_bytes : Int32
  files : Array[PortableBookMember]
  exclusions : Array[PortableBookExclusion]
  compatibility : Json
  export_policy : Json
  memory_policy : Json
  memory_metrics : Json
} derive(FromJson, ToJson)

///|
struct PortableBookVerification {
  ok : Bool
  agent_id : String
  version : String
  bundle_digest : String
  checked_file_count : Int32
  issues : Array[String]
} derive(FromJson, ToJson)

///|
struct PortableBookSource {
  agent_id : String
  agent_version : String
  book_revision : String
  bundle_digest : String
  package_filename : String
  package_size_bytes : Int32
  package_sha256 : String
  file_count : Int32
  total_decoded_bytes : Int32
} derive(FromJson, ToJson)

///|
struct PortableBookPrepared {
  workspace_id : String
  expected_library : String
  export_id : String
  path : String
  inspection : PortableBookInspection
  verification : PortableBookVerification
  source : PortableBookSource
} derive(FromJson, ToJson)

///|
enum PortableBookOperation {
  Catalog
  Entries(String)
  ChooseHumanResult
  PreparePackage(String)
  InspectPackage(String)
} derive(Eq, Debug)

///|
struct PortableBookPending {
  request : Int32
  operation : PortableBookOperation
} derive(Eq, Debug)

///|
struct PortableBookState {
  active : Bool
  library_changing : Bool
  library : String
  workspace : String
  generation : Int32
  request : Int32
  available : Bool
  loaded : Bool
  capability_message : String
  exports : Array[PortableBookExport]
  version : String
  paths : Array[String]
  output_groups : Array[PortableBookGroup]
  group_name : String
  selected_group : String
  next_group_id : Int32
  directory : String
  entries : Array[@desk.DeskFileEntry]
  entries_loaded : Bool
  operation_id : String
  recovery_checked : Bool
  accepted_human_result : PortableBookHumanResult?
  prepared : PortableBookPrepared?
  pending : PortableBookPending?
  error : String
  notice : String
}

///|
enum PortableBookMsg {
  BindPortable(Bool, String, String)
  RefreshCatalog
  SetVersion(String)
  BrowseFiles(String)
  ToggleFile(String)
  RemoveFile(String)
  OutputGroup(PortableGroupMsg)
  ChooseAcceptedHumanResult
  RemoveAcceptedHumanResult
  AcceptedHumanResultPicked(
    Int32,
    Int32,
    Result[PortableBookHumanResult?, String]
  )
  Prepare(String)
  InspectSaved(String)
  CheckPreparation
  StartNewPreparation
  Received(Int32, Int32, Result[Json, String])
  FilesReceived(Int32, Int32, Result[Array[@desk.DeskFileEntry], String])
  TimedOut(Int32, Int32)
}

///|
enum PortableBookEffect {
  NoPortableEffect
  ReadPortableCatalog(Int32, Int32)
  ReadPortableEntries(Int32, Int32, String)
  PreparePortablePackage(Int32, Int32, String, String, Array[String])
  PreparePortableGroupedPackage(
    Int32,
    Int32,
    String,
    String,
    Array[String],
    Array[PortableBookGroup],
    String?
  )
  PreparePortablePackageWithHumanResult(
    Int32,
    Int32,
    String,
    String,
    Array[String],
    String
  )
  PickAcceptedHumanResult(Int32, Int32)
  InspectPortablePackage(Int32, Int32, String)
} derive(Eq, Debug)

///|
fn init_portable_book() -> PortableBookState {
  {
    active: false,
    library_changing: false,
    library: "",
    workspace: "",
    generation: 0,
    request: 0,
    available: false,
    loaded: false,
    capability_message: "",
    exports: [],
    version: "",
    paths: [],
    output_groups: [],
    group_name: "",
    selected_group: "",
    next_group_id: 1,
    directory: "",
    entries: [],
    entries_loaded: false,
    operation_id: "",
    recovery_checked: false,
    accepted_human_result: None,
    prepared: None,
    pending: None,
    error: "",
    notice: "",
  }
}

///|
fn portable_book_id_valid(id : String) -> Bool {
  id.length() == 32 && id.iter().all(c => c is ('0'..<='9' | 'a'..<='f'))
}

///|
fn portable_book_path_valid(path : String) -> Bool {
  path != "" &&
  !path.contains("\\") &&
  !path.contains("\u0000") &&
  path.split("/").all(part => part != "" && part != "." && part != "..")
}

///|
fn portable_book_sha_valid(digest : String) -> Bool {
  digest.length() == 71 &&
  digest.has_prefix("sha256:") &&
  digest[7:].to_owned().iter().all(c => c is ('0'..<='9' | 'a'..<='f'))
}

///|
fn portable_book_can_prepare(state : PortableBookState) -> Bool {
  state.active &&
  !state.library_changing &&
  state.library != "" &&
  state.workspace != "" &&
  state.loaded &&
  state.available &&
  state.pending is None &&
  state.prepared is None &&
  state.operation_id == "" &&
  !state.version.trim().is_empty() &&
  state.version.length() <= 64 &&
  portable_book_groups_valid(state)
}

///|
fn portable_book_inputs_locked(state : PortableBookState) -> Bool {
  state.library_changing ||
  state.pending is Some(_) ||
  (state.operation_id != "" && state.prepared is None)
}

///|
fn portable_book_error(result : Result[Json, String]) -> String {
  match result {
    Ok({ "error": String(message), .. }) if !message.trim().is_empty() =>
      message
    Ok({ "message": String(message), .. }) if !message.trim().is_empty() =>
      message
    _ =>
      "The local host response could not be verified. Check the saved package before starting another preparation."
  }
}

///|
fn portable_book_decode_prepared(
  json : Json,
  library : String,
  workspace : String,
  export_id : String,
) -> PortableBookPrepared? {
  let value : PortableBookPrepared = @json.from_json(json) catch {
    _ => return None
  }
  let inspection = value.inspection
  let source = value.source
  let verification = value.verification
  if value.expected_library != library ||
    value.workspace_id != workspace ||
    value.export_id != export_id ||
    !portable_book_id_valid(value.export_id) ||
    !portable_book_path_valid(value.path) ||
    !portable_book_sha_valid(source.package_sha256) ||
    source.package_size_bytes <= 0 ||
    inspection.agent_id == "" ||
    inspection.version == "" ||
    inspection.bundle_digest == "" ||
    !verification.ok ||
    !verification.issues.is_empty() ||
    verification.agent_id != inspection.agent_id ||
    verification.version != inspection.version ||
    verification.bundle_digest != inspection.bundle_digest ||
    verification.checked_file_count != inspection.files.length() ||
    source.agent_id != inspection.agent_id ||
    source.agent_version != inspection.version ||
    source.book_revision != inspection.book_revision ||
    source.bundle_digest != inspection.bundle_digest ||
    source.file_count != inspection.files.length() ||
    inspection.file_count != inspection.files.length() ||
    source.total_decoded_bytes != inspection.total_bytes ||
    inspection.total_bytes < 0 {
    return None
  }
  let seen : Map[String, Unit] = Map([])
  let mut total = 0
  for file in inspection.files {
    if !portable_book_path_valid(file.path) ||
      seen.contains(file.path) ||
      file.role == "" ||
      file.digest == "" ||
      file.review_status == "" ||
      file.sensitivity == "" ||
      file.size_bytes < 0 ||
      file.size_bytes > inspection.total_bytes - total {
      return None
    }
    seen[file.path] = ()
    total += file.size_bytes
  }
  if total != inspection.total_bytes {
    None
  } else {
    Some(value)
  }
}

///|
fn portable_book_download_url(prepared : PortableBookPrepared) -> String {
  @desk.workspace_artifact_url(
    prepared.workspace_id,
    prepared.path,
    prepared.source.package_sha256,
  )
}
