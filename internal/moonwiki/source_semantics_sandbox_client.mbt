///|
const SourceSemanticsSandboxConfigBytes : Int = 65_536

///|
const SourceSemanticsSandboxResponseBytes : Int = 200_000

///|
priv struct SourceSemanticsSandboxClientConfig {
  protocol_version : Int
  instance_id : String
  auth_token : String
  workspace_id : String
  workspace_root : String
} derive(@json.FromJson)

///|
priv enum SourceSemanticsSandboxClientError {
  Unavailable
  InvalidReceipt
  Truncated
}

///|
fn source_semantics_safe_hex(value : String, length : Int) -> Bool {
  value.length() == length &&
  value.all(character => {
    character.is_ascii_digit() || (character >= 'a' && character <= 'f')
  })
}

///|
fn source_semantics_control_root(
  app_data_root : String,
  home : String,
) -> String {
  let app_root = if app_data_root.trim() != "" {
    @pathx.normalize(app_data_root)
  } else if home.trim() != "" {
    @pathx.join(
      @pathx.normalize(home),
      "Library/Application Support/app.vectie.moondesk",
    )
  } else {
    ""
  }
  if app_root == "" {
    ""
  } else {
    @pathx.join(app_root, "control/execution-sandbox")
  }
}

///|
async fn source_semantics_read_bounded_file(
  path : String,
  limit : Int,
) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  guard file.kind() is Regular else { fail("sandbox config is not regular") }
  let initial_size = file.size()
  guard initial_size >= 0L && initial_size <= limit.to_int64() else {
    fail("sandbox config exceeds the size limit")
  }
  let output = @buffer.Buffer(size_hint=initial_size.to_int().min(8_192))
  for ;; {
    guard file.read_some(max_len=(limit - output.length() + 1).min(8_192))
      is Some(chunk) else {
      break
    }
    guard output.length() + chunk.length() <= limit else {
      fail("sandbox config exceeds the size limit")
    }
    output.write_bytes(chunk)
  }
  guard file.size() == initial_size else {
    fail("sandbox config changed while it was read")
  }
  @encoding/utf8.decode(output.to_bytes())
}

///|
async fn source_semantics_load_sandbox_client_config() -> SourceSemanticsSandboxClientConfig? {
  let configured = @sys.get_env_var("MOONDESK_EXECUTION_SANDBOX_CONFIG").unwrap_or(
    "",
  )
  guard configured != "" else { return None }
  let path = @pathx.normalize(configured)
  let control_root = source_semantics_control_root(
    @sys.get_env_var("LEPUSA_APP_DATA_DIR").unwrap_or(""),
    @sys.get_env_var("HOME").unwrap_or(""),
  )
  guard control_root != "" &&
    @pathx.dirname(path).to_owned() == control_root &&
    @fs.kind(control_root, follow_symlink=false) is Directory &&
    @fs.realpath(control_root) == control_root &&
    @fs.kind(path, follow_symlink=false) is Regular &&
    @fs.realpath(path) == path else {
    fail("sandbox client config must be a canonical private control file")
  }
  @fs.chmod(control_root, 0o700)
  @fs.chmod(path, 0o600)
  let config : SourceSemanticsSandboxClientConfig = @json.from_json(
    @json.parse(
      source_semantics_read_bounded_file(
        path,
        SourceSemanticsSandboxConfigBytes,
      ),
    ),
  ) catch {
    _ => fail("sandbox client config is malformed")
  }
  guard config.protocol_version == 1 &&
    source_semantics_safe_hex(config.instance_id, 32) &&
    source_semantics_safe_hex(config.auth_token, 64) &&
    config.workspace_id.length() >= 1 &&
    config.workspace_id.length() <= 128 &&
    @fs.kind(config.workspace_root, follow_symlink=false) is Directory &&
    @fs.realpath(config.workspace_root) == config.workspace_root else {
    fail("sandbox client config failed validation")
  }
  Some(config)
}

///|
async fn source_semantics_read_bounded_response(
  client : @http.Client,
) -> Result[String, SourceSemanticsSandboxClientError] {
  let output = @buffer.Buffer(size_hint=8_192)
  for ;; {
    let chunk = client.read_some(
      max_len=(SourceSemanticsSandboxResponseBytes - output.length() + 1).min(
        8_192,
      ),
    ) catch {
      _ => return Err(Unavailable)
    }
    guard chunk is Some(chunk) else { break }
    guard output.length() + chunk.length() <=
      SourceSemanticsSandboxResponseBytes else {
      return Err(Truncated)
    }
    output.write_bytes(chunk)
  }
  Ok(
    @encoding/utf8.decode(output.to_bytes()) catch {
      _ => return Err(InvalidReceipt)
    },
  )
}

///|
fn source_semantics_request_id() -> Result[
  String,
  SourceSemanticsSandboxClientError,
] {
  guard @env.rand(16) is Some(random) else { return Err(Unavailable) }
  Ok("desk-" + @crypto.bytes_to_hex_string(random))
}

///|
fn source_semantics_validate_sandbox_response(
  payload : Json,
  config : SourceSemanticsSandboxClientConfig,
  request_id : String,
) -> Result[Json, SourceSemanticsSandboxClientError] {
  guard json_int(payload, "protocol_version", default=0) == 1 &&
    json_string(payload, "instance_id", default="") == config.instance_id &&
    json_string(payload, "request_id", default="") == request_id &&
    json_string(payload, "workspace_id", default="") == config.workspace_id &&
    json_string(payload, "operation", default="") == "moon_diagnostics" &&
    !json_bool(payload, "output_truncated", default=true) &&
    json_object_field(payload, "receipt") is Some(receipt) &&
    source_semantics_safe_hex(
      json_string(receipt, "approval_digest", default=""),
      64,
    ) &&
    source_semantics_safe_hex(
      json_string(receipt, "command_digest", default=""),
      64,
    ) &&
    source_semantics_safe_hex(
      json_string(receipt, "profile_digest", default=""),
      64,
    ) &&
    json_string(receipt, "enforcement", default="") == "Enforced" &&
    json_bool(receipt, "cleanup_verified", default=false) else {
    return Err(InvalidReceipt)
  }
  Ok({
    "exit_code": json_int(payload, "exit_code", default=-1),
    "output": json_string(payload, "output", default=""),
    "receipt": receipt,
  })
}

///|
async fn source_semantics_sandbox_diagnostics(
  workspace_root : String,
  module_root : String,
) -> Result[Json, SourceSemanticsSandboxClientError] {
  let config = source_semantics_load_sandbox_client_config() catch {
    _ => return Err(Unavailable)
  }
  guard config is Some(config) && config.workspace_root == workspace_root else {
    return Err(Unavailable)
  }
  let module_directory = if module_root == workspace_root {
    ""
  } else {
    match module_root.strip_prefix(workspace_root + "/") {
      Some(value) => value.to_owned()
      None => return Err(Unavailable)
    }
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  guard json_bool(daemon, "running", default=false) else {
    return Err(Unavailable)
  }
  let port = json_int(daemon, "port", default=0)
  guard port > 0 else { return Err(Unavailable) }
  let request_id = match source_semantics_request_id() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let request : Json = {
    "protocol_version": 1,
    "instance_id": config.instance_id,
    "request_id": request_id,
    "workspace_id": config.workspace_id,
    "module_directory": module_directory,
    "target": "",
  }
  let client = @http.Client("http://127.0.0.1:\{port}") catch {
    _ => return Err(Unavailable)
  }
  defer client.close()
  let response = client.post(
    "/v1/execution-sandbox/moon-diagnostics",
    request,
    extra_headers={
      "Content-Type": "application/json",
      "X-MoonClaw-Execution-Token": config.auth_token,
    },
  ) catch {
    _ => return Err(Unavailable)
  }
  guard response.code == 200 else { return Err(Unavailable) }
  let text = match source_semantics_read_bounded_response(client) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let payload = @json.parse(text) catch { _ => return Err(InvalidReceipt) }
  source_semantics_validate_sandbox_response(payload, config, request_id)
}
