///|
fn resolve_workspace_path(
  workspace_root : String,
  relative : String,
) -> (String, String)? {
  let root = @pathx.normalize(workspace_root)
  let clean = match clean_relative_path(relative) {
    Some(path) => path
    None => return None
  }
  let absolute = if clean == "" { root } else { @pathx.join(root, clean) }
  let expected_prefix = root + "/"
  if absolute == root || absolute.has_prefix(expected_prefix) {
    Some((absolute, clean))
  } else {
    None
  }
}

///|
fn clean_relative_path(relative : String) -> String? {
  if relative.has_prefix("/") || @pathx.is_absolute(relative) {
    return None
  }
  let trimmed = relative.trim(chars=['/']).to_string()
  if trimmed == "" {
    return Some("")
  }
  let normalized = @pathx.normalize(trimmed)
  if normalized == "." {
    Some("")
  } else if normalized == ".." || normalized.has_prefix("../") {
    None
  } else {
    Some(normalized)
  }
}

///|
fn is_read_method(method_ : @http.RequestMethod) -> Bool {
  method_ is @http.RequestMethod::Get || method_ is @http.RequestMethod::Head
}

///|
fn strip_query(path : String) -> String {
  match path.find("?") {
    Some(index) => path[:index].to_string()
    None => path
  }
}

///|
fn query_value(path : String, key : String) -> String? {
  match path.find("?") {
    Some(index) => {
      for piece in path[index + 1:].split("&") {
        let entry = piece.to_string()
        match entry.find("=") {
          Some(split) =>
            if entry[:split] == key {
              return Some(entry[split + 1:].to_string())
            }
          None => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn decode_query_value(text : String) -> String {
  let chars = text.to_array()
  let bytes : Array[Byte] = []
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch == '+' {
      bytes.push(' '.to_int().to_byte())
      index += 1
    } else if ch == '%' && index + 2 < chars.length() {
      let high = hex_value(chars[index + 1])
      let low = hex_value(chars[index + 2])
      if high >= 0 && low >= 0 {
        bytes.push((high * 16 + low).to_byte())
        index += 3
      } else {
        append_utf8_char(bytes, ch)
        index += 1
      }
    } else {
      append_utf8_char(bytes, ch)
      index += 1
    }
  }
  @encoding/utf8.decode_lossy(Bytes::from_array(bytes))
}

///|
fn encode_query_value(text : String) -> String {
  let pieces : Array[String] = []
  for ch in text {
    if query_safe_char(ch) {
      pieces.push(String::from_array([ch]))
    } else {
      append_percent_encoded_char(pieces, ch)
    }
  }
  pieces.join("")
}

///|
fn query_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '~'
}

///|
fn hex_value(ch : Char) -> Int {
  let code = ch.to_int()
  if ch >= '0' && ch <= '9' {
    code - '0'.to_int()
  } else if ch >= 'a' && ch <= 'f' {
    code - 'a'.to_int() + 10
  } else if ch >= 'A' && ch <= 'F' {
    code - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
fn append_percent_encoded_char(pieces : Array[String], ch : Char) -> Unit {
  let code = ch.to_int()
  if code <= 0x7F {
    pieces.push(percent_encoded_byte(code))
  } else if code <= 0x7FF {
    pieces.push(percent_encoded_byte(0xC0 + code / 64))
    pieces.push(percent_encoded_byte(0x80 + code % 64))
  } else if code <= 0xFFFF {
    pieces.push(percent_encoded_byte(0xE0 + code / 4096))
    pieces.push(percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(percent_encoded_byte(0x80 + code % 64))
  } else {
    pieces.push(percent_encoded_byte(0xF0 + code / 262144))
    pieces.push(percent_encoded_byte(0x80 + code / 4096 % 64))
    pieces.push(percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(percent_encoded_byte(0x80 + code % 64))
  }
}

///|
fn percent_encoded_byte(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  "%" +
  digits[value / 16:value / 16 + 1].to_owned() +
  digits[value % 16:value % 16 + 1].to_owned()
}

///|
fn append_utf8_char(bytes : Array[Byte], ch : Char) -> Unit {
  let code = ch.to_int()
  if code <= 0x7F {
    bytes.push(code.to_byte())
  } else if code <= 0x7FF {
    bytes.push((0xC0 + code / 64).to_byte())
    bytes.push((0x80 + code % 64).to_byte())
  } else if code <= 0xFFFF {
    bytes.push((0xE0 + code / 4096).to_byte())
    bytes.push((0x80 + code / 64 % 64).to_byte())
    bytes.push((0x80 + code % 64).to_byte())
  } else {
    bytes.push((0xF0 + code / 262144).to_byte())
    bytes.push((0x80 + code / 4096 % 64).to_byte())
    bytes.push((0x80 + code / 64 % 64).to_byte())
    bytes.push((0x80 + code % 64).to_byte())
  }
}

///|
fn path_segments(path : String) -> Array[String] {
  let path = match path {
    ['/', .. rest] => rest.to_string()
    _ => path
  }
  let segments : Array[String] = []
  for segment in path.split("/") {
    let segment = segment.to_string()
    if segment != "" {
      segments.push(segment)
    }
  }
  segments
}

///|
async fn read_json_body(body : &@io.Reader) -> Json? {
  let text = body.read_all().text()
  if text.trim().to_string() == "" {
    return Some(Json::object({}))
  }
  Some(@json.parse(text)) catch {
    _ => None
  }
}

///|
fn json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn json_string_opt(json : Json, key : String) -> String? {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn json_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) =>
          @json.from_json(value) catch {
            _ =>
              match value {
                Json::String(text) =>
                  @string.parse_int(text) catch {
                    _ => default
                  }
                _ => default
              }
          }
        None => default
      }
    _ => default
  }
}

///|
fn json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        None => default
      }
    _ => default
  }
}

///|
fn json_string_array_len(json : Json, key : String) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => {
          let items : Array[String] = @json.from_json(value) catch { _ => [] }
          items.length()
        }
        None => 0
      }
    _ => 0
  }
}

///|
async fn read_json_file_or_object(path : String) -> Json {
  if !@fs.exists(path) {
    return Json::object({})
  }
  @json.parse(@fs.read_file(path).text()) catch {
    _ => Json::object({})
  }
}

///|
async fn read_text_file_or_empty(path : String) -> String {
  if !@fs.exists(path) {
    return ""
  }
  @fs.read_file(path).text() catch {
    _ => ""
  }
}

///|
fn parse_moonclaw_json_output(text : String) -> Json {
  let parsed = @json.parse(text) catch { _ => Json::object({}) }
  if json_string(parsed, "proposal_id", default="") != "" {
    return parsed
  }
  let lines = text.split("\n").to_array()
  let mut index = lines.length()
  while index > 0 {
    index -= 1
    let line = lines[index].to_string().trim().to_owned()
    if line == "{" || line.contains("\"proposal_id\"") {
      let candidate_lines : Array[String] = []
      let mut cursor = index
      while cursor < lines.length() {
        candidate_lines.push(lines[cursor].to_string())
        cursor += 1
      }
      let candidate = candidate_lines.join("\n").trim().to_owned()
      let candidate_json = @json.parse(candidate) catch {
        _ => Json::object({})
      }
      if json_string(candidate_json, "proposal_id", default="") != "" {
        return candidate_json
      }
    }
  }
  Json::object({})
}

///|
async fn read_json_array_file(path : String) -> Array[Json] {
  if !@fs.exists(path) {
    return []
  }
  let parsed = @json.parse(@fs.read_file(path).text()) catch { _ => return [] }
  @json.from_json(parsed) catch {
    _ => []
  }
}
