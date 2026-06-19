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
  let trimmed = relative.trim(chars=['/']).to_owned()
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
  method_ is Get || method_ is Head
}

///|
fn strip_query(path : String) -> String {
  match path.find("?") {
    Some(index) => path[:index].to_owned()
    None => path
  }
}

///|
fn query_value(path : String, key : String) -> String? {
  match path.find("?") {
    Some(index) => {
      for piece in path[index + 1:].split("&") {
        let entry = piece.to_owned()
        match entry.find("=") {
          Some(split) =>
            if entry[:split] == key {
              return Some(entry[split + 1:].to_owned())
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
    ['/', .. rest] => rest.to_owned()
    _ => path
  }
  let segments : Array[String] = []
  for segment in path.split("/") {
    let segment = segment.to_owned()
    if segment != "" {
      segments.push(segment)
    }
  }
  segments
}

///|
async fn read_json_body(body : &@io.Reader) -> Json? {
  let text = body.read_all().text()
  if text.trim().to_owned() == "" {
    return Some(Json::object({}))
  }
  Some(@json.parse(text)) catch {
    _ => None
  }
}

///|
fn json_string(json : Json, key : String, default~ : String) -> String {
  @mooncore.json_string(json, key, default~)
}

///|
fn json_string_opt(json : Json, key : String) -> String? {
  @mooncore.json_string_opt(json, key)
}

///|
fn json_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  @mooncore.json_first_string(json, keys, default~)
}

///|
fn json_int(json : Json, key : String, default~ : Int) -> Int {
  @mooncore.json_int(json, key, default~)
}

///|
fn json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  @mooncore.json_bool(json, key, default~)
}

///|
fn json_string_array_len(json : Json, key : String) -> Int {
  match json {
    Object(object) =>
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
  @moonfiles.read_json_file_or_object(path)
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
