///|
fn api_contract_response(
  payload : Json,
  ok~ : Bool,
  status~ : String,
  message~ : String,
  next_action~ : String = "",
) -> Json {
  let with_ok = @mooncore.session_with_field(payload, "ok", ToJson::to_json(ok))
  let with_status = @mooncore.session_with_field(
    with_ok,
    "status",
    ToJson::to_json(status),
  )
  let with_message = @mooncore.session_with_field(
    with_status,
    "message",
    ToJson::to_json(message),
  )
  let with_contract = @mooncore.session_with_field(
    with_message,
    "api_contract",
    ToJson::to_json("moonsuite.phase6.v1"),
  )
  if next_action == "" {
    with_contract
  } else {
    @mooncore.session_with_field(
      with_contract,
      "next_action",
      ToJson::to_json(next_action),
    )
  }
}

///|
fn api_service_fields(
  payload : Json,
  service_configured~ : Bool,
  service_config_path~ : String,
  service_command~ : String = "",
  service_path~ : String = "",
) -> Json {
  let next = @mooncore.session_with_field(
    payload,
    "service_configured",
    ToJson::to_json(service_configured),
  )
  let next = @mooncore.session_with_field(
    next,
    "service_config_path",
    ToJson::to_json(service_config_path),
  )
  let next = @mooncore.session_with_field(
    next,
    "service_command",
    ToJson::to_json(service_command),
  )
  if service_path == "" {
    next
  } else {
    @mooncore.session_with_field(
      next,
      "service_path",
      ToJson::to_json(service_path),
    )
  }
}
