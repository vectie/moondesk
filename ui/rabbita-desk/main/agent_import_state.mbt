///|
struct AgentImportMembers {
  ok : Bool
  changed_members : Array[String]
} derive(FromJson)

///|
struct AgentImportReply {
  operation_id : String
  expected_library : String
  status : String
  filename : String
  destination_folder : String
  inspection : PortableBookInspection
  verification : PortableBookVerification
  source : PortableBookSource
  import_verification : AgentImportMembers?
  created : CreatedWorkspace?
  message : String
  town_binding : Json
  exact_import_receipt : Json
}

///|
/// HTTP uses explicit nulls. Derived optional record fields interpret absence
/// as None, so decode nullable completion fields explicitly at the boundary.
struct AgentImportWire {
  operation_id : String
  expected_library : String
  status : String
  filename : String
  destination_folder : String
  inspection : PortableBookInspection
  verification : PortableBookVerification
  source : PortableBookSource
  import_verification : Json
  created : Json
  message : String
} derive(FromJson)

///|
fn agent_import_parse_reply(json : Json) -> AgentImportReply? {
  let wire : AgentImportWire = @json.from_json(json) catch { _ => return None }
  let created : CreatedWorkspace? = if wire.created is Null {
    None
  } else {
    Some(@json.from_json(wire.created) catch { _ => return None })
  }
  let import_verification : AgentImportMembers? = if wire.import_verification
    is Null {
    None
  } else {
    Some(@json.from_json(wire.import_verification) catch { _ => return None })
  }
  Some({
    operation_id: wire.operation_id,
    expected_library: wire.expected_library,
    status: wire.status,
    filename: wire.filename,
    destination_folder: wire.destination_folder,
    inspection: wire.inspection,
    verification: wire.verification,
    source: wire.source,
    import_verification,
    created,
    message: wire.message,
    town_binding: handoff_field(json, "town_binding"),
    exact_import_receipt: handoff_field(json, "exact_import_receipt"),
  })
}

///|
struct AgentImportSession {
  library : String
  operation_id : String
  filename : String
  destination : String
  status : String
  import_started : Bool
  reviewed_sha : String
  reply : AgentImportReply?
  error : String
  exact_required : Bool
  binding_digest : String
}

///|
enum AgentImportOperation {
  PickingPackage
  PickingBinding
  StagingPackage
  ImportingPackage
  CheckingImport
  CheckingBeforeOpen
} derive(Eq, Debug)

///|
struct AgentImportPending {
  request : Int32
  operation : AgentImportOperation
} derive(Eq, Debug)

///|
struct AgentImportState {
  active : Bool
  library_changing : Bool
  context : String
  generation : Int32
  request : Int32
  session : AgentImportSession
  suspended : Array[AgentImportSession]
  pending : AgentImportPending?
  package_file : LocalImportFile?
}

///|
enum AgentImportMsg {
  BindAgentImport(Bool, String, String)
  ChoosePackage(String)
  ChooseExactPackage(String)
  ChooseBinding
  PackagePicked(Int32, Int32, Result[Array[LocalImportFile], String])
  BindingPicked(Int32, Int32, Result[Array[LocalImportFile], String])
  SetImportDestination(String)
  ImportInspectedPackage
  CheckImport
  CancelPackage
  KeepAttemptAndStartNew
  SelectSavedImport(String)
  OpenImportedPackage
  ImportResponse(Int32, Int32, Result[Json, String])
  ImportTimedOut(Int32, Int32)
}

///|
enum AgentImportEffect {
  NoAgentImportEffect
  PickAgentPackage(Int32, Int32)
  PickAgentBinding(Int32, Int32)
  StageAgentPackage(Int32, Int32, LocalImportFile)
  StageExactAgentPackage(Int32, Int32, LocalImportFile, Json)
  WriteAgentImport(Int32, Int32)
  ReadAgentImport(Int32, Int32)
  OpenAgentImport(CreatedWorkspace)
}

///|
fn init_agent_import_session(library : String) -> AgentImportSession {
  {
    library,
    operation_id: "",
    filename: "",
    destination: "",
    status: "empty",
    import_started: false,
    reviewed_sha: "",
    reply: None,
    error: "",
    exact_required: false,
    binding_digest: "",
  }
}

///|
fn init_agent_import() -> AgentImportState {
  {
    active: false,
    library_changing: false,
    context: "",
    generation: 0,
    request: 0,
    session: init_agent_import_session(""),
    suspended: agent_import_restore_sessions(browser_agent_import_saved()),
    pending: None,
    package_file: None,
  }
}

///|
fn agent_import_destination_valid(value : String) -> Bool {
  value.length() > 0 &&
  value.length() <= 80 &&
  value[0] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9') &&
  value.iter().all(c => c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-' | '_'))
}

///|
fn agent_import_ready(state : AgentImportState) -> Bool {
  state.active &&
  !state.library_changing &&
  state.session.library != "" &&
  state.pending is None
}

///|
fn agent_import_can_write(state : AgentImportState) -> Bool {
  agent_import_ready(state) &&
  state.session.status == "inspected" &&
  !state.session.import_started &&
  state.session.reply is Some(_) &&
  agent_import_destination_valid(state.session.destination)
}

///|
fn agent_import_decode_reply(
  json : Json,
  session : AgentImportSession,
) -> AgentImportReply? {
  guard agent_import_parse_reply(json) is Some(reply) else { return None }
  if reply.expected_library != session.library ||
    reply.operation_id != session.operation_id ||
    !portable_book_id_valid(reply.operation_id) ||
    reply.filename != session.filename ||
    !reply.filename.has_suffix(".moonbook-agent") ||
    !portable_book_path_valid(reply.filename) ||
    reply.filename.contains("/") ||
    !["inspected", "importing", "imported", "uncertain", "partial", "invalid"].contains(
      reply.status,
    ) {
    return None
  }
  // Reuse the complete package-proof decoder, including all member lengths,
  // digests, identity fields and counts. This does not create export provenance.
  let proof : Json = {
    "workspace_id": "local-import",
    "expected_library": reply.expected_library,
    "export_id": reply.operation_id,
    "path": reply.filename,
    "inspection": ToJson::to_json(reply.inspection),
    "verification": ToJson::to_json(reply.verification),
    "source": ToJson::to_json(reply.source),
  }
  guard portable_book_decode_prepared(
      proof,
      session.library,
      "local-import",
      session.operation_id,
    )
    is Some(_) else {
    return None
  }
  if session.reply is Some(previous) &&
    (
      ToJson::to_json(previous.source) != ToJson::to_json(reply.source) ||
      ToJson::to_json(previous.inspection) != ToJson::to_json(reply.inspection) ||
      previous.town_binding != reply.town_binding
    ) {
    return None
  }
  if session.exact_required {
    if handoff_text(reply.town_binding, "contract") !=
      "moontown.portable-listing-binding.v1" ||
      handoff_text(reply.town_binding, "binding_digest") !=
      session.binding_digest ||
      !portable_book_sha_valid(session.binding_digest) ||
      handoff_text(
        handoff_field(reply.town_binding, "source"),
        "package_sha256",
      ) !=
      reply.source.package_sha256 {
      return None
    }
    if reply.status == "imported" &&
      (
        handoff_text(reply.exact_import_receipt, "contract") !=
        "moonbook.portable_import_receipt.v1" ||
        handoff_text(reply.exact_import_receipt, "status") != "complete" ||
        handoff_text(reply.exact_import_receipt, "binding_digest") !=
        session.binding_digest ||
        handoff_field(reply.exact_import_receipt, "member_bytes_verified") !=
        true.to_json()
      ) {
      return None
    }
    if reply.status == "imported" {
      for
        key in [
          "source", "listing_id", "publisher_principal_id", "tenant_id", "binding_digest",
        ] {
        if handoff_field(reply.exact_import_receipt, key) !=
          handoff_field(reply.town_binding, key) {
          return None
        }
      }
      if handoff_text(reply.exact_import_receipt, "local_book_id") !=
        reply.destination_folder ||
        handoff_text(reply.exact_import_receipt, "local_target_root") !=
        session.library + "/" + reply.destination_folder {
        return None
      }
    }
  } else if !(reply.town_binding is Null) ||
    !(reply.exact_import_receipt is Null) {
    return None
  }
  if session.reviewed_sha != "" &&
    reply.source.package_sha256 != session.reviewed_sha {
    return None
  }
  if session.import_started &&
    !(reply.status == "inspected" && reply.destination_folder == "") &&
    reply.destination_folder != session.destination {
    return None
  }
  if reply.status == "imported" {
    guard session.import_started &&
      reply.created is Some(created) &&
      reply.import_verification is Some(members) &&
      members.ok &&
      members.changed_members.is_empty() &&
      agent_import_destination_valid(reply.destination_folder) &&
      created.workspace_id == @desk.stable_id("book", reply.destination_folder) &&
      created.book_id != "" &&
      created.name != "" &&
      created.path == "wiki/index.md" else {
      return None
    }
  } else if reply.created is Some(_) {
    return None
  }
  Some(reply)
}

///|
fn agent_import_invalidate(state : AgentImportState) -> AgentImportState {
  let session = state.session
  {
    ..state,
    generation: state.generation + 1,
    pending: None,
    package_file: None,
    session: if state.pending
      is Some({ operation: PickingPackage | PickingBinding, .. }) ||
      session.status == "awaiting-binding" {
      init_agent_import_session(session.library)
    } else if state.pending is Some(_) {
      {
        ..session,
        status: "uncertain",
        error: "The response was interrupted. Check the retained operation before continuing.",
      }
    } else {
      session
    },
  }
}
