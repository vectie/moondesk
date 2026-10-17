///|
fn supervisor_bridge_model_selector_valid(model : String) -> Bool {
  model == "gpt-5.6-sol" || moonclaw_moongate_model_name_valid(model)
}

///| Resolve only a new activation. Once Town has claimed it, the persisted

///|
/// selector and payload digest survive route/default changes and transport retries.
fn supervisor_bridge_resolve_activation_model(
  handoff : Json,
  route : Json,
) -> Result[Json, String] {
  let payload = json_object_field_or_empty(handoff, "payload")
  let binding = json_object_field_or_empty(payload, "runtime_binding")
  let model = json_string(binding, "model", default="")
  if supervisor_bridge_digest(payload) !=
    json_string(handoff, "request_digest", default="") {
    return Err(
      "Town activation payload does not match its exact request digest",
    )
  }
  if model != "" {
    if !supervisor_bridge_model_selector_valid(model) {
      return Err("The persisted supervisor model selector is invalid")
    }
    return Ok(handoff)
  }
  let requested = json_string(binding, "requested_model", default="")
  let selected = if requested == "" {
    if !moonclaw_moongate_route_ready(route) {
      return Err(
        "Configure a live MoonGate default model, then retry the saved activation",
      )
    }
    moonclaw_moongate_default_model(route)
  } else {
    requested
  }
  let catalog_ready = json_bool(
    route,
    "catalog_ready",
    default=json_bool(route, "ready", default=false),
  )
  if json_string(route, "contract", default="") != MoonGateRouteContract ||
    !catalog_ready ||
    !moonclaw_moongate_model_name_valid(selected) ||
    !moonclaw_moongate_models(route).any(model => {
      json_string(model, "name", default="") == selected
    }) {
    return Err(
      "The exact selected MoonGate model is unavailable; restore that route and retry the saved activation",
    )
  }
  guard binding is Object(binding_fields) &&
    payload is Object(payload_fields) &&
    handoff is Object(handoff_fields) else {
    return Err("Town activation has an invalid runtime binding")
  }
  let next_binding = binding_fields.copy()
  next_binding["model"] = ToJson::to_json(selected)
  next_binding["model_resolution"] = ToJson::to_json(
    if requested == "" {
      "configured_default"
    } else {
      "explicit"
    },
  )
  let next_payload = payload_fields.copy()
  next_payload["runtime_binding"] = Json::object(next_binding)
  let resolved = Json::object(next_payload)
  let next_handoff = handoff_fields.copy()
  next_handoff["payload"] = resolved
  next_handoff["request_digest"] = ToJson::to_json(
    supervisor_bridge_digest(resolved),
  )
  Ok(Json::object(next_handoff))
}
