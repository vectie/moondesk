///|
/// An integrity-checked offline observation. No signature or current acceptance
/// authority is asserted by importing this file.
priv struct AgentAcceptedHumanResult {
  source : Bytes
  content : Bytes
  source_sha256 : String
}

///|
fn agent_human_result_hash(bytes : Bytes) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn agent_human_result_id(value : String, revision? : Bool = false) -> Bool {
  value.length() > 0 &&
  value.length() <= 128 &&
  value != "." &&
  value != ".." &&
  value
  .iter()
  .all(c => {
    c is ('0'..='9' | 'a'..='z' | 'A'..='Z' | '_' | '-') ||
    (!revision && c is ('.' | ':'))
  })
}

///|
fn agent_human_result_version(value : String) -> Bool {
  value.length() > 0 &&
  value.length() <= 10 &&
  value[0] is ('1'..='9') &&
  value.iter().all(c => c is ('0'..='9')) &&
  (value.length() < 10 || value.compare("2147483647") <= 0)
}

///|
fn agent_human_result_evidence(value : String) -> Bool {
  @encoding/utf8.encode(value).length() <= 4096 &&
  !value.trim().is_empty() &&
  !value.iter().any(c => c < ' ' || c == '\u007f') &&
  !value.contains("\\") &&
  !value.has_prefix("/") &&
  !value.to_lower().has_prefix("file:") &&
  !(value.length() >= 3 &&
  value[0] is ('a'..='z' | 'A'..='Z') &&
  value[1] == ':' &&
  value[2] == '/')
}

///|
fn agent_human_result_record(value : Json) -> Bool {
  value is Object(fields) &&
  fields.length() == 3 &&
  fields.get("record_id") is Some(String(id)) &&
  fields.get("record_version") is Some(String(version)) &&
  fields.get("record_digest") is Some(String(digest)) &&
  agent_human_result_id(id) &&
  agent_human_result_version(version) &&
  agent_export_sha_valid(digest)
}

///|
// Every accepted object has a fixed key set. Counting structural colons after
// JSON parsing also rejects duplicate keys that a map parser could overwrite.
fn agent_human_result_key_count(text : String) -> Int {
  let mut quoted = false
  let mut escaped = false
  let mut count = 0
  for c in text {
    if quoted {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        quoted = false
      }
    } else if c == '"' {
      quoted = true
    } else if c == ':' {
      count += 1
    }
  }
  count
}

///|
fn agent_human_result_decode(
  encoded : String,
) -> Result[AgentAcceptedHumanResult, String] {
  guard encoded.length() > 0 && encoded.length() <= 699052 else {
    return Err("Accepted human result source must contain at most 512 KiB")
  }
  let source = @base64.decode(encoded, ignore_whitespace=false) catch {
    _ => return Err("Accepted human result source contains invalid base64")
  }
  guard source.length() > 0 &&
    source.length() <= 512 * 1024 &&
    @base64.encode(source, padding=true) == encoded else {
    return Err("Accepted human result source bytes are invalid or too large")
  }
  let text = @encoding/utf8.decode(source) catch {
    _ => return Err("Accepted human result source must be UTF-8 JSON")
  }
  let envelope = @json.parse(text, max_nesting_depth=4) catch {
    _ => return Err("Accepted human result source must be valid JSON")
  }
  guard envelope is Object(fields) &&
    fields.length() == 9 &&
    agent_human_result_key_count(text) == 27 &&
    fields.get("contract_version") ==
    Some(Json::string("moonproj.accepted-human-result.v1")) &&
    fields.get("source_product") == Some(Json::string("moonproj")) &&
    fields.get("provenance_scope") ==
    Some(Json::string("captured_accepted_human_revision")) &&
    fields.get("authenticity") ==
    Some(Json::string("unsigned_source_observation")) &&
    fields.get("authorizing") is Some(False) &&
    fields.get("task") is Some(task) &&
    fields.get("report") is Some(report) &&
    agent_human_result_record(task) &&
    agent_human_result_record(report) &&
    fields.get("revision") is Some(Object(revision)) &&
    revision.length() == 7 &&
    revision.get("revision_id") is Some(String(revision_id)) &&
    agent_human_result_id(revision_id, revision=true) &&
    revision.get("revision_snapshot_digest") is Some(String(snapshot_digest)) &&
    agent_export_sha_valid(snapshot_digest) else {
    return Err(
      "Accepted human result has an unsupported or invalid exact schema",
    )
  }
  for
    field in [
      "original_run_id", "session_id", "original_command_id", "output_command_id",
    ] {
    guard revision.get(field) is Some(String(id)) && agent_human_result_id(id) else {
      return Err("Accepted human result has an invalid revision identity")
    }
  }
  guard revision.get("output_evidence_id") is Some(String(evidence)) &&
    agent_human_result_evidence(evidence) else {
    return Err(
      "Accepted human result has an invalid portable evidence identity",
    )
  }
  guard fields.get("content") is Some(Object(content)) &&
    content.length() == 5 &&
    content.get("encoding") == Some(Json::string("base64")) &&
    content.get("media_type") == Some(Json::string("text/plain;charset=utf-8")) &&
    content.get("size_bytes") is Some(Number(size, ..)) &&
    size >= 0.0 &&
    size <= 262144.0 &&
    size == size.to_int().to_double() &&
    content.get("sha256") is Some(String(digest)) &&
    agent_export_sha_valid(digest) &&
    content.get("data") is Some(String(data)) &&
    data.length() <= 349528 else {
    return Err("Accepted human result content metadata is invalid")
  }
  let bytes = @base64.decode(data, ignore_whitespace=false) catch {
    _ => return Err("Accepted human result content contains invalid base64")
  }
  guard bytes.length() == size.to_int() &&
    @base64.encode(bytes, padding=true) == data &&
    agent_human_result_hash(bytes) == digest else {
    return Err("Accepted human result content integrity check failed")
  }
  let body = @encoding/utf8.decode(bytes) catch {
    _ => return Err("Accepted human result content must be UTF-8 text")
  }
  guard !body.contains("\u0000") else {
    return Err("Accepted human result content cannot contain NUL bytes")
  }
  Ok({ source, content: bytes, source_sha256: agent_human_result_hash(source), })
}

///|
fn agent_human_result_artifact_id(source : AgentAcceptedHumanResult) -> String {
  "source-" + source.source_sha256[7:].to_owned()
}

///|
fn agent_human_result_staging_relative(id : String) -> String {
  "book/agents/.preparing-" + id + "/accepted-human-result"
}

///|
fn agent_human_result_selection(
  id : String,
  source : AgentAcceptedHumanResult,
) -> Json {
  let relative = agent_human_result_staging_relative(id)
  {
    "artifact_id": agent_human_result_artifact_id(source),
    "label": "Captured accepted human result (unsigned source observation)",
    "mime_type": "application/json",
    "included": true,
    "files": [
      { "source_path": relative + "/source.json", "path": "source.json" },
      { "source_path": relative + "/content.txt", "path": "content.txt" },
    ],
  }
}

///|
fn agent_human_result_inspection_matches(
  result : Json,
  source : AgentAcceptedHumanResult,
) -> Bool {
  guard result is { "inspection": { "files": Array(files), .. }, .. } else {
    return false
  }
  let prefix = "portable/outputs/" +
    agent_human_result_artifact_id(source) +
    "/"
  for
    (name, bytes) in [
      ("source.json", source.source),
      ("content.txt", source.content),
    ] {
    let matching = files.filter(file => {
      json_string(file, "path", default="") == prefix + name
    })
    guard matching.length() == 1 &&
      matching[0]
      is {
        "digest": String(digest),
        "size_bytes": Number(size, ..),
        "role": String("artifact"),
        ..
      } &&
      digest == agent_human_result_hash(bytes) &&
      size == bytes.length().to_double() else {
      return false
    }
  }
  true
}

///|
async fn agent_human_result_stage(
  root : String,
  id : String,
  source : AgentAcceptedHumanResult,
) -> Unit {
  let relative = agent_human_result_staging_relative(id)
  guard resolve_workspace_write_path(root, relative) is Some((absolute, _)) &&
    absolute == root + "/" + relative else {
    fail("Accepted human result staging is not confined to this Book")
  }
  @fs.mkdir(absolute, permission=0o700)
  @fs.write_file(
    absolute + "/source.json",
    source.source,
    create_mode=CreateNew,
    permission=0o600,
  )
  @fs.write_file(
    absolute + "/content.txt",
    source.content,
    create_mode=CreateNew,
    permission=0o600,
  )
}

///|
async fn agent_human_result_retained_matches(
  workspace : @desk.DeskWorkspace,
  relative : String,
  source : AgentAcceptedHumanResult?,
) -> Bool {
  let base = relative + "/accepted-human-result"
  match source {
    None => !@fs.exists(workspace.root_path + "/" + base)
    Some(source) => {
      for
        (name, expected) in [
          ("source.json", source.source),
          ("content.txt", source.content),
        ] {
        guard agent_export_existing_path(workspace.root_path, base + "/" + name)
          is Some(path) &&
          @fs.kind(path, follow_symlink=false) == Regular else {
          return false
        }
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        guard file.size() == expected.length().to_int64() &&
          file.read_exactly(expected.length()) == expected &&
          file.size() == expected.length().to_int64() else {
          return false
        }
      }
      true
    }
  }
}
