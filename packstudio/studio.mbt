///|
fn safe_identifier(value : String) -> Bool {
  @pack.safe_identifier(value) &&
  value == value.to_lower() &&
  value.length() <= 96
}

///|
fn join_path(left : String, right : String) -> String {
  if left.has_suffix("/") {
    left + right
  } else {
    left + "/" + right
  }
}

///|
async fn ensure_directory(path : String) -> Unit {
  if @fs.exists(path) {
    return
  }
  let parent = @path.Path::dirname(path).to_string()
  if parent != "." && !parent.is_empty() {
    ensure_directory(parent)
  }
  @fs.mkdir(path, permission=0o755) catch {
    _ => ()
  }
}

///|
async fn write_text(path : String, content : String) -> Unit {
  ensure_directory(@path.Path::dirname(path).to_string())
  @fs.write_file(
    path,
    @encoding/utf8.encode(content),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
}

///|
fn authority_name(authority : @pack.AuthorityClass) -> String {
  match authority {
    Observe => "Observe"
    CognitiveMaintenance => "CognitiveMaintenance"
    SandboxExecution => "SandboxExecution"
    WorkspaceMutation => "WorkspaceMutation"
    ExternalEffect => "ExternalEffect"
    PhysicalEffect => "PhysicalEffect"
  }
}

///|
fn bridge_ready(manifest : @pack.MoonPackManifest) -> Bool {
  manifest.provider_ports.any(port => {
    port.id == "moontown-pack-projection" && port.version == "1.0.0"
  }) &&
  manifest.schemas.any(schema => schema.id == "pack-town-projection") &&
  manifest.schemas.any(schema => schema.id == "town-pack-candidate") &&
  manifest.schemas.any(schema => schema.id == "pack-candidate-acknowledgement") &&
  manifest.tools.any(tool => {
    tool.input_schema_id == "town-pack-candidate" &&
    tool.review_required &&
    !(tool.authority is (ExternalEffect | PhysicalEffect))
  })
}

///|
pub async fn inspect_pack_source(
  source_root : String,
  workspace_root : String,
) -> PackStudioInspection {
  let manifest = @installer.load_source_manifest(source_root) catch {
    error =>
      return {
        source_root,
        pack_id: "",
        version: "",
        display_name: "",
        product_id: "",
        valid: false,
        install_ready: false,
        active: false,
        bridge_ready: false,
        intake_operation_ids: [],
        authorities: [],
        issues: ["\{error}"],
      }
  }
  let issues = @installer.validate_source_tree(source_root, manifest)
  let plan = @installer.plan_install(manifest)
  let active = @installer.active_pack(workspace_root, manifest.id)
    is Some(pointer) &&
    pointer.version == manifest.version
  {
    source_root,
    pack_id: manifest.id,
    version: manifest.version,
    display_name: manifest.display_name,
    product_id: manifest.product_id,
    valid: issues.is_empty() && plan.validation.ok,
    install_ready: issues.is_empty() && plan.state is ReadyToStage,
    active,
    bridge_ready: bridge_ready(manifest),
    intake_operation_ids: manifest.tools
    .filter(tool => tool.input_schema_id == "town-pack-candidate")
    .map(tool => tool.id),
    authorities: plan.authorities.map(authority_name),
    issues: issues +
    plan.validation.issues.map(issue => "\{issue.path}: \{issue.message}"),
  }
}

///|
async fn write_bridge_artifacts(
  source_root : String,
  intake_operation_id : String,
) -> Unit {
  write_text(
    source_root + "/schemas/pack-town-projection.schema.json",
    pack_projection_schema_text(),
  )
  write_text(
    source_root + "/schemas/town-pack-candidate.schema.json",
    town_candidate_schema_text(),
  )
  write_text(
    source_root + "/schemas/pack-candidate-acknowledgement.schema.json",
    candidate_acknowledgement_schema_text(),
  )
  write_text(
    source_root + "/providers/moontown-pack-projection.port.md",
    provider_port_text(intake_operation_id),
  )
}

///|
pub async fn create_domain_pack_scaffold(
  request : PackScaffoldRequest,
  workspace_root : String,
) -> PackStudioInspection {
  if !safe_identifier(request.pack_id) ||
    !safe_identifier(request.product_id) ||
    !safe_identifier(request.intake_operation_id) ||
    !safe_identifier(request.output_schema_id) ||
    request.display_name.trim().is_empty() {
    fail("pack, product, operation, schema, and display names must be safe")
  }
  let source_root = join_path(
    request.parent_root.trim().to_owned(),
    request.pack_id,
  )
  if @fs.exists(source_root) {
    fail("pack scaffold target already exists")
  }
  ensure_directory(source_root + "/schemas")
  ensure_directory(source_root + "/providers")
  let manifest : @pack.MoonPackManifest = {
    id: request.pack_id,
    version: "0.1.0",
    display_name: request.display_name,
    product_id: request.product_id,
    kind: DomainPack,
    required_runtime_extensions: ["moontown"],
    book_templates: [],
    schemas: [
      @pack.contract_ref(
        request.output_schema_id,
        "1.0.0",
        "schemas/" + request.output_schema_id + ".schema.json",
      ),
      @pack.contract_ref(
        "pack-town-projection", "1.0.0", "schemas/pack-town-projection.schema.json",
      ),
      @pack.contract_ref(
        "town-pack-candidate", "1.0.0", "schemas/town-pack-candidate.schema.json",
      ),
      @pack.contract_ref(
        "pack-candidate-acknowledgement", "1.0.0", "schemas/pack-candidate-acknowledgement.schema.json",
      ),
    ],
    tools: [
      @pack.tool_declaration(
        request.intake_operation_id,
        request.product_id,
        "town-pack-candidate",
        request.output_schema_id,
        WorkspaceMutation,
        evidence_outputs=["records/candidate-intake"],
        review_required=true,
      ),
    ],
    workflows: [],
    skills: [],
    policies: [],
    provider_ports: [
      @pack.contract_ref(
        "moontown-pack-projection", "1.0.0", "providers/moontown-pack-projection.port.md",
      ),
    ],
    schedules: [],
    app_entrypoints: [],
    migrations: [],
    evaluations: [],
    uninstall_contract: Some(
      @pack.contract_ref("uninstall", "1.0.0", "UNINSTALL.md"),
    ),
  }
  write_text(source_root + "/pack.json", @pack.encode_manifest(manifest))
  write_text(
    source_root + "/schemas/" + request.output_schema_id + ".schema.json",
    domain_schema_text(request.output_schema_id),
  )
  write_bridge_artifacts(source_root, request.intake_operation_id)
  write_text(
    source_root + "/UNINSTALL.md",
    "# Uninstall\n\nDeactivate the pack and preserve records and evidence.\n",
  )
  write_text(
    source_root + "/README.md",
    "# " +
    request.display_name +
    "\n\nDomain semantics belong here. MoonTown consumes only the declared projection and candidate intake contracts.\n",
  )
  inspect_pack_source(source_root, workspace_root)
}

///|
fn json_contract(id : String, path : String) -> Json {
  { "id": id, "version": "1.0.0", "path": path }
}

///|
fn append_unique_contract(
  fields : Map[String, Json],
  field : String,
  id : String,
  path : String,
) -> Unit raise {
  guard fields.get(field) is Some(Array(items)) else {
    fail("pack manifest field `\{field}` must be an array")
  }
  let exists = items.any(item => {
    match item {
      Object(contract) => contract.get("id") == Some(id.to_json())
      _ => false
    }
  })
  if !exists {
    items.push(json_contract(id, path))
  }
}

///|
pub async fn adopt_pack_bridge(
  request : PackBridgeAdoptionRequest,
  workspace_root : String,
) -> PackStudioInspection {
  if !safe_identifier(request.intake_operation_id) ||
    !safe_identifier(request.output_schema_id) {
    fail("intake operation and output schema must be safe identifiers")
  }
  let manifest_path = request.source_root + "/pack.json"
  let parsed = @json.parse(@fs.read_file(manifest_path).text())
  guard parsed is Object(fields) else {
    fail("pack manifest must be an object")
  }
  guard fields.get("schemas") is Some(Array(schemas)) else {
    fail("pack manifest schemas must be an array")
  }
  let output_declared = schemas.any(item => {
    match item {
      Object(schema) =>
        schema.get("id") == Some(request.output_schema_id.to_json())
      _ => false
    }
  })
  if !output_declared {
    fail("candidate output schema is not declared by the pack")
  }
  append_unique_contract(
    fields, "schemas", "pack-town-projection", "schemas/pack-town-projection.schema.json",
  )
  append_unique_contract(
    fields, "schemas", "town-pack-candidate", "schemas/town-pack-candidate.schema.json",
  )
  append_unique_contract(
    fields, "schemas", "pack-candidate-acknowledgement", "schemas/pack-candidate-acknowledgement.schema.json",
  )
  append_unique_contract(
    fields, "provider_ports", "moontown-pack-projection", "providers/moontown-pack-projection.port.md",
  )
  guard fields.get("tools") is Some(Array(tools)) else {
    fail("pack manifest tools must be an array")
  }
  let has_intake = tools.any(item => {
    match item {
      Object(tool) =>
        tool.get("id") == Some(request.intake_operation_id.to_json())
      _ => false
    }
  })
  if !has_intake {
    let product_id = match fields.get("product_id") {
      Some(String(value)) => value
      _ => fail("pack product_id is required")
    }
    tools.push({
      "id": request.intake_operation_id,
      "owner_product": product_id,
      "input_schema_id": "town-pack-candidate",
      "output_schema_id": request.output_schema_id,
      "authority": "WorkspaceMutation",
      "idempotent": true,
      "evidence_outputs": ["records/candidate-intake"],
      "review_required": true,
    })
  }
  @pack.decode_manifest(parsed.stringify()) |> ignore
  write_bridge_artifacts(request.source_root, request.intake_operation_id)
  write_text(manifest_path, parsed.stringify(indent=2))
  inspect_pack_source(request.source_root, workspace_root)
}

///|
pub async fn install_pack_source(
  request : PackInstallRequest,
  workspace_root : String,
) -> @installer.InstallationReceipt {
  let profile : @installer.HostProfile = {
    contract: "moonsuite.pack-host-profile.v1",
    runtime_extensions: request.runtime_extensions,
    granted_authorities: request.granted_authorities,
  }
  @installer.install_authorized(request.source_root, workspace_root, profile)
}

///|
pub async fn activate_pack_version(
  request : PackVersionRequest,
  workspace_root : String,
) -> @installer.ActivePackPointer {
  @installer.activate_version(workspace_root, request.pack_id, request.version)
}

///|
pub async fn deactivate_pack(
  request : PackIdentityRequest,
  workspace_root : String,
) -> Bool {
  @installer.deactivate(workspace_root, request.pack_id)
}

///|
pub async fn active_pack_catalog(workspace_root : String) -> Json {
  {
    "contract_id": "moondesk.pack-lifecycle-catalog.v1",
    "packs": @installer.list_active(workspace_root),
  }
}

///|
fn mailbox_entry_count(path : String) -> Int {
  if !@sync_fs.path_exists(path) {
    return 0
  }
  @sync_fs.read_dir(path).length() catch {
    _ => 0
  }
}

///|
/// Inspect the shared bridge transport without executing pack-owned code.
pub fn pack_bridge_mailbox_status(
  workspace_root : String,
  pack_id : String,
) -> Json raise {
  guard safe_identifier(pack_id) else {
    fail("pack id must be a safe identifier")
  }
  let root = workspace_root + "/.moonsuite/products/\{pack_id}/pack-bridge"
  let inbox = root + "/inbox/candidates"
  let receipts = root + "/outbox/candidate-receipts"
  {
    "contract_id": "moondesk.pack-bridge-mailbox-status.v1",
    "pack_id": pack_id,
    "mailbox_root": root,
    "delivered_candidates": mailbox_entry_count(inbox),
    "candidate_receipts": mailbox_entry_count(receipts),
    "projection_present": @sync_fs.path_exists(root + "/outbox/projection.json"),
  }
}
