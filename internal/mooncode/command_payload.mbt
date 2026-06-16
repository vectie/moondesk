///|
pub fn command_action(payload : Json) -> String {
  trimmed_or(json_string(payload, "action", default="note"), fallback="note")
}

///|
pub fn command_context_path(payload : Json) -> String {
  trimmed_or(json_string(payload, "context_path", default=""), fallback="")
}
