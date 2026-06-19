///|
pub async fn read_json_record_file(path : String) -> Json? {
  if !@fs.exists(path) {
    return None
  }
  let parsed = @json.parse(@fs.read_file(path).text()) catch {
    _ => return None
  }
  match parsed {
    Object(_) => Some(parsed)
    _ => None
  }
}

///|
pub async fn read_json_record_file_or_empty(path : String) -> Json {
  match read_json_record_file(path) {
    Some(record) => record
    None => Json::object({})
  }
}

///|
pub async fn read_json_file_or_object(path : String) -> Json {
  if !@fs.exists(path) {
    return Json::object({})
  }
  @json.parse(@fs.read_file(path).text()) catch {
    _ => Json::object({})
  }
}

///|
pub async fn read_directory_names(
  path : String,
  include_hidden? : Bool = true,
) -> Array[String] {
  let dir = @fs.opendir(path) catch { _ => return [] }
  defer dir.close()
  let names = dir.read_all(include_hidden~) catch { _ => return [] }
  names.sort()
  names
}

///|
pub async fn write_json_record_file(path : String, record : Json) -> Unit {
  match record {
    Object(_) => ()
    _ => fail("json record must be an object")
  }
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  @fsx.write_to_file(path, record.stringify(indent=2) + "\n", create=0o644)
}
