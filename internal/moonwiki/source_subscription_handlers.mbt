///|
const SourceSubscriptionContract : String = "moondesk.source-subscription.v1"

///|
const SourceSubscriptionMaxRecords : Int = 512

///|
const SourceSubscriptionMaxSourceChars : Int = 4_096

///|
const SourceSubscriptionMaxRuleChars : Int = 2_000

///|
let source_subscription_write_mutex : @async.Mutex = Mutex()

///|
fn source_subscriptions_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "sources/subscriptions.v1.json",
  )
}

///|
fn source_subscription_kind_valid(kind : String) -> Bool {
  ["website", "feed", "folder", "repository"].contains(kind)
}

///|
fn source_subscription_cadence_ticks(cadence : String) -> Int {
  match cadence {
    "daily" => 1_440
    "weekly" => 10_080
    "monthly" => 43_200
    _ => 0
  }
}

///|
fn source_subscription_prompt(
  title : String,
  kind : String,
  source : String,
  cadence : String,
  change_rule : String,
) -> String {
  let material_change = if change_rule == "" {
    "Report only a material change that affects the current MoonBook."
  } else {
    change_rule
  }
  "Keep “" +
  title +
  "” current from this " +
  kind +
  ".\n\nSource: " +
  source +
  "\nCheck: " +
  cadence +
  "\nMeaningful change: " +
  material_change +
  "\n\nCompare new material with the accepted book baseline. Put a concise source-backed result in the MoonBook Inbox only when the rule is met. Treat new knowledge as proposed until it is accepted through Learning Review."
}

///|
fn source_subscription_create(
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let kind = json_string(payload, "source_kind", default="website")
    .trim()
    .to_owned()
  let source = json_string(payload, "source", default="").trim().to_owned()
  let title = json_string(payload, "title", default="").trim().to_owned()
  let cadence = json_string(payload, "cadence", default="weekly")
    .trim()
    .to_owned()
  let change_rule = json_string(payload, "change_rule", default="")
    .trim()
    .to_owned()
  let cadence_ticks = source_subscription_cadence_ticks(cadence)
  if workspace_id == "" ||
    !source_subscription_kind_valid(kind) ||
    source == "" ||
    source.length() > SourceSubscriptionMaxSourceChars ||
    title == "" ||
    title.length() > 160 ||
    cadence_ticks == 0 ||
    change_rule.length() > SourceSubscriptionMaxRuleChars {
    return Err("invalid_source_subscription")
  }
  Ok({
    "contract": SourceSubscriptionContract,
    "id": @desk.stable_id(
      "source-subscription",
      workspace_id + ":" + kind + ":" + source + ":" + now,
    ),
    "workspace_id": workspace_id,
    "source_kind": kind,
    "source": source,
    "title": title,
    "cadence": cadence,
    "cadence_ticks": cadence_ticks,
    "change_rule": change_rule,
    "prompt": source_subscription_prompt(
      title, kind, source, cadence, change_rule,
    ),
    "status": "needs_setup",
    "standing_goal_id": "",
    "created_at": now,
    "updated_at": now,
  })
}

///|
fn source_subscription_find(records : Array[Json], id : String) -> Json? {
  for record in records {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn source_subscription_activate(
  records : Array[Json],
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let id = json_string(payload, "id", default="").trim().to_owned()
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let standing_goal_id = json_string(payload, "standing_goal_id", default="")
    .trim()
    .to_owned()
  guard source_subscription_find(records, id) is Some(current) else {
    return Err("source_subscription_not_found")
  }
  if workspace_id == "" ||
    json_string(current, "workspace_id", default="") != workspace_id ||
    standing_goal_id == "" ||
    standing_goal_id.length() > 200 {
    return Err("invalid_source_subscription_activation")
  }
  let active = @mooncore.session_with_field(
    current,
    "status",
    "active".to_json(),
  )
  let linked = @mooncore.session_with_field(
    active,
    "standing_goal_id",
    standing_goal_id.to_json(),
  )
  Ok(@mooncore.session_with_field(linked, "updated_at", now.to_json()))
}

///|
async fn write_source_subscriptions(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = source_subscriptions_path(workspace_root)
  let content = Json::array(records).stringify(indent=2) + "\n"
  if @fsx.exists(path) {
    if @fsx.read_file(path) == content {
      return
    }
  }
  let parent = @pathx.dirname(path).to_owned()
  @fsx.make_directory(parent, recursive=true, exists_ok=true)
  let temp = @pathx.join(
    parent,
    ".source-subscriptions." +
    @desk.stable_id("source-subscription-write", @async.now().to_string()) +
    ".tmp",
  )
  @fs.write_file(
    temp,
    @encoding/utf8.encode(content),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(temp, path, replace=true)
  @fs.chmod(path, 0o600)
}

///|
async fn apply_source_subscription(
  workspace_root : String,
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  if workspace_id == "" {
    return Err("workspace_id_required")
  }
  if find_workspace(workspace_root, workspace_id) is None {
    return Err("unknown_workspace")
  }
  source_subscription_write_mutex.acquire()
  defer source_subscription_write_mutex.release()
  let path = source_subscriptions_path(workspace_root)
  let records = read_json_array_file(path)
  let action = json_string(payload, "action", default="create")
  let record = match action {
    "create" => source_subscription_create(payload, now)
    "activate" => source_subscription_activate(records, payload, now)
    _ => Err("invalid_source_subscription_action")
  }
  let record = match record {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let next = upsert_record_by_id(records, record)
  while next.length() > SourceSubscriptionMaxRecords {
    next.pop() |> ignore
  }
  write_source_subscriptions(workspace_root, next)
  Ok(record)
}

///|
async fn handle_source_subscriptions(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_id = decode_query_value(
      query_value(request_path, "workspace_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if workspace_id == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id is required",
    )
    return
  }
  let subscriptions = read_json_array_file(
    source_subscriptions_path(workspace_root),
  ).filter(record => {
    json_string(record, "workspace_id", default="") == workspace_id
  })
  send_json(conn, method_, {
    "contract": "moondesk.source-subscriptions.v1",
    "workspace_id": workspace_id,
    "subscriptions": Json::array(subscriptions),
  })
}

///|
async fn handle_update_source_subscription(
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
  match
    apply_source_subscription(workspace_root, payload, @async.now().to_string()) {
    Ok(record) => send_json(conn, method_, record)
    Err("unknown_workspace") =>
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    Err("source_subscription_not_found") =>
      send_api_error(
        conn, method_, 404, "Not Found", "Source subscription not found",
      )
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}
