///|
/// Pair the desktop with its local service. This grants no Book/project trust
/// and stores no provider credential; those remain separate user actions.
pub async fn prepare_moonclaw_private_control(
  workspace_root : String,
) -> Result[Unit, String] {
  try {
    let root = @fs.realpath(workspace_context(workspace_root).suite_root)
    let configured = @env.get_env_var("MOONDESK_EXECUTION_SANDBOX_CONFIG").unwrap_or(
      "",
    )
    if configured != "" {
      let loaded = source_semantics_load_sandbox_client_config()
      if loaded is Some(config) && config.workspace_root == root {
        return Ok(())
      }
      return Err("MoonClaw control configuration belongs to another workspace")
    }
    let control_root = source_semantics_control_root(
      @env.get_env_var("LEPUSA_APP_DATA_DIR").unwrap_or(""),
      @env.get_env_var("HOME").unwrap_or(""),
    )
    let path = prepare_moonclaw_private_control_at(root, control_root)
    @env.set_env_var("MOONDESK_EXECUTION_SANDBOX_CONFIG", path)
    Ok(())
  } catch {
    _ =>
      Err(
        "MoonDesk could not prepare private MoonClaw communication; check app-data permissions",
      )
  }
}

///|
async fn prepare_moonclaw_private_control_at(
  root : String,
  control_root : String,
) -> String {
  guard control_root != "" && @fs.realpath(root) == root else {
    fail("Private control paths must be canonical")
  }
  @fs.mkdir(control_root, recursive=true, allow_exist=true, permission=0o700)
  guard @fs.realpath(control_root) == control_root else {
    fail("Private control directory must not redirect")
  }
  @fs.chmod(control_root, 0o700)
  let workspace_id = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(root).to_fixedarray()),
  )
  let path = @pathx.join(control_root, workspace_id + ".json")
  if !@fs.exists(path) {
    let random = @fs.open("/dev/urandom", mode=ReadOnly)
    defer random.close()
    let bytes = random.read_exactly(48)
    let payload : Json = {
      "protocol_version": 1,
      "instance_id": @crypto.bytes_to_hex_string(bytes[:16].to_owned()),
      "auth_token": @crypto.bytes_to_hex_string(bytes[16:].to_owned()),
      "workspace_id": workspace_id,
      "workspace_root": root,
      "trusted_book_roots": [],
    }
    // CreateNew prevents a second desktop process from replacing a live pair.
    @fs.write_file(
      path,
      payload.stringify(),
      create_mode=CreateNew,
      permission=0o600,
      sync=Full,
    )
  }
  guard @fs.kind(path, follow_symlink=false) is Regular &&
    @fs.realpath(path) == path else {
    fail("Private control file must not redirect")
  }
  @fs.chmod(path, 0o600)
  let config : SourceSemanticsSandboxClientConfig = @json.from_json(
    @json.parse(
      source_semantics_read_bounded_file(
        path,
        SourceSemanticsSandboxConfigBytes,
      ),
    ),
  )
  guard config.protocol_version == 1 &&
    config.workspace_id == workspace_id &&
    config.workspace_root == root &&
    source_semantics_safe_hex(config.instance_id, 32) &&
    source_semantics_safe_hex(config.auth_token, 64) else {
    fail("Private control file is invalid")
  }
  path
}
