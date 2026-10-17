///|
/// Read-only inspection of the existing native single-step protocol. The
/// browser supplies identities and an ordinal, never a filesystem locator.
struct MoonFlowRetainedResult {
  metadata : Json
  bytes : Bytes
}

///|
fn moonflow_retained_sha(bytes : Bytes) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
async fn moonflow_retained_bytes(root : String, reference : String) -> Bytes {
  guard !root.contains("\u0000") &&
    reference != "" &&
    reference.length() <= 4096 &&
    !reference.contains("\\") &&
    !reference.contains(":") &&
    !reference.contains("\u0000") else {
    fail("Unsupported retained reference")
  }
  let mut path = root
  let parts = reference.split("/").to_array()
  for index, part in parts {
    guard part != "" && part != "." && part != ".." else {
      fail("Unsupported retained reference")
    }
    path += "/" + part.to_owned()
    guard @fs.exists(path) else { fail("Retained bytes are missing") }
    guard @fs.realpath(path) == path &&
      @fs.kind(path, follow_symlink=false) ==
      (if index == parts.length() - 1 { Regular } else { Directory }) else {
      fail("Retained reference is unsafe or has changed")
    }
  }
  let output = FixedArray::make(4 * 1024 * 1024 + 1, b'0')
  let count = moonflow_retained_read_native(
    @encoding/utf8.encode(root + "\u0000"),
    @encoding/utf8.encode(reference + "\u0000"),
    output,
    output.length(),
  )
  guard count != -2 else {
    fail("Unsupported platform for confined retained result reads")
  }
  guard count >= 0 else {
    fail("Retained file missing, unsafe, changed, or unsupported above 4 MiB")
  }
  output.unsafe_reinterpret_as_bytes()[:count].to_owned()
}

///|
#borrow(root, relative, output)
extern "c" fn moonflow_retained_read_native(
  root : Bytes,
  relative : Bytes,
  output : FixedArray[Byte],
  capacity : Int32,
) -> Int32 = "moonbit_moondesk_retained_read"

///|
fn moonflow_retained_same(
  left : Json,
  right : Json,
  keys : Array[String],
) -> Bool {
  keys.all(key => {
    json_object_field(left, key) is Some(value) &&
    value != Json::null() &&
    json_object_field(right, key) == Some(value)
  })
}

///|
async fn moonflow_retained_result(
  suite_root : String,
  workspace : @desk.DeskWorkspace,
  identity : Json,
) -> MoonFlowRetainedResult {
  guard ["run_id", "work_item_id", "attempt_id", "result_id", "action_id"].all(key => {
      moonflow_single_step_identifier(json_string(identity, key, default=""))
    }) &&
    json_string(identity, "workspace_id", default="") == workspace.id &&
    @fs.realpath(suite_root) == suite_root &&
    @fs.realpath(workspace.root_path) == workspace.root_path &&
    workspace.root_path.has_prefix(suite_root + "/") else {
    fail("Invalid or changed selected Book/result identity")
  }
  let run_id = json_string(identity, "run_id", default="")
  let item_id = json_string(identity, "work_item_id", default="")
  let prefix = ".moonsuite/products/moonflow/runs/" + run_id
  let record_refs = [
    prefix + "/projection.json",
    prefix + "/events.json",
    prefix + "/single-step/" + item_id + ".action.json",
    prefix + "/single-step/" + item_id + ".request.json",
    prefix + "/single-step/" + item_id + ".result.json",
    prefix + "/single-step/" + item_id + ".evidence.json",
    prefix +
    "/single-step/request-" +
    json_string(identity, "action_id", default="") +
    ".json",
  ]
  let records : Array[Bytes] = []
  for reference in record_refs {
    records.push(moonflow_retained_bytes(suite_root, reference))
  }
  let values = records.map(bytes => @json.parse(@encoding/utf8.decode(bytes)))
  // Bind download to the exact observation as well as the selected bytes.
  // This detects a changed evidence manifest even if its selected file remains
  // identical. It is an observation seal, not an adapter signature.
  let record_digest = moonflow_retained_sha(
    @encoding/utf8.encode(
      records.map(moonflow_retained_sha).to_json().stringify(),
    ),
  )
  let projection = values[0]
  let events = values[1]
  let action = values[2]
  let request = values[3]
  let result = values[4]
  let manifest = values[5]
  let index = values[6]
  guard json_string(projection, "protocol", default="") ==
    "moonflow.run-projection.v3" &&
    json_string(projection, "run_id", default="") == run_id &&
    moonflow_single_step_book_matches(workspace, projection) &&
    moonflow_owner_summary_observation(projection, Some(events)) ==
    "event-head-matched" else {
    fail("Retained run does not match this Book or its persisted event head")
  }
  let items = moonflow_graph_items(projection).filter(item => {
    json_string(item, "work_item_id", default="") == item_id
  })
  guard items.length() == 1 else {
    fail("Selected retained item is missing or ambiguous")
  }
  let item = items[0]
  guard json_string(item, "product_id", default="") == "moonmold" &&
    json_string(item, "operation", default="") ==
    "moonmold/spatial.operation.execute@0.2.0" &&
    json_string(item, "requested_authority", default="") == "workspace-mutation" &&
    json_string(item, "required_claim", default="") == "digital-artifact" &&
    json_object_field(item, "input_contracts") ==
    Some(["moonmold/spatial-operation-request@1.0.0"].to_json()) &&
    json_object_field(item, "output_contracts") ==
    Some(["moonmold/spatial-operation-receipt@1.0.0"].to_json()) else {
    fail(
      "Unsupported result protocol: only the existing native single-step Mold operation can be inspected",
    )
  }
  guard json_string(action, "contract_id", default="") ==
    "moonflow.single-step-action.v1" &&
    json_string(action, "status", default="") == "review" &&
    json_string(action, "request_id", default="") ==
    json_string(identity, "action_id", default="") &&
    moonflow_retained_same(action, projection, ["run_id", "source_digest"]) &&
    moonflow_retained_same(action, item, ["work_item_id"]) &&
    moonflow_retained_same(index, action, ["work_item_id", "request_id"]) &&
    json_object_field(action, "adapter_request") == Some(request) &&
    moonflow_retained_same(request, projection, ["run_id", "book_id"]) &&
    moonflow_retained_same(request, item, [
      "work_item_id", "request_id", "idempotency_key", "input_digest", "product_id",
      "operation", "input_contracts", "output_contracts", "required_claim",
    ]) &&
    moonflow_retained_same(result, request, [
      "request_id", "attempt_id", "idempotency_key", "product_id",
    ]) &&
    moonflow_retained_same(result, item, [
      "result_id", "output_digest", "external_job_id",
    ]) &&
    moonflow_retained_same(identity, result, ["attempt_id", "result_id"]) &&
    json_string(item, "active_attempt_id", default="") ==
    json_string(result, "attempt_id", default="") &&
    json_string(item, "attempt_status", default="") == "succeeded" &&
    json_string(result, "status", default="") == "succeeded" else {
    fail(
      "Retained action, request, attempt or result identity changed or does not match",
    )
  }
  let outputs = json_array_items(result, "output_artifacts")
  guard !outputs.is_empty() &&
    outputs.length() <= 64 &&
    json_object_field(item, "artifacts") == Some(outputs.to_json()) &&
    manifest is Array(observations) &&
    observations.length() == outputs.length() else {
    fail(
      "Flow's retained per-file evidence is missing or does not match the result",
    )
  }
  let ordinal = json_int(identity, "artifact_index", default=-1)
  guard ordinal >= 0 && ordinal < outputs.length() else {
    fail("Unknown retained output selection")
  }
  let receipt_ref = ".moonsuite/products/moonmold/adapter-attempts/" +
    json_string(result, "attempt_id", default="") +
    "/operation-receipt.json"
  guard outputs[0] == receipt_ref.to_json() else {
    fail("Unsupported adapter receipt location")
  }
  let receipt_bytes = moonflow_retained_bytes(suite_root, receipt_ref)
  let digest = moonflow_retained_sha(receipt_bytes)
  guard digest == json_string(result, "output_digest", default="") else {
    fail("Adapter receipt byte identity changed")
  }
  let receipt = @json.parse(@encoding/utf8.decode(receipt_bytes))
  let qualification = json_object_field(receipt, "backend_qualification").unwrap_or(
    Json::null(),
  )
  guard json_string(receipt, "contract_id", default="") ==
    "moonmold.spatial-operation-receipt.v1" &&
    json_string(receipt, "operation_ref", default="") ==
    json_string(request, "operation", default="") &&
    moonflow_retained_same(receipt, request, [
      "request_id", "attempt_id", "idempotency_key",
    ]) &&
    ["applied", "idempotent-no-op"].contains(
      json_string(receipt, "outcome", default=""),
    ) &&
    json_string(receipt, "claim_ceiling", default="") == "digital-artifact" &&
    !json_bool(receipt, "physical_authority", default=true) &&
    json_bool(receipt, "review_required", default=false) &&
    json_object_field(receipt, "artifacts") ==
    Some(outputs[1:].to_owned().to_json()) &&
    json_string(qualification, "evidence_class", default="") ==
    "fixture-reference-only" &&
    !json_bool(qualification, "production_qualified", default=true) &&
    !json_bool(qualification, "blender_evidence", default=true) &&
    !json_bool(qualification, "physical_authority", default=true) else {
    fail("Retained receipt correlation or digital reference boundary differs")
  }
  guard events is Array(history) &&
    history.any(event => {
      json_string(event, "kind", default="") == "attempt-reconciled" &&
      moonflow_retained_same(event, result, [
        "result_id", "request_id", "attempt_id", "idempotency_key", "output_digest",
        "output_artifacts",
      ]) &&
      moonflow_retained_same(event, item, ["work_item_id", "attempt_status"])
    }) else {
    fail("The retained result has no matching persisted terminal event")
  }
  let seen : Array[String] = []
  let mut selected = b""
  let mut reference = ""
  let mut selected_digest = ""
  let mut total_bytes = 0
  for output_index, output in outputs {
    guard output is String(ref_) && !seen.contains(ref_) else {
      fail("Ambiguous retained output references")
    }
    seen.push(ref_)
    let observation = observations[output_index]
    guard json_string(observation, "reference", default="") == ref_ else {
      fail("Flow's retained per-file evidence references changed")
    }
    // Validate all outputs: a changed companion or manifest prevents a stale
    // inspection/download from claiming that this result remains intact.
    let bytes = if output_index == 0 {
      receipt_bytes
    } else {
      moonflow_retained_bytes(suite_root, ref_)
    }
    total_bytes += bytes.length()
    guard total_bytes <= 16 * 1024 * 1024 else {
      fail(
        "Unsupported retained result above the 16 MiB total inspection limit",
      )
    }
    let sha = moonflow_retained_sha(bytes)
    guard sha == json_string(observation, "sha256", default="") &&
      bytes.length() == json_int(observation, "byte_length", default=-1) else {
      fail(
        "Flow-recorded artifact byte identity changed or its evidence manifest differs",
      )
    }
    if output_index == ordinal {
      selected = bytes
      reference = ref_
      selected_digest = sha
    }
  }
  for record_index, ref_ in record_refs {
    guard moonflow_retained_bytes(suite_root, ref_) == records[record_index] else {
      fail(
        "Retained result records changed during inspection; refresh this selection",
      )
    }
  }
  let preview = @encoding/utf8.decode(selected) catch { _ => "" }
  let text_supported = @encoding/utf8.encode(preview) == selected &&
    !preview.contains("\u0000")
  let limit = 32768
  let parsed_preview = @json.parse(preview) catch { _ => Json::null() }
  let metadata : Json = {
    "contract_id": "moondesk.flow-retained-result.v1",
    "status": "verified",
    "identity": identity,
    "adapter_request_id": json_string(request, "request_id", default=""),
    "reference": reference,
    "sha256": selected_digest,
    "record_digest": record_digest,
    "byte_length": selected.length(),
    "identity_scope": if ordinal == 0 {
      "Adapter receipt byte identity"
    } else {
      "Flow-recorded artifact byte identity"
    },
    "preview_kind": if text_supported {
      if parsed_preview is (Object(_) | Array(_)) {
        "json"
      } else {
        "text"
      }
    } else {
      "binary"
    },
    "preview_text": if text_supported {
      preview[:limit].to_owned()
    } else {
      "Binary content has no text preview. Download preserves the exact retained bytes."
    },
    "preview_truncated": text_supported && preview.length() > limit,
    "qualification": qualification,
  }
  { metadata, bytes: selected, }
}

///|
async fn handle_moonflow_retained_result(
  workspace_root : String,
  identity : Json,
  expected_digest : String?,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let result = try {
    guard find_workspace(
        workspace_root,
        json_string(identity, "workspace_id", default=""),
      )
      is Some(workspace) else {
      fail("Select a registered Book before inspecting retained results")
    }
    moonflow_retained_result(
      @fs.realpath(workspace_context(workspace_root).suite_root),
      workspace,
      identity,
    )
  } catch {
    error => {
      if expected_digest is Some(_) {
        send_api_error(conn, method_, 409, "Conflict", error.to_string())
      } else {
        send_json(conn, method_, {
          "contract_id": "moondesk.flow-retained-result.v1",
          "status": "unavailable",
          "identity": identity,
          "message": error.to_string(),
        })
      }
      return
    }
  }
  match expected_digest {
    None => send_json(conn, method_, result.metadata)
    Some(expected) => {
      let binding = json_string(result.metadata, "sha256", default="")[7:].to_owned() +
        "-" +
        json_string(result.metadata, "record_digest", default="")[7:].to_owned()
      guard expected == binding else {
        send_api_error(
          conn, method_, 409, "Conflict", "Retained bytes or observation records changed since inspection",
        )
        return
      }
      conn.send_response(200, "OK", extra_headers={
        "content-type": "application/octet-stream",
        "cache-control": "no-store",
        "content-disposition": "attachment; filename=retained-result.bin",
        "x-content-type-options": "nosniff",
      })
      if method_ != Head {
        conn.write(result.bytes)
      }
      conn.end_response()
    }
  }
}
