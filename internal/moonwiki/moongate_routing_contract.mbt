///|
const MoonGateModelPrefix : String = "moongate/"

///|
const MoonGateRouteContract : String = "moonclaw.moongate-route.v1"

///|
fn moonclaw_moongate_model_name_valid(name : String) -> Bool {
  let value = name.trim()
  value == name &&
  value.has_prefix(MoonGateModelPrefix) &&
  value.length() > MoonGateModelPrefix.length()
}

///|
fn moonclaw_moongate_models(payload : Json) -> Array[Json] {
  let models : Array[Json] = []
  for model in json_array_items(payload, "models") {
    let name = json_string(model, "name", default="")
    if moonclaw_moongate_model_name_valid(name) &&
      !models.any(existing => json_string(existing, "name", default="") == name) {
      models.push(model)
    }
  }
  models
}

///|
fn moonclaw_moongate_default_model(payload : Json) -> String {
  let default_model = json_string(payload, "default_model", default="")
  if moonclaw_moongate_model_name_valid(default_model) &&
    moonclaw_moongate_models(payload).any(model => {
      json_string(model, "name", default="") == default_model
    }) {
    default_model
  } else {
    ""
  }
}

///|
fn moonclaw_moongate_route_ready(payload : Json) -> Bool {
  json_string(payload, "contract", default="") == MoonGateRouteContract &&
  json_bool(payload, "ready", default=false) &&
  moonclaw_moongate_default_model(payload) != ""
}

///|
fn moonclaw_moongate_route_evidence(payload : Json) -> Json {
  {
    "contract": MoonGateRouteContract,
    "ready": moonclaw_moongate_route_ready(payload),
    "traffic_path": ["moondesk", "moonclaw", "moongate"],
    "model_prefix": MoonGateModelPrefix,
    "default_model": moonclaw_moongate_default_model(payload),
    "models": Json::array(moonclaw_moongate_models(payload)),
  }
}

///|
fn mooncode_command_requires_model_route(
  command : @mooncode_core.MoonCodeCommand,
) -> Bool {
  ["prompt", "steer", "package"].contains(command.kind.to_string())
}

///|
fn validate_mooncode_command_model_route(
  command : @mooncode_core.MoonCodeCommand,
) -> Result[Unit, String] {
  if mooncode_command_requires_model_route(command) &&
    !moonclaw_moongate_model_name_valid(command.model) {
    Err("MoonCode requires a model routed through MoonClaw and MoonGate")
  } else if command.model != "" &&
    !moonclaw_moongate_model_name_valid(command.model) {
    Err("MoonCode model is not routed through MoonGate")
  } else {
    Ok(())
  }
}
