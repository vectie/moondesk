///|
const LivingArtifactContract : String = "moondesk.living-artifact.v1"

///|
const LivingArtifactMaxRecords : Int = 256

///|
const LivingArtifactMaxItems : Int = 1_000

///|
let living_artifact_write_mutex : @async.Mutex = Mutex()

///|
fn living_artifact_id(prefix : String, seed : String) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  prefix + "-" + digest[:20].to_owned()
}

///|
fn living_artifacts_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "artifacts/living.v1.json",
  )
}

///|
fn living_artifact_kind_valid(kind : String) -> Bool {
  ["checklist", "tracker", "evidence-table"].contains(kind)
}

///|
fn living_artifact_item(
  artifact_id : String,
  label : String,
  value : String,
  source : String,
  now : String,
  ordinal : Int,
) -> Result[Json, String] {
  let label = label.trim().to_owned()
  let value = value.trim().to_owned()
  let source = source.trim().to_owned()
  if label == "" ||
    label.length() > 500 ||
    value.length() > 4_000 ||
    source.length() > 4_096 {
    return Err("invalid_living_artifact_item")
  }
  Ok({
    "id": living_artifact_id(
      "living-item",
      artifact_id + ":" + label + ":" + now + ":" + ordinal.to_string(),
    ),
    "label": label,
    "value": value,
    "source": source,
    "done": false,
    "created_at": now,
    "updated_at": now,
  })
}

///|
fn living_artifact_create(payload : Json, now : String) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let title = json_string(payload, "title", default="").trim().to_owned()
  let kind = json_string(payload, "kind", default="checklist").trim().to_owned()
  let purpose = json_string(payload, "purpose", default="").trim().to_owned()
  if workspace_id == "" ||
    title == "" ||
    title.length() > 160 ||
    !living_artifact_kind_valid(kind) ||
    purpose.length() > 2_000 {
    return Err("invalid_living_artifact")
  }
  let artifact_id = living_artifact_id(
    "living-artifact",
    workspace_id + ":" + kind + ":" + title + ":" + now,
  )
  let items : Array[Json] = []
  for label in json_string_array_items(payload, "items") {
    if items.length() >= LivingArtifactMaxItems {
      break
    }
    match
      living_artifact_item(artifact_id, label, "", "", now, items.length()) {
      Ok(item) => items.push(item)
      Err(_) => ()
    }
  }
  let relative_path = "book/site/generated/living/" +
    artifact_id +
    "/index.html"
  Ok({
    "contract": LivingArtifactContract,
    "id": artifact_id,
    "workspace_id": workspace_id,
    "title": title,
    "kind": kind,
    "purpose": purpose,
    "path": relative_path,
    "status": "active",
    "revision": 1,
    "items": Json::array(items),
    "created_at": now,
    "updated_at": now,
  })
}

///|
fn living_artifact_find(records : Array[Json], id : String) -> Json? {
  for record in records {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn living_artifact_apply_command(
  record : Json,
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let action = json_string(payload, "command", default="")
  let item_id = json_string(payload, "item_id", default="").trim().to_owned()
  let current_items = json_array_items(record, "items")
  let next_items : Array[Json] = match action {
    "add-item" => {
      if current_items.length() >= LivingArtifactMaxItems {
        return Err("living_artifact_item_limit")
      }
      let item = living_artifact_item(
        json_string(record, "id", default=""),
        json_string(payload, "label", default=""),
        json_string(payload, "value", default=""),
        json_string(payload, "source", default=""),
        now,
        current_items.length(),
      )
      match item {
        Ok(value) => [value, ..current_items]
        Err(error) => return Err(error)
      }
    }
    "toggle-item" => {
      if item_id == "" ||
        !current_items.any(item => {
          json_string(item, "id", default="") == item_id
        }) {
        return Err("living_artifact_item_not_found")
      }
      current_items.map(item => {
        if json_string(item, "id", default="") == item_id {
          let toggled = @mooncore.session_with_field(
            item,
            "done",
            (!json_bool(item, "done", default=false)).to_json(),
          )
          @mooncore.session_with_field(toggled, "updated_at", now.to_json())
        } else {
          item
        }
      })
    }
    "set-value" => {
      let value = json_string(payload, "value", default="").trim().to_owned()
      if item_id == "" ||
        value.length() > 4_000 ||
        !current_items.any(item => {
          json_string(item, "id", default="") == item_id
        }) {
        return Err("living_artifact_item_not_found")
      }
      current_items.map(item => {
        if json_string(item, "id", default="") == item_id {
          let changed = @mooncore.session_with_field(
            item,
            "value",
            value.to_json(),
          )
          @mooncore.session_with_field(changed, "updated_at", now.to_json())
        } else {
          item
        }
      })
    }
    _ => return Err("invalid_living_artifact_command")
  }
  let with_items = @mooncore.session_with_field(
    record,
    "items",
    Json::array(next_items),
  )
  let with_revision = @mooncore.session_with_field(
    with_items,
    "revision",
    (json_int(record, "revision", default=0) + 1).to_json(),
  )
  @mooncore.session_with_field(with_revision, "updated_at", now.to_json()) |> Ok
}

///|
fn living_artifact_shell(artifact_id : String) -> String {
  let id = artifact_id.to_json().stringify()
  let shell =
    $|<!doctype html>
    $|<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    $|<title>Living artifact</title><style>
    $|:root{font-family:Inter,system-ui,sans-serif;color:#24364a;background:#f5f7fa}*{box-sizing:border-box}body{margin:0;padding:28px}main{max-width:900px;margin:auto}.eyebrow{color:#64748b;font-size:11px;font-weight:800;text-transform:uppercase}h1{margin:5px 0 4px;font-size:28px}p{color:#64748b}.toolbar,form,.item{display:flex;gap:8px;align-items:center}.toolbar{justify-content:space-between;margin:20px 0}form{margin:16px 0}input{min-height:38px;padding:8px 10px;border:1px solid #cbd5e1;border-radius:8px;background:#fff}form input:first-child{flex:1}button{min-height:38px;padding:8px 12px;border:0;border-radius:8px;background:#315f91;color:#fff;cursor:pointer}.items{display:grid;gap:8px}.item{padding:12px;border:1px solid #dbe3ec;border-radius:10px;background:#fff}.item.done{opacity:.6}.item label{min-width:0;flex:1}.item strong{display:block}.item small{color:#7b8795}.item .value{width:min(280px,38vw)}.empty{padding:28px;border:1px dashed #cbd5e1;border-radius:10px;text-align:center}.status{font-size:12px;color:#64748b}@media(max-width:650px){body{padding:16px}.item,form{align-items:stretch;flex-direction:column}.item .value{width:100%}}
    $|</style></head><body><main><div class="eyebrow" id="kind">Living artifact</div><h1 id="title">Loading…</h1><p id="purpose"></p><div class="toolbar"><span class="status" id="status">Connecting to MoonDesk…</span><span class="status" id="count"></span></div><form id="add"><input name="label" required maxlength="500" placeholder="Add an item"><input name="value" maxlength="4000" placeholder="Value or note"><button>Add</button></form><div class="items" id="items"></div></main><script>
    $|const artifactId=\{id};const contract='moondesk.living-artifact-message.v1';let state=null;const send=(type,detail={})=>parent.postMessage({contract,type,artifact_id:artifactId,...detail},'*');const esc=value=>String(value??'');function render(){if(!state)return;document.title=state.title;document.querySelector('#kind').textContent=String(state.kind||'living artifact').replace('-', ' ');document.querySelector('#title').textContent=state.title;document.querySelector('#purpose').textContent=state.purpose||'';document.querySelector('#status').textContent='Saved in this MoonBook';const items=Array.isArray(state.items)?state.items:[];document.querySelector('#count').textContent=`${items.length} item${items.length===1?'':'s'}`;const root=document.querySelector('#items');root.replaceChildren();if(!items.length){const empty=document.createElement('div');empty.className='empty';empty.textContent='Add the first item to make this artifact useful.';root.append(empty);return}for(const item of items){const row=document.createElement('div');row.className=`item${item.done?' done':''}`;const toggle=document.createElement('input');toggle.type='checkbox';toggle.checked=Boolean(item.done);toggle.addEventListener('change',()=>send('command',{command:'toggle-item',item_id:item.id}));const label=document.createElement('label');const strong=document.createElement('strong');strong.textContent=esc(item.label);const source=document.createElement('small');source.textContent=item.source?`Source: ${esc(item.source)}`:'';label.append(strong,source);const value=document.createElement('input');value.className='value';value.value=esc(item.value);value.placeholder='Value or note';value.maxLength=4000;value.addEventListener('change',()=>send('command',{command:'set-value',item_id:item.id,value:value.value}));row.append(toggle,label,value);root.append(row)}}window.addEventListener('message',event=>{const value=event.data||{};if(value.contract!=='moondesk.living-artifact-host.v1'||value.artifact_id!==artifactId)return;state=value.artifact;render()});document.querySelector('#add').addEventListener('submit',event=>{event.preventDefault();const data=new FormData(event.currentTarget);send('command',{command:'add-item',label:data.get('label'),value:data.get('value')});event.currentTarget.reset()});send('ready');
    $|</script></body></html>
  shell
}

///|
async fn write_living_artifact_records(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = living_artifacts_path(workspace_root)
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
    ".living-artifacts." +
    @desk.stable_id("living-artifact-write", @async.now().to_string()) +
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
async fn write_living_artifact_shell(
  workspace_root : String,
  workspace_id : String,
  record : Json,
) -> Unit {
  guard find_workspace(workspace_root, workspace_id) is Some(workspace) else {
    fail("unknown_workspace")
  }
  let relative_path = json_string(record, "path", default="")
  guard relative_path.has_prefix("book/site/generated/living/") &&
    relative_path.has_suffix("/index.html") &&
    resolve_workspace_write_path(workspace.root_path, relative_path)
    is Some((path, _)) else {
    fail("invalid_living_artifact_path")
  }
  let parent = @pathx.dirname(path).to_owned()
  @fsx.make_directory(parent, recursive=true, exists_ok=true)
  let content = living_artifact_shell(json_string(record, "id", default=""))
  let temp = @pathx.join(
    parent,
    ".index." +
    @desk.stable_id("living-shell", @async.now().to_string()) +
    ".tmp",
  )
  @fs.write_file(
    temp,
    @encoding/utf8.encode(content),
    create_mode=CreateNew,
    permission=0o644,
    sync=Full,
  )
  @fs.rename(temp, path, replace=true)
  @fs.chmod(path, 0o644)
}

///|
async fn apply_living_artifact(
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
  living_artifact_write_mutex.acquire()
  defer living_artifact_write_mutex.release()
  let path = living_artifacts_path(workspace_root)
  let records = read_json_array_file(path)
  let action = json_string(payload, "action", default="create")
  let record = if action == "create" {
    living_artifact_create(payload, now)
  } else if action == "command" {
    let id = json_string(payload, "id", default="").trim().to_owned()
    match living_artifact_find(records, id) {
      Some(current) =>
        if json_string(current, "workspace_id", default="") == workspace_id {
          living_artifact_apply_command(current, payload, now)
        } else {
          Err("living_artifact_not_found")
        }
      None => Err("living_artifact_not_found")
    }
  } else {
    Err("invalid_living_artifact_action")
  }
  let record = match record {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let next = upsert_record_by_id(records, record)
  while next.length() > LivingArtifactMaxRecords {
    next.pop() |> ignore
  }
  if action == "create" {
    write_living_artifact_shell(workspace_root, workspace_id, record) catch {
      _ => return Err("living_artifact_shell_write_failed")
    }
  }
  write_living_artifact_records(workspace_root, next)
  Ok(record)
}

///|
async fn handle_living_artifacts(
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
  let id = decode_query_value(query_value(request_path, "id").unwrap_or(""))
    .trim()
    .to_owned()
  if workspace_id == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id is required",
    )
    return
  }
  let artifacts = read_json_array_file(living_artifacts_path(workspace_root)).filter(record => {
      json_string(record, "workspace_id", default="") == workspace_id &&
      (id == "" || json_string(record, "id", default="") == id)
    },
  )
  send_json(conn, method_, {
    "contract": "moondesk.living-artifacts.v1",
    "workspace_id": workspace_id,
    "artifacts": Json::array(artifacts),
  })
}

///|
async fn handle_update_living_artifact(
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
    apply_living_artifact(workspace_root, payload, @async.now().to_string()) {
    Ok(record) => send_json(conn, method_, record)
    Err("unknown_workspace") =>
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    Err("living_artifact_not_found") =>
      send_api_error(
        conn, method_, 404, "Not Found", "Living artifact not found",
      )
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}
