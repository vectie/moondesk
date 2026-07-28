///|
test "Flow capability evidence has stable precedence and separate facts" {
  let supported : Json = {
    "supported": true,
    "platform": "macos",
    "architecture": "arm64",
  }
  let unsupported : Json = {
    "supported": false,
    "platform": "unsupported",
    "architecture": "unsupported",
  }
  let platform = moonflow_capability_evidence_from_values(
    unsupported, true, true, true, "/runtime",
  )
  assert_false(json_bool(platform, "available", default=true))
  assert_eq(json_string(platform, "reason", default=""), "unsupported-platform")
  let command = moonflow_capability_evidence_from_values(
    supported, false, false, false, "",
  )
  assert_eq(
    json_string(command, "reason", default=""),
    "runtime-command-unavailable",
  )
  let missing = moonflow_capability_evidence_from_values(
    supported, true, false, false, "",
  )
  assert_eq(
    json_string(missing, "reason", default=""),
    "runtime-root-not-configured",
  )
  let invalid = moonflow_capability_evidence_from_values(
    supported, true, true, false, "/missing",
  )
  assert_eq(
    json_string(invalid, "reason", default=""),
    "runtime-root-unavailable",
  )
  let ready = moonflow_capability_evidence_from_values(
    supported, true, true, true, "/runtime",
  )
  assert_true(json_bool(ready, "available", default=false))
  assert_eq(json_string(ready, "reason", default=""), "capability-ready")
  let installation = json_object_field(ready, "installation_evidence").unwrap()
  assert_true(json_bool(installation, "installed", default=false))
  let configuration = json_object_field(ready, "configuration_evidence").unwrap()
  assert_true(json_bool(configuration, "configured", default=false))
  assert_true(json_bool(configuration, "valid", default=false))
}
