///|
pub fn native_runtime_event_contract_report(
  native_report : Json,
  session_id~ : String,
  observed_at~ : String,
) -> Json {
  @mooncode_core.native_event_projection_report(
    native_report,
    session_id~,
    observed_at~,
  )
}

///|
pub fn native_runtime_events_for_canonical_projection(
  native_report : Json,
) -> Array[Json] {
  @mooncode_core.native_events_for_canonical_projection(native_report)
}
