///|
// Native MoonCode runtime result and completion contracts.

///|
pub fn native_command_result_contract(action : String) -> Json {
  @mooncode_core.native_command_result_contract(action)
}

///|
pub fn native_command_execution_checklist(
  action : String,
  required_events : Array[String],
  required_outputs : Array[String],
  event_sink : String,
  eval_report_sink : String,
  ack_sink : String,
) -> Array[Json] {
  @mooncode_core.native_command_execution_checklist(
    action, required_events, required_outputs, event_sink, eval_report_sink, ack_sink,
  )
}
