///|
async test "mooncode writes and lists native session records outside generic agent store" {
  let root = "/tmp/moondesk-mooncode-session-record-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let session : Json = {
    "id": session_id,
    "component": "mooncode",
    "protocol": @mooncode.protocol_version(),
    "workspace_root": root,
    "messages": [],
  }
  write_mooncode_session_record(root, session)
  match read_mooncode_session_record(root, session_id) {
    Some(read_back) => {
      assert_eq(json_string(read_back, "id", default=""), session_id)
      assert_eq(json_string(read_back, "component", default=""), "mooncode")
    }
    None => fail("MoonCode session record should be readable")
  }
  let records = read_mooncode_session_records(root)
  assert_eq(records.length(), 1)
  assert_true(@fs.exists(mooncode_session_record_path(root, session_id)))
}

///|
async test "mooncode response enrichment uses MoonCode defaults only" {
  let root = "/tmp/moondesk-mooncode-response-defaults-wbtest-" +
    @async.now().to_string()
  let session : Json = {
    "id": "session-a",
    "component": "mooncode",
    "protocol": @mooncode.protocol_version(),
    "workspace_root": root,
    "mooncode_runtime_session_id": "session-a",
  }
  let enriched = enrich_mooncode_session_for_response(root, session)
  assert_eq(json_string(enriched, "title", default=""), "MoonCode Session")
  assert_eq(json_string(enriched, "cwd", default=""), root)
  assert_eq(json_array_items(enriched, "transcript").length(), 0)
}
