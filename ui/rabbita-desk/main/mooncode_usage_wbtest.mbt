///|
test "Code shows only measured provider usage from the canonical turn" {
  let measured : Json = {
    "contract": "mooncode.turn_usage.v1",
    "measured": true,
    "response_count": 2,
    "input_tokens": 180,
    "output_tokens": 35,
    "cached_input_tokens": 65,
  }
  guard mooncode_canonical_usage_evidence(Some(measured), "turn-a") is Some(row) else {
    fail("measured usage")
  }
  assert_eq(row.item_id, "turn-a:usage")
  assert_eq(mooncode_evidence_label(row), "Usage")
  assert_eq(mooncode_evidence_label({ ..row, kind: "skill", }), "Skill")
  assert_true(row.detail.contains("180 input"))
  assert_true(row.detail.contains("65 cached input tokens"))
  assert_true(mooncode_canonical_usage_evidence(None, "turn-a") is None)
  assert_true(
    mooncode_canonical_usage_evidence(
      Some({ "contract": "mooncode.turn_usage.v1", "measured": false }),
      "turn-a",
    )
    is None,
  )
}
