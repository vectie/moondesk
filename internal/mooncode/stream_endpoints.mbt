///|
pub fn moondesk_stream_endpoint(
  session_id : String,
  format : String,
  since : Int,
) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/stream?format=\{stream_query_value(format)}&since=\{since}"
}

///|
pub fn moondesk_live_stream_endpoint(
  session_id : String,
  format : String,
  since : Int,
  timeout_ms? : Int = 8000,
) -> String {
  moondesk_stream_endpoint(session_id, format, since) +
  "&live=true&timeout_ms=\{timeout_ms}"
}

///|
pub fn moondesk_stream_state_endpoint(
  session_id : String,
  consumer_id : String,
  since : Int,
) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/stream-state?consumer=\{stream_query_value(consumer_id)}&since=\{since}"
}

///|
pub fn moondesk_stream_state_base_endpoint(session_id : String) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/stream-state"
}

///|
pub fn moondesk_runtime_event_ingest_endpoint(session_id : String) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/runtime-events"
}

///|
fn stream_query_value(text : String) -> String {
  let pieces : Array[String] = []
  for ch in text {
    if stream_query_safe_char(ch) {
      pieces.push(String::from_array([ch]))
    } else {
      stream_append_percent_encoded_char(pieces, ch)
    }
  }
  pieces.join("")
}

///|
fn stream_query_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '~'
}

///|
fn stream_append_percent_encoded_char(
  pieces : Array[String],
  ch : Char,
) -> Unit {
  let code = ch.to_int()
  if code <= 0x7F {
    pieces.push(stream_percent_encoded_byte(code))
  } else if code <= 0x7FF {
    pieces.push(stream_percent_encoded_byte(0xC0 + code / 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code % 64))
  } else if code <= 0xFFFF {
    pieces.push(stream_percent_encoded_byte(0xE0 + code / 4096))
    pieces.push(stream_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code % 64))
  } else {
    pieces.push(stream_percent_encoded_byte(0xF0 + code / 262144))
    pieces.push(stream_percent_encoded_byte(0x80 + code / 4096 % 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code % 64))
  }
}

///|
fn stream_percent_encoded_byte(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  "%" +
  digits[value / 16:value / 16 + 1].to_owned() +
  digits[value % 16:value % 16 + 1].to_owned()
}
