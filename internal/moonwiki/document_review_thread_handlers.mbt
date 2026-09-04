///|
const DocumentReviewThreadMaxRecords : Int = 1000

///|
let document_review_write_mutex : @async.Mutex = Mutex()

///|
fn document_review_threads_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "collaboration/document-review-threads.v1.json",
  )
}

///|
fn document_review_record_with_anchor_state(
  record : Json,
  current_baseline : String,
) -> Json {
  let baseline = json_string(record, "document_baseline", default="")
  @mooncore.session_with_field(
    record,
    "anchor_status",
    (if current_baseline == "" || baseline == "" || baseline == current_baseline {
      "current"
    } else {
      "stale"
    }).to_json(),
  )
}

///|
fn document_review_counts(
  records : Array[Json],
  viewer_id : String,
  last_read_at : String,
) -> Json {
  let open_count = records
    .filter(record => {
      json_string(record, "kind", default="") == "thread" &&
      json_string(record, "status", default="open") != "resolved"
    })
    .length()
  let unread_count = if viewer_id == "" {
    0
  } else {
    records
    .filter(record => {
      json_string(record, "updated_at", default="").compare(last_read_at) > 0 &&
      json_string(record, "author_id", default="") != viewer_id
    })
    .length()
  }
  let required_action_count = records
    .filter(record => {
      json_string(record, "kind", default="") == "thread" &&
      json_string(record, "status", default="open") != "resolved" &&
      json_string(record, "assigned_to", default="") != ""
    })
    .length()
  {
    "open_count": open_count,
    "unread_count": unread_count,
    "required_action_count": required_action_count,
  }
}

///|
async fn handle_document_review_threads(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_id = decode_query_value(
    query_value(request_path, "workspace_id").unwrap_or(""),
  )
  let document_path = decode_query_value(
    query_value(request_path, "document_path").unwrap_or(""),
  )
  let baseline = decode_query_value(
    query_value(request_path, "baseline").unwrap_or(""),
  )
  let viewer_id = decode_query_value(
    query_value(request_path, "viewer_id").unwrap_or(""),
  )
  if workspace_id == "" || document_path == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id and document_path are required",
    )
    return
  }
  let all_records = read_json_array_file(
    document_review_threads_path(workspace_root),
  )
  let mut last_read_at = ""
  for record in all_records {
    if json_string(record, "kind", default="") == "read_receipt" &&
      json_string(record, "workspace_id", default="") == workspace_id &&
      json_string(record, "document_path", default="") == document_path &&
      json_string(record, "viewer_id", default="") == viewer_id {
      last_read_at = json_string(record, "read_at", default="")
      break
    }
  }
  let records = all_records
    .filter(record => {
      json_string(record, "workspace_id", default="") == workspace_id &&
      json_string(record, "document_path", default="") == document_path &&
      ["thread", "reply"].contains(json_string(record, "kind", default=""))
    })
    .map(record => document_review_record_with_anchor_state(record, baseline))
  let counts = document_review_counts(records, viewer_id, last_read_at)
  send_json(conn, method_, {
    "contract": "moondesk.document_review_threads.v1",
    "threads": Json::array(records),
    "open_count": json_int(counts, "open_count", default=0),
    "unread_count": json_int(counts, "unread_count", default=0),
    "required_action_count": json_int(
      counts,
      "required_action_count",
      default=0,
    ),
  })
}

///|
async fn handle_save_document_review_thread(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let action = json_string(payload, "action", default="create")
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let document_path = json_string(payload, "document_path", default="")
    .trim()
    .to_owned()
  let detail = json_string(payload, "detail", default="").trim().to_owned()
  let thread_id = json_string(payload, "thread_id", default="")
    .trim()
    .to_owned()
  if workspace_id == "" ||
    document_path == "" ||
    (!["resolve", "mark-read"].contains(action) && detail == "") {
    send_api_error(
      conn, method_, 400, "Bad Request", "Review thread fields are required",
    )
    return
  }
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  if resolve_workspace_existing_path(workspace.root_path, document_path) is None {
    send_api_error(
      conn, method_, 400, "Bad Request", "Document is outside this workspace",
    )
    return
  }
  let path = document_review_threads_path(workspace_root)
  document_review_write_mutex.acquire()
  defer document_review_write_mutex.release()
  let records = read_json_array_file(path)
  if action == "mark-read" {
    let viewer_id = json_string(payload, "viewer_id", default="")
      .trim()
      .to_owned()
    if viewer_id == "" || viewer_id.length() > 160 {
      send_api_error(conn, method_, 400, "Bad Request", "viewer_id is required")
      return
    }
    let receipt_id = @desk.stable_id(
      "document-review-read",
      workspace_id + ":" + document_path + ":" + viewer_id,
    )
    let receipt : Json = {
      "id": receipt_id,
      "contract": "moondesk.document_review_read_receipt.v1",
      "kind": "read_receipt",
      "workspace_id": workspace_id,
      "document_path": document_path,
      "viewer_id": viewer_id,
      "read_at": @async.now().to_string(),
    }
    write_preference_records(path, upsert_record_by_id(records, receipt))
    send_json(conn, method_, receipt)
    return
  }
  let mut parent : Json? = None
  for record in records {
    if json_string(record, "id", default="") == thread_id &&
      json_string(record, "kind", default="") == "thread" {
      parent = Some(record)
      break
    }
  }
  if ["resolve", "reply"].contains(action) && parent is None {
    send_api_error(conn, method_, 404, "Not Found", "Unknown review thread")
    return
  }
  let parent_revision = match parent {
    Some(record) => json_int(record, "revision", default=0)
    None => 0
  }
  let expected_revision = json_int(
    payload,
    "expected_revision",
    default=parent_revision,
  )
  if expected_revision != parent_revision {
    send_api_json_error(conn, method_, 409, "Conflict", {
      "contract": "moondesk.document_review_thread.v1",
      "error": "revision_conflict",
      "message": "The review discussion changed on another client",
      "thread": parent.unwrap_or(Json::null()),
    })
    return
  }
  if action == "resolve" {
    if thread_id == "" {
      send_api_error(conn, method_, 400, "Bad Request", "thread_id is required")
      return
    }
    let next = records.map(record => {
      if json_string(record, "id", default="") == thread_id &&
        json_string(record, "kind", default="") == "thread" {
        let value = @mooncore.session_with_field(
          record,
          "status",
          "resolved".to_json(),
        )
        let updated = @mooncore.session_with_field(
          value,
          "updated_at",
          @async.now().to_string().to_json(),
        )
        @mooncore.session_with_field(
          updated,
          "revision",
          (parent_revision + 1).to_json(),
        )
      } else {
        record
      }
    })
    write_preference_records(path, next)
    send_json(conn, method_, { "resolved": true, "thread_id": thread_id })
    return
  }
  if action == "reply" && thread_id == "" {
    send_api_error(conn, method_, 400, "Bad Request", "thread_id is required")
    return
  }
  let now = @async.now().to_string()
  let id = @desk.stable_id(
    if action == "reply" {
      "review-reply"
    } else {
      "review-thread"
    },
    workspace_id +
    ":" +
    document_path +
    ":" +
    thread_id +
    ":" +
    now +
    ":" +
    detail,
  )
  let record : Json = {
    "id": id,
    "contract": "moondesk.document_review_thread.v1",
    "kind": if action == "reply" {
      "reply"
    } else {
      "thread"
    },
    "thread_id": if action == "reply" {
      thread_id
    } else {
      id
    },
    "workspace_id": workspace_id,
    "document_path": document_path,
    "document_baseline": json_string(payload, "document_baseline", default=""),
    "anchor": json_string(payload, "anchor", default=""),
    "anchor_kind": json_string(payload, "anchor_kind", default="document"),
    "anchor_label": json_string(payload, "anchor_label", default="Document"),
    "detail": detail,
    "assigned_to": json_string(payload, "assigned_to", default=""),
    "author": json_string(payload, "author", default="You"),
    "author_id": json_string(payload, "author_id", default=""),
    "status": "open",
    "revision": if action == "reply" {
      1
    } else {
      1
    },
    "created_at": now,
    "updated_at": now,
  }
  let next = if action == "reply" {
    [
      record,
      ..records.map(item => {
        if json_string(item, "id", default="") == thread_id &&
          json_string(item, "kind", default="") == "thread" {
          let updated = @mooncore.session_with_field(
            item,
            "updated_at",
            now.to_json(),
          )
          @mooncore.session_with_field(
            updated,
            "revision",
            (parent_revision + 1).to_json(),
          )
        } else {
          item
        }
      }),
    ]
  } else {
    [record, ..records]
  }
  while next.length() > DocumentReviewThreadMaxRecords {
    next.pop() |> ignore
  }
  write_preference_records(path, next)
  send_json(conn, method_, record)
}
