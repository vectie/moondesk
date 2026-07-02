///|
fn api_contract_response(
  payload : Json,
  ok~ : Bool,
  status~ : String,
  message~ : String,
  next_action? : String = "",
) -> Json {
  let with_ok = @mooncore.session_with_field(payload, "ok", ok.to_json())
  let with_status = @mooncore.session_with_field(
    with_ok,
    "status",
    status.to_json(),
  )
  let with_message = @mooncore.session_with_field(
    with_status,
    "message",
    message.to_json(),
  )
  let with_contract = @mooncore.session_with_field(
    with_message,
    "api_contract",
    "moonsuite.phase6.v1".to_json(),
  )
  if next_action == "" {
    with_contract
  } else {
    @mooncore.session_with_field(
      with_contract,
      "next_action",
      next_action.to_json(),
    )
  }
}

///|
fn api_service_fields(
  payload : Json,
  service_configured~ : Bool,
  service_config_path~ : String,
  service_command? : String = "",
  service_path? : String = "",
) -> Json {
  let next = @mooncore.session_with_field(
    payload,
    "service_configured",
    service_configured.to_json(),
  )
  let next = @mooncore.session_with_field(
    next,
    "service_config_path",
    service_config_path.to_json(),
  )
  let next = @mooncore.session_with_field(
    next,
    "service_command",
    service_command.to_json(),
  )
  if service_path == "" {
    next
  } else {
    @mooncore.session_with_field(next, "service_path", service_path.to_json())
  }
}
