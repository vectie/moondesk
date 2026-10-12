///|
// A host observation check, not a second execution engine. The engine owns
// the summary; the host only checks its revision/event-head correlation.
fn moonflow_owner_summary_observation(
  projection : Json,
  events : Json?,
) -> String {
  guard projection is { "owner_summary": summary, .. } else {
    return "summary-unavailable"
  }
  guard summary
    is {
      "contract_id": "moonflow.owner-summary.v1",
      "last_event_id": String(head_id),
      "recorded_at": String(recorded_at),
      ..
    } &&
    !head_id.is_empty() &&
    !recorded_at.is_empty() else {
    return "summary-unavailable"
  }
  for
    key in [
      "run_id", "book_id", "declaration_revision", "source_digest", "last_sequence",
      "outcome",
    ] {
    guard projection is Object(run_fields) &&
      summary is Object(summary_fields) &&
      run_fields.get(key) is Some(value) &&
      summary_fields.get(key) == Some(value) else {
      return "summary-mismatch"
    }
  }
  guard events is Some(Array(history)) && !history.is_empty() else {
    return "events-unavailable"
  }
  let ids : Array[String] = []
  for index, event in history {
    guard event is { "sequence": Number(sequence), "event_id": String(id), .. } &&
      sequence == index.to_double() &&
      !id.is_empty() &&
      !ids.contains(id) else {
      return "event-head-mismatch"
    }
    ids.push(id)
    for key in ["run_id", "book_id", "declaration_revision", "source_digest"] {
      guard event is Object(event_fields) &&
        summary is Object(summary_fields) &&
        event_fields.get(key) == summary_fields.get(key) else {
        return "event-head-mismatch"
      }
    }
  }
  guard history.last()
    is Some(
      {
        "event_id": String(id),
        "recorded_at": String(at),
        "sequence": sequence,
        ..
      }
    ) &&
    id == head_id &&
    at == recorded_at &&
    summary is { "last_sequence": expected, .. } &&
    sequence == expected else {
    return "event-head-mismatch"
  }
  "event-head-matched"
}
