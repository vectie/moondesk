///|
#cfg(target="js")
extern "js" fn portable_human_wire_encode(text : String) -> String =
  #| text => {
  #|   const bytes = new TextEncoder().encode(text); let binary = '';
  #|   for (let i = 0; i < bytes.length; i += 8192) binary += String.fromCharCode(...bytes.subarray(i, i + 8192));
  #|   return btoa(binary);
  #| }

///|
fn portable_human_wire_fixture() -> Json {
  let digest = portable_book_test_sha()
  {
    "contract_version": "moonproj.accepted-human-result.v1",
    "source_product": "moonproj",
    "provenance_scope": "captured_accepted_human_revision",
    "authenticity": "unsigned_source_observation",
    "authorizing": false,
    "task": {
      "record_id": "task:alpha",
      "record_version": "3",
      "record_digest": digest,
    },
    "report": {
      "record_id": "report:alpha",
      "record_version": "1",
      "record_digest": digest,
    },
    "revision": {
      "revision_id": "revision-1",
      "original_run_id": "run:1",
      "session_id": "session:1",
      "original_command_id": "command:1",
      "output_command_id": "command:2",
      "output_evidence_id": "report/result.txt:sha256:captured",
      "revision_snapshot_digest": digest,
    },
    "content": {
      "encoding": "base64",
      "media_type": "text/plain;charset=utf-8",
      "size_bytes": 5,
      "sha256": "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
      "data": "aGVsbG8=",
    },
  }
}

///|
fn portable_human_wire_change(
  section : String,
  field : String,
  value : Json,
) -> String {
  guard portable_human_wire_fixture() is Object(source) else {
    abort("fixture")
  }
  if section == "" {
    source[field] = value
  } else {
    guard source[section] is Object(fields) else { abort("fixture section") }
    fields[field] = value
  }
  Json::object(source).stringify()
}

///|
// Shared with the evidence harness and normal UI regression scheduler.
async fn portable_human_check_exact_wire() -> Unit {
  let wire = " \n" + portable_human_wire_fixture().stringify(indent=2) + "\r\n"
  let raw = portable_human_wire_encode(wire)
  guard validate_portable_book_human_result(raw, "source.json") is Ok(source) else {
    fail("valid unsigned captured observation must be previewable")
  }
  assert_eq(source.raw_base64, raw)
  assert_eq(source.raw_size_bytes, wire.length())
  assert_eq(source.content_text, "hello")
  assert_eq(source.content_size_bytes, 5)
  assert_eq(source.task.record_version, "3")
  assert_eq(
    source.revision.output_evidence_id,
    "report/result.txt:sha256:captured",
  )
  assert_true(portable_book_sha_valid(source.raw_sha256))
}

///|
async fn portable_human_check_empty_content() -> Unit {
  guard portable_human_wire_fixture() is Object(source) else { fail("fixture") }
  source["content"] = {
    "encoding": "base64",
    "media_type": "text/plain;charset=utf-8",
    "size_bytes": 0,
    "sha256": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "data": "",
  }
  let result = validate_portable_book_human_result(
    portable_human_wire_encode(Json::object(source).stringify()),
    "empty.json",
  )
  guard result is Ok(empty) else { fail("empty content is allowed") }
  assert_eq(empty.content_text, "")
  assert_eq(empty.content_size_bytes, 0)
}

///|
async fn portable_human_check_invalid_schema() -> Unit {
  for
    (section, field, value) in [
      ("", "contract_version", ToJson::to_json("wrong")),
      ("", "source_product", ToJson::to_json("other")),
      ("", "provenance_scope", ToJson::to_json("live")),
      ("", "authenticity", ToJson::to_json("signed")),
      ("", "authorizing", ToJson::to_json(true)),
      ("", "workspace_path", ToJson::to_json("/private/workspace")),
      ("task", "record_id", ToJson::to_json("../task")),
      ("task", "record_id", ToJson::to_json("..")),
      ("task", "record_version", ToJson::to_json("0")),
      ("task", "record_version", ToJson::to_json("01")),
      ("task", "record_version", ToJson::to_json("2147483648")),
      ("task", "record_version", ToJson::to_json(3)),
      ("report", "record_digest", ToJson::to_json("sha256:bad")),
      ("revision", "revision_id", ToJson::to_json("revision:1")),
      ("revision", "original_run_id", ToJson::to_json("/run")),
      ("revision", "output_evidence_id", ToJson::to_json("/absolute/path")),
      ("revision", "output_evidence_id", ToJson::to_json("C:/absolute/path")),
      ("revision", "output_evidence_id", ToJson::to_json("FiLe:secret")),
      ("revision", "output_evidence_id", ToJson::to_json("path\\secret")),
      ("revision", "output_evidence_id", ToJson::to_json("a\nsecret")),
      ("revision", "output_evidence_id", ToJson::to_json(" ")),
      ("content", "encoding", ToJson::to_json("utf8")),
      ("content", "media_type", ToJson::to_json("text/html")),
    ] {
    let wire = portable_human_wire_change(section, field, value)
    assert_true(
      validate_portable_book_human_result(
        portable_human_wire_encode(wire),
        "invalid.json",
      )
      is Err(_),
      msg=section + "." + field + " must be rejected",
    )
  }
}

///|
async fn portable_human_check_invalid_bytes() -> Unit {
  let wire = portable_human_wire_fixture().stringify()
  let duplicate = wire.replace_all(
    old="\"authorizing\":false",
    new="\"authorizing\":true,\"authorizing\":false",
  )
  assert_true(duplicate != wire)
  assert_true(
    validate_portable_book_human_result(
      portable_human_wire_encode(duplicate),
      "duplicate.json",
    )
    is Err(_),
  )
  for
    (field, value) in [
      ("data", ToJson::to_json("aGVsbG8")),
      ("data", ToJson::to_json("aGVsbG8=\n")),
      ("data", ToJson::to_json("aGVsbG9=")),
      ("data", ToJson::to_json("aGVsbG8_")),
      ("data", ToJson::to_json("aGVsAG8=")),
      ("data", ToJson::to_json("//////8=")),
      ("size_bytes", ToJson::to_json(4)),
      ("size_bytes", ToJson::to_json(-1)),
      ("size_bytes", ToJson::to_json(262145)),
      ("sha256", ToJson::to_json(portable_book_test_sha())),
    ] {
    let invalid = portable_human_wire_change("content", field, value)
    assert_true(
      validate_portable_book_human_result(
        portable_human_wire_encode(invalid),
        "invalid.json",
      )
      is Err(_),
    )
  }
  for
    raw in ["", "////", "e30", "e31=", portable_human_wire_encode(wire) + "\n"] {
    assert_true(
      validate_portable_book_human_result(raw, "invalid.json") is Err(_),
    )
  }
  assert_true(
    validate_portable_book_human_result(
      portable_human_wire_encode("\uFEFF" + wire),
      "bom.json",
    )
    is Err(_),
  )
}

///|
/// Test-only fixture builder uses the same standard browser crypto API to
/// create boundary-size bytes; the product still independently checks them.
#cfg(target="js")
extern "js" fn portable_human_boundary_fixture(
  wire : String,
  mode : String,
) -> @js.Promise =
  #| async (wire, mode) => {
  #|   const source = JSON.parse(wire);
  #|   const encode = bytes => { let b = ''; for (let i = 0; i < bytes.length; i += 8192) b += String.fromCharCode(...bytes.subarray(i, i + 8192)); return btoa(b); };
  #|   if (mode === 'body-max' || mode === 'body-over' || mode === 'unicode') {
  #|     const text = mode === 'unicode' ? '\ufeff完整文本\r\n<script>&"' : 'x'.repeat(mode === 'body-max' ? 262144 : 262145);
  #|     const bytes = new TextEncoder().encode(text);
  #|     source.content.size_bytes = bytes.length;
  #|     source.content.data = encode(bytes);
  #|     source.content.sha256 = 'sha256:' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), b => b.toString(16).padStart(2, '0')).join('');
  #|   }
  #|   if (mode === 'id-over') source.task.record_id = 'a'.repeat(129);
  #|   if (mode === 'evidence-max') source.revision.output_evidence_id = '文'.repeat(1365) + 'a';
  #|   if (mode === 'evidence-over') source.revision.output_evidence_id = '文'.repeat(1366);
  #|   if (mode === 'version-max') source.task.record_version = '2147483647';
  #|   let text = JSON.stringify(source);
  #|   if (mode === 'raw-max' || mode === 'raw-over') text += ' '.repeat((mode === 'raw-max' ? 524288 : 524289) - text.length);
  #|   return encode(new TextEncoder().encode(text));
  #| }

///|
async fn portable_human_check_byte_boundaries() -> Unit {
  let wire = portable_human_wire_fixture().stringify()
  for mode in ["body-max", "raw-max", "evidence-max", "version-max", "unicode"] {
    let raw : String = portable_human_boundary_fixture(wire, mode).wait().cast()
    guard validate_portable_book_human_result(raw, "boundary.json")
      is Ok(source) else {
      fail("valid boundary rejected: " + mode)
    }
    assert_eq(source.raw_base64, raw)
    if mode == "body-max" {
      assert_eq(source.content_size_bytes, 262144)
    }
    if mode == "raw-max" {
      assert_eq(source.raw_size_bytes, 524288)
    }
    if mode == "unicode" {
      assert_eq(source.content_text, "\uFEFF完整文本\r\n<script>&\"")
    }
  }
  for mode in ["body-over", "raw-over", "evidence-over", "id-over"] {
    let raw : String = portable_human_boundary_fixture(wire, mode).wait().cast()
    assert_true(
      validate_portable_book_human_result(raw, "boundary.json") is Err(_),
      msg="oversize must be rejected: " + mode,
    )
  }
}

///|
/// Opt-in source evidence from the real MoonProj export handler. Node and
/// filesystem access are confined to this test-only fixture reader.
#cfg(target="js")
extern "js" fn portable_human_producer_fixture(name : String) -> String =
  #| name => {
  #|   if (typeof process === 'undefined' || !process.env.MOONDESK_HUMAN_RESULT_FIXTURES) return '';
  #|   if (!['unicode', 'unicode-v2', 'empty', 'max'].includes(name)) throw new Error('Unknown fixture');
  #|   const fs = process.getBuiltinModule('fs'), root = process.env.MOONDESK_HUMAN_RESULT_FIXTURES;
  #|   return JSON.stringify({ raw_base64: fs.readFileSync(root + '/' + name + '.json').toString('base64'), body_text: fs.readFileSync(root + '/' + name + '.body.txt').toString('utf8') });
  #| }

///|
async fn portable_human_check_actual_producer() -> Unit {
  for
    (name, raw_digest) in [
      (
        "unicode", "9bb4d2fedb6dd09d614458b7407a3899be088e85b948ebfe483fbfb3b2ab0589",
      ),
      (
        "unicode-v2", "b6f3897249402758d5bfee2c8adfac2e90c0cf1cc2464c7ed4431fb64dd1dc23",
      ),
      (
        "empty", "17fa9d1f60f6d1d0512235a3e7335dcfd3261f94e22b0ee34c41e75aae34c266",
      ),
      (
        "max", "72b24fba8fb92050c4ea07c65b2959f9edfcb2f5496388bdb0eda25ac1b45b07",
      ),
    ] {
    let fixture = portable_human_producer_fixture(name)
    if fixture == "" {
      return
    }
    guard @json.parse(fixture)
      is { "raw_base64": String(raw), "body_text": String(body), .. } else {
      fail("invalid fixture envelope")
    }
    guard validate_portable_book_human_result(raw, name + ".json") is Ok(source) else {
      fail("real exported source rejected: " + name)
    }
    assert_eq(source.raw_base64, raw)
    assert_eq(source.raw_sha256, "sha256:" + raw_digest)
    assert_eq(source.content_text, body)
    if name == "empty" {
      assert_eq(source.content_size_bytes, 0)
    }
    if name == "max" {
      assert_eq(source.content_size_bytes, 262144)
    }
    let request = portable_book_prepare_body(
      "/library-a",
      portable_book_test_id(),
      "1.2.3",
      [],
      accepted_human_result_base64=source.raw_base64,
    )
    assert_eq(handoff_text(request, "accepted_human_result_base64"), raw)
  }
}

///|
test "accepted human result wire preserves bytes and rejects invalid boundaries" {
  @js.async_test(async fn() {
    portable_human_check_exact_wire()
    portable_human_check_empty_content()
    portable_human_check_invalid_schema()
    portable_human_check_invalid_bytes()
    portable_human_check_byte_boundaries()
    // This helper additionally verifies retained real exports when the
    // existing opt-in fixture directory is supplied by the evidence runner.
    portable_human_check_actual_producer()
  })
}
