///|
fn mooncode_native_stream_latest_sequence(text : String) -> Int {
  let mut latest = 0
  for line in text.split("\n") {
    let record = mooncode_native_stream_record(line)
    let type_ = json_string(record, "type", default="")
    if type_ == "meta" {
      latest = mooncode_max_int(
        latest,
        json_int(record, "next_since", default=0),
      )
    } else if type_ == "event" || type_ == "done" {
      latest = mooncode_max_int(latest, json_int(record, "sequence", default=0))
    }
  }
  latest
}

///|
fn mooncode_native_stream_record(line : StringView) -> Json {
  let trimmed = line.trim().to_owned()
  if trimmed == "" {
    Json::object({})
  } else {
    @json.parse(trimmed) catch {
      _ => Json::object({})
    }
  }
}

///|
fn mooncode_max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
async fn mooncode_native_stream_text(
  workspace_root : String,
  session_id : String,
  format : String,
  since : Int,
  wait_ms~ : Int,
  poll_ms~ : Int,
) -> Result[String, String] {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return Err("MoonClaw daemon is not running")
  }
  if !mooncode_turn_runtime_ready(daemon) {
    return Err("MoonClaw MoonCode runtime is not available")
  }
  moonclaw_get_text(
    daemon,
    @mooncode.moonclaw_native_stream_endpoint(
      session_id,
      workspace_root,
      format,
      since,
      wait_ms~,
      poll_ms~,
    ),
  )
}
