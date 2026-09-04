///|
test "agent preferences select the exact revisioned record" {
  let records : Array[Json] = [
    { "id": "pref-a", "revision": 2, "label": "Tone" },
    { "id": "pref-b", "revision": 5, "label": "Spelling" },
  ]
  let selected = agent_preference_previous(records, "pref-b").unwrap()
  assert_eq(json_int(selected, "revision", default=0), 5)
  assert_true(agent_preference_previous(records, "pref-missing") is None)
}

///|
async test "preference records are written atomically with private permissions" {
  let root = "/tmp/moondesk-agent-preferences-" +
    @desk.stable_id("test", @async.now().to_string())
  @moonlib/fsx.make_directory(root, recursive=true, exists_ok=true)
  let path = @pathx.join(root, "agent-memory.json")
  write_preference_records(path, [
    { "id": "pref-a", "revision": 1, "label": "Tone" },
  ])
  let records = read_json_array_file(path)
  assert_eq(records.length(), 1)
  assert_eq(json_string(records[0], "id", default=""), "pref-a")
}
