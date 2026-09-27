///|
/// One ordered piece of a user-owned MoonCode prompt. Image bytes are bounded
/// and retained in the daemon command journal until an external media store is
/// available; they must never be flattened into the text request.
pub(all) struct MoonCodeContentPart {
  kind : String
  text : String
  media_type : String
  data_base64 : String
  name : String
} derive(Debug, Eq)

///|
fn mooncode_content_part_field(
  fields : Map[String, Json],
  key : String,
) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    None => Some("")
    Some(_) => None
  }
}

///|
fn mooncode_content_part_fields_allowed(
  fields : Map[String, Json],
  allowed : Array[String],
) -> Bool {
  for key, _ in fields.iter2() {
    if !allowed.contains(key) {
      return false
    }
  }
  true
}

///|
fn mooncode_decode_content_part(
  value : Json,
) -> Result[MoonCodeContentPart, String] {
  guard value is Object(fields) else {
    return Err("content_parts entries must be objects")
  }
  let kind = match mooncode_content_part_field(fields, "type") {
    Some(value) => value
    None => return Err("content part type must be a string")
  }
  match kind {
    "text" => {
      if !mooncode_content_part_fields_allowed(fields, ["type", "text"]) {
        return Err("text content part has unsupported fields")
      }
      let text = match mooncode_content_part_field(fields, "text") {
        Some(value) if value != "" => value
        _ => return Err("text content part must contain text")
      }
      Ok({ kind, text, media_type: "", data_base64: "", name: "", })
    }
    "image" => {
      if !mooncode_content_part_fields_allowed(fields, [
          "type", "media_type", "data_base64", "name",
        ]) {
        return Err("image content part has unsupported fields")
      }
      let media_type = match mooncode_content_part_field(fields, "media_type") {
        Some(value) => value
        None => return Err("image media_type must be a string")
      }
      let data_base64 = match
        mooncode_content_part_field(fields, "data_base64") {
        Some(value) => value
        None => return Err("image data_base64 must be a string")
      }
      let name = match mooncode_content_part_field(fields, "name") {
        Some(value) => value
        None => return Err("image name must be a string")
      }
      Ok({ kind, text: "", media_type, data_base64, name, })
    }
    _ => Err("unsupported content part type")
  }
}

///|
fn mooncode_content_part_json(part : MoonCodeContentPart) -> Json {
  if part.kind == "text" {
    { "type": "text", "text": part.text }
  } else {
    {
      "type": "image",
      "media_type": part.media_type,
      "data_base64": part.data_base64,
      "name": part.name,
    }
  }
}

///|
fn mooncode_content_parts_text(parts : Array[MoonCodeContentPart]) -> String {
  let out = StringBuilder()
  for part in parts {
    if part.kind == "text" {
      out.write_string(part.text)
    }
  }
  out.to_string()
}

///|
fn mooncode_image_signature_valid(media_type : String, bytes : Bytes) -> Bool {
  let raw = bytes.to_fixedarray()
  match media_type {
    "image/png" =>
      raw.length() >= 8 &&
      raw[0] == b'\x89' &&
      raw[1] == b'P' &&
      raw[2] == b'N' &&
      raw[3] == b'G' &&
      raw[4] == b'\r' &&
      raw[5] == b'\n' &&
      raw[6] == b'\x1a' &&
      raw[7] == b'\n'
    "image/jpeg" =>
      raw.length() >= 3 &&
      raw[0] == b'\xff' &&
      raw[1] == b'\xd8' &&
      raw[2] == b'\xff'
    "image/webp" =>
      raw.length() >= 12 &&
      raw[0] == b'R' &&
      raw[1] == b'I' &&
      raw[2] == b'F' &&
      raw[3] == b'F' &&
      raw[8] == b'W' &&
      raw[9] == b'E' &&
      raw[10] == b'B' &&
      raw[11] == b'P'
    _ => false
  }
}

///|
fn mooncode_command_content_parts_valid(
  parts : Array[MoonCodeContentPart],
  action : MoonCodeCommandKind,
  message : String,
) -> Result[Unit, String] {
  if parts.is_empty() {
    return Ok(())
  }
  if !(action is Prompt) {
    return Err("content_parts are available only for prompt turns")
  }
  if parts.length() > 12 {
    return Err("A Code turn may contain at most 12 ordered content parts")
  }
  if mooncode_content_parts_text(parts) != message {
    return Err("message must match the ordered text content exactly")
  }
  let mut image_count = 0
  let mut total_bytes = 0
  for part in parts {
    if part.kind == "text" {
      if part.text == "" ||
        part.text.length() > 64 * 1024 ||
        part.media_type != "" ||
        part.data_base64 != "" ||
        part.name != "" {
        return Err("Invalid text content part")
      }
    } else if part.kind == "image" {
      image_count += 1
      if image_count > 4 ||
        part.text != "" ||
        !["image/png", "image/jpeg", "image/webp"].contains(part.media_type) ||
        part.name.length() > 120 ||
        part.name.contains("\u{0000}") ||
        part.data_base64 == "" ||
        part.data_base64.length() > 11 * 1024 * 1024 {
        return Err("Invalid or unsupported Code image")
      }
      let bytes = @base64.decode(part.data_base64) catch {
        _ => return Err("Image data is not valid base64")
      }
      if bytes.length() == 0 ||
        bytes.length() > 8 * 1024 * 1024 ||
        @base64.encode(bytes) != part.data_base64 ||
        !mooncode_image_signature_valid(part.media_type, bytes) {
        return Err(
          "Image data exceeds the Code limit or is not canonical base64",
        )
      }
      total_bytes += bytes.length()
      if total_bytes > 16 * 1024 * 1024 {
        return Err("Code images exceed the 16 MB turn limit")
      }
    } else {
      return Err("Unsupported content part type")
    }
  }
  Ok(())
}

///|
fn mooncode_command_decode_content_parts(
  fields : Map[String, Json],
) -> Result[Array[MoonCodeContentPart], String] {
  let parts : Array[MoonCodeContentPart] = []
  match fields.get("content_parts") {
    None => Ok(parts)
    Some(Array(items)) => {
      for item in items {
        match mooncode_decode_content_part(item) {
          Ok(part) => parts.push(part)
          Err(error) => return Err(error)
        }
      }
      if parts.is_empty() {
        Err("content_parts must not be empty when supplied")
      } else {
        Ok(parts)
      }
    }
    Some(_) => Err("content_parts must be an array")
  }
}
