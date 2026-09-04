///|
test "MoonCode model choices are normalized and selected explicitly" {
  assert_eq(
    mooncode_normalize_model_names([
      { name: " codex/gpt-5.6-sol " },
      { name: "" },
      { name: "codex/gpt-5.6-sol" },
      { name: "moongate/kimi-k3" },
    ]),
    ["moongate/kimi-k3"],
  )
  let model = {
    ..init_model(),
    mooncode_models: ["moongate/kimi-k3"],
    mooncode_model: "moongate/kimi-k3",
  }
  let (_, selected) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    SetMoonCodeModel("moongate/kimi-k3"),
    model,
  )
  assert_eq(selected.mooncode_model, "moongate/kimi-k3")
  let (_, rejected) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    SetMoonCodeModel("unavailable/model"),
    selected,
  )
  assert_eq(rejected.mooncode_model, "moongate/kimi-k3")
}

///|
test "MoonCode reasoning choices accept only runtime-supported effort" {
  let model = init_model()
  assert_eq(model.mooncode_reasoning_effort, "none")
  let (_, selected) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    SetMoonCodeReasoningEffort("xhigh"),
    model,
  )
  assert_eq(selected.mooncode_reasoning_effort, "xhigh")
  let (_, rejected) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    SetMoonCodeReasoningEffort("maximum"),
    selected,
  )
  assert_eq(rejected.mooncode_reasoning_effort, "xhigh")
}

///|
#warnings("-alert_unstable")
test "MoonCode composer exposes lazy model and reasoning control state" {
  let model = {
    ..init_model(),
    mooncode_models: ["moongate/kimi-k3"],
    mooncode_model: "moongate/kimi-k3",
    mooncode_reasoning_effort: "high",
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_composer_controls(fn(_msg) { @rabbita.none }, model),
    ),
  )
  assert_true(markup.contains("data-testid=\"mooncode-composer-controls\""))
  assert_true(markup.contains("data-runtime=\"mooncode-composer-controls-v1\""))
  assert_true(markup.contains("data-models=\"moongate/kimi-k3\""))
  assert_true(markup.contains("data-selected-model=\"moongate/kimi-k3\""))
  assert_true(markup.contains("data-reasoning=\"high\""))
  assert_true(markup.contains("data-mooncode-control-sync=\"model\""))
  assert_true(markup.contains("data-mooncode-control-sync=\"reasoning\""))
}
