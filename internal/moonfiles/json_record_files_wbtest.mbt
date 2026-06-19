///|
async test "json record file IO preserves object records" {
  let root = "/tmp/moondesk-moonfiles-json-record-wbtest-" +
    @async.now().to_string()
  let path = @pathx.join(root, "nested/record.json")
  write_json_record_file(path, { "id": "record-a", "ready": true })
  match read_json_record_file(path) {
    Some({ "id": String("record-a"), "ready": True, .. }) => ()
    None => fail("expected persisted JSON record")
    Some(_) => fail("persisted JSON record lost fields")
  }
  match read_json_record_file(@pathx.join(root, "missing.json")) {
    Some(_) => fail("missing record should not parse")
    None => ()
  }
  @fsx.write_to_file(@pathx.join(root, "array.json"), "[]\n", create=0o644)
  match read_json_record_file(@pathx.join(root, "array.json")) {
    Some(_) => fail("array JSON should not be accepted as a record")
    None => ()
  }
  match read_json_file_or_object(@pathx.join(root, "array.json")) {
    Array(items) => assert_eq(items.length(), 0)
    _ => fail("generic JSON file reader should preserve arrays")
  }
  let names = read_directory_names(root, include_hidden=false)
  assert_true(names.contains("array.json"))
  assert_true(names.contains("nested"))
}
