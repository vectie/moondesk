///|
// Native MoonClaw MoonCode endpoint builders and query encoding.

///|
pub fn moonclaw_native_command_endpoint(session_id : String) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/commands"
}

///|
pub fn moonclaw_native_runtime_loop_endpoint(session_id : String) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/runtime-loop"
}

///|
pub fn moonclaw_native_runtime_turn_endpoint(session_id : String) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/runtime-turn"
}

///|
pub fn moonclaw_native_eval_report_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/eval-report?book_root=\{moonclaw_query_value(book_root)}"
}

///|
pub fn moonclaw_native_stream_endpoint(
  session_id : String,
  book_root : String,
  format : String,
  since : Int,
) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/stream?book_root=\{moonclaw_query_value(book_root)}&format=\{moonclaw_query_value(format)}&since=\{since}"
}

///|
fn moonclaw_query_value(text : String) -> String {
  let pieces : Array[String] = []
  for ch in text {
    if moonclaw_query_safe_char(ch) {
      pieces.push(String::from_array([ch]))
    } else {
      moonclaw_append_percent_encoded_char(pieces, ch)
    }
  }
  pieces.join("")
}

///|
fn moonclaw_query_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '~'
}

///|
fn moonclaw_append_percent_encoded_char(
  pieces : Array[String],
  ch : Char,
) -> Unit {
  let code = ch.to_int()
  if code <= 0x7F {
    pieces.push(moonclaw_percent_encoded_byte(code))
  } else if code <= 0x7FF {
    pieces.push(moonclaw_percent_encoded_byte(0xC0 + code / 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code % 64))
  } else if code <= 0xFFFF {
    pieces.push(moonclaw_percent_encoded_byte(0xE0 + code / 4096))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code % 64))
  } else {
    pieces.push(moonclaw_percent_encoded_byte(0xF0 + code / 262144))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code / 4096 % 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code % 64))
  }
}

///|
fn moonclaw_percent_encoded_byte(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  "%" +
  digits[value / 16:value / 16 + 1].to_owned() +
  digits[value % 16:value % 16 + 1].to_owned()
}
