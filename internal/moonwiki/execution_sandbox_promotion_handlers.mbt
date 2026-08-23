///|
const ExecutionSandboxPromotionRequestBytes : Int = 65_536

///|
priv struct MoonClawSandboxPromotionEvidence {
  moonfort_protocol_version : Int
  retention_id : String
  workspace_id : String
  approval_digest : String
  command_digest : String
  completed : Bool
  promoted_paths : Array[String]
  destination_outcome : String
  uncertain_paths : Array[String]
  recovery_required : Bool
  error_code : String
} derive(@json.FromJson)

///|
priv struct MoonClawSandboxPromotionResponse {
  protocol_version : Int
  instance_id : String
  request_id : String
  workspace_id : String
  retention_id : String
  approval_digest : String
  command_digest : String
  completed : Bool
  promoted_paths : Array[String]
  destination_outcome : String
  uncertain_paths : Array[String]
  recovery_required : Bool
  error_code : String
  evidence : MoonClawSandboxPromotionEvidence
} derive(@json.FromJson)

///|
async fn read_sandbox_promotion_body(
  body : &@io.Reader,
) -> Result[@mooncode_core.MoonCodeSandboxPromotionRequest, String] {
  let output = @buffer.Buffer(size_hint=1_024)
  for ;; {
    guard body.read_some(
        max_len=(ExecutionSandboxPromotionRequestBytes - output.length() + 1).min(
          4_096,
        ),
      )
      is Some(chunk) else {
      break
    }
    guard output.length() + chunk.length() <=
      ExecutionSandboxPromotionRequestBytes else {
      return Err("sandbox promotion request exceeds the size limit")
    }
    output.write_bytes(chunk)
  }
  let json = @json.parse(@encoding/utf8.decode(output.to_bytes())) catch {
    _ => return Err("sandbox promotion request is not valid JSON")
  }
  let request : @mooncode_core.MoonCodeSandboxPromotionRequest = @json.from_json(
    json,
  ) catch {
    _ => return Err("sandbox promotion request has an invalid shape")
  }
  @mooncode_core.validate_mooncode_sandbox_promotion_request(request)
}

///|
fn sandbox_promotion_bound_request(
  request : @mooncode_core.MoonCodeSandboxPromotionRequest,
  config : SourceSemanticsSandboxClientConfig,
  request_id : String,
) -> Json {
  {
    "protocol_version": 1,
    "instance_id": config.instance_id,
    "request_id": request_id,
    "workspace_id": config.workspace_id,
    "retention_id": request.retention_id,
    "approval_digest": request.approval_digest,
    "command_digest": request.command_digest,
    "items": request.items,
  }
}

///|
fn validate_moonclaw_sandbox_promotion_response(
  payload : Json,
  request : @mooncode_core.MoonCodeSandboxPromotionRequest,
  config : SourceSemanticsSandboxClientConfig,
  request_id : String,
) -> Result[@mooncode_core.MoonCodeSandboxPromotionResult, String] {
  let response : MoonClawSandboxPromotionResponse = @json.from_json(payload) catch {
    _ => return Err("MoonClaw returned an invalid sandbox promotion receipt")
  }
  let pre_claim_refusal = response.destination_outcome == "not-applied" &&
    !response.recovery_required &&
    response.error_code == "promotion-refused"
  let evidence_binding_valid = if pre_claim_refusal {
    response.evidence.workspace_id == "" &&
    response.evidence.approval_digest == "" &&
    response.evidence.command_digest == ""
  } else {
    response.evidence.workspace_id == config.workspace_id &&
    response.evidence.approval_digest == request.approval_digest &&
    response.evidence.command_digest == request.command_digest
  }
  guard response.protocol_version == 1 &&
    response.instance_id == config.instance_id &&
    response.request_id == request_id &&
    response.workspace_id == config.workspace_id &&
    response.retention_id == request.retention_id &&
    response.approval_digest == request.approval_digest &&
    response.command_digest == request.command_digest &&
    response.evidence.moonfort_protocol_version == 4 &&
    response.evidence.retention_id == request.retention_id &&
    evidence_binding_valid &&
    response.evidence.completed == response.completed &&
    response.evidence.promoted_paths == response.promoted_paths &&
    response.evidence.destination_outcome == response.destination_outcome &&
    response.evidence.uncertain_paths == response.uncertain_paths &&
    response.evidence.recovery_required == response.recovery_required &&
    response.evidence.error_code == response.error_code else {
    return Err("MoonClaw sandbox promotion receipt did not match the review")
  }
  @mooncode_core.validate_mooncode_sandbox_promotion_result(
    {
      completed: response.completed,
      retention_id: response.retention_id,
      approval_digest: response.approval_digest,
      command_digest: response.command_digest,
      promoted_paths: response.promoted_paths,
      destination_outcome: response.destination_outcome,
      uncertain_paths: response.uncertain_paths,
      recovery_required: response.recovery_required,
      error_code: response.error_code,
    },
    request,
  )
}

///|
async fn call_moonclaw_sandbox_promotion(
  request : @mooncode_core.MoonCodeSandboxPromotionRequest,
  config : SourceSemanticsSandboxClientConfig,
  request_id : String,
) -> Result[@mooncode_core.MoonCodeSandboxPromotionResult, String] {
  let daemon = moonclaw_daemon_status(config.workspace_root)
  guard json_bool(daemon, "running", default=false) else {
    return Err("Execution sandbox is unavailable")
  }
  let port = json_int(daemon, "port", default=0)
  guard port > 0 else { return Err("Execution sandbox is unavailable") }
  let client = @http.Client("http://127.0.0.1:\{port}") catch {
    _ => return Err("Execution sandbox is unavailable")
  }
  defer client.close()
  let response = client.post(
    "/v1/execution-sandbox/promote",
    sandbox_promotion_bound_request(request, config, request_id),
    extra_headers={
      "Content-Type": "application/json",
      "X-MoonClaw-Execution-Token": config.auth_token,
    },
  ) catch {
    _ => return Err("Execution sandbox promotion was unavailable")
  }
  guard response.code == 200 else {
    return Err("Execution sandbox promotion was refused")
  }
  let text = match source_semantics_read_bounded_response(client) {
    Ok(value) => value
    Err(_) => return Err("Execution sandbox promotion response was invalid")
  }
  let payload = @json.parse(text) catch {
    _ => return Err("Execution sandbox promotion response was invalid")
  }
  validate_moonclaw_sandbox_promotion_response(
    payload, request, config, request_id,
  )
}

///|
async fn handle_execution_sandbox_promotion(
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let request = match read_sandbox_promotion_body(body) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 422, "Unprocessable Content", error)
      return
    }
  }
  let config = source_semantics_load_sandbox_client_config() catch { _ => None }
  guard config is Some(config) else {
    send_api_error(
      conn, method_, 503, "Service Unavailable", "Execution sandbox is unavailable",
    )
    return
  }
  let request_id = match source_semantics_request_id() {
    Ok(value) => value
    Err(_) => {
      send_api_error(
        conn, method_, 503, "Service Unavailable", "Execution sandbox request identity is unavailable",
      )
      return
    }
  }
  match call_moonclaw_sandbox_promotion(request, config, request_id) {
    Ok(result) => send_json(conn, method_, result.to_json())
    Err(error) =>
      send_api_error(conn, method_, 503, "Service Unavailable", error)
  }
}
