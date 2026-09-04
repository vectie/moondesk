///|
fn mooncode_normalize_model_names(
  models : Array[MoonClawModel],
) -> Array[String] {
  let names : Array[String] = []
  for available in models {
    let name = available.name.trim().to_owned()
    if name.has_prefix("moongate/") &&
      name.length() > "moongate/".length() &&
      !names.contains(name) {
      names.push(name)
    }
  }
  names
}

///|
fn mooncode_available_model_names(
  result : MoonClawModelsResult,
) -> Array[String] {
  mooncode_normalize_model_names(result.models)
}

///|
fn mooncode_reasoning_effort_is_supported(value : String) -> Bool {
  ["none", "minimal", "low", "medium", "high", "xhigh"].contains(value)
}

///|
fn mooncode_reasoning_effort_status(value : String) -> String {
  if value == "none" {
    "Reasoning effort set automatically"
  } else {
    "Reasoning effort set to " + value
  }
}

///|
fn render_mooncode_composer_controls(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="mooncode-composer-controls",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-composer-controls")
      .data_set("runtime", "mooncode-composer-controls-v1")
      .data_set("models", model.mooncode_models.join("\n"))
      .data_set("selected-model", model.mooncode_model)
      .data_set("reasoning", model.mooncode_reasoning_effort)
      .aria_label("MoonCode model controls"),
    [
      input(
        class="mooncode-composer-control-sync",
        attrs=@html.Attrs::build()
          .data_set("mooncode-control-sync", "model")
          .aria_hidden("true"),
        value=model.mooncode_model,
        on_input=fn(value) { dispatch(SetMoonCodeModel(value)) },
      ),
      input(
        class="mooncode-composer-control-sync",
        attrs=@html.Attrs::build()
          .data_set("mooncode-control-sync", "reasoning")
          .aria_hidden("true"),
        value=model.mooncode_reasoning_effort,
        on_input=fn(value) { dispatch(SetMoonCodeReasoningEffort(value)) },
      ),
    ],
  )
}
