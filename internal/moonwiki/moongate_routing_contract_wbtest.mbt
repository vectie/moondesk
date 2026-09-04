///|
test "MoonGate routing contract accepts only live routed models" {
  let payload : Json = {
    "contract": "moonclaw.moongate-route.v1",
    "ready": true,
    "default_model": "moongate/kimi-k3",
    "models": [
      { "name": "codex/gpt-5.6-sol" },
      { "name": "moongate/kimi-k3" },
      { "name": "moongate/kimi-k3" },
      { "name": "moongate/deepseek-v4" },
    ],
  }
  assert_true(moonclaw_moongate_route_ready(payload))
  assert_eq(moonclaw_moongate_default_model(payload), "moongate/kimi-k3")
  let models = moonclaw_moongate_models(payload)
  assert_eq(models.length(), 2)
  assert_eq(json_string(models[0], "name", default=""), "moongate/kimi-k3")
  assert_eq(json_string(models[1], "name", default=""), "moongate/deepseek-v4")
}

///|
test "MoonGate routing contract fails closed on standalone MoonClaw models" {
  for
    payload in [
      (
        {
          "contract": "moonclaw.moongate-route.v1",
          "ready": true,
          "default_model": "codex/gpt-5.6-sol",
          "models": [{ "name": "codex/gpt-5.6-sol" }],
        } : Json),
      (
        {
          "contract": "moonclaw.moongate-route.v1",
          "ready": false,
          "default_model": "moongate/kimi-k3",
          "models": [{ "name": "moongate/kimi-k3" }],
        } : Json),
      (
        {
          "contract": "legacy",
          "ready": true,
          "default_model": "moongate/kimi-k3",
          "models": [{ "name": "moongate/kimi-k3" }],
        } : Json),
    ] {
    assert_false(moonclaw_moongate_route_ready(payload))
  }
}

///|
test "MoonGate model selector validation rejects whitespace and empty ids" {
  assert_true(moonclaw_moongate_model_name_valid("moongate/kimi-k3"))
  for
    invalid in [
      "", "moongate/", " moongate/kimi-k3", "moongate/kimi-k3 ", "codex/gpt-5.6-sol",
    ] {
    assert_false(moonclaw_moongate_model_name_valid(invalid))
  }
}

///|
test "MoonCode planning commands require a MoonGate route" {
  let routed = @mooncode_core.MoonCodeCommand::{
    kind: Prompt,
    client_turn_id: "turn-1",
    context_path: "",
    message: "Help",
    model: "moongate/kimi-k3",
    web_search: false,
    planner_max_steps: None,
    planner_reasoning_effort: "none",
    approval_id: "",
    target_command_id: "",
    tool_call_id: "",
    force_preflight: false,
  }
  assert_true(validate_mooncode_command_model_route(routed) is Ok(_))
  assert_true(
    validate_mooncode_command_model_route({
      ..routed,
      model: "codex/gpt-5.6-sol",
    })
    is Err(_),
  )
  assert_true(
    validate_mooncode_command_model_route({ ..routed, model: "" }) is Err(_),
  )
  let deterministic = @mooncode_core.MoonCodeCommand::{
    ..routed,
    kind: RunTests,
    model: "",
  }
  assert_true(validate_mooncode_command_model_route(deterministic) is Ok(_))
}
