///|
fn pack_projection_schema_text() -> String {
  "{\"$schema\":\"https://json-schema.org/draft/2020-12/schema\",\"$id\":\"moontown.pack-projection.v1\",\"type\":\"object\",\"additionalProperties\":false,\"required\":[\"contract_id\",\"pack_id\",\"product_id\",\"version\",\"generated_at\",\"subjects\"],\"properties\":{\"contract_id\":{\"const\":\"moontown.pack-projection.v1\"},\"pack_id\":{\"type\":\"string\",\"minLength\":1},\"product_id\":{\"type\":\"string\",\"minLength\":1},\"version\":{\"type\":\"string\",\"minLength\":1},\"generated_at\":{\"type\":\"string\",\"minLength\":1},\"subjects\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"additionalProperties\":false,\"required\":[\"subject_ref\",\"schema_id\",\"title\",\"summary\",\"lifecycle_state\",\"attention\",\"place_refs\",\"related_refs\",\"workflow_refs\",\"run_refs\",\"evidence_refs\",\"operation_ids\",\"domain_payload\"],\"properties\":{\"subject_ref\":{\"type\":\"string\",\"minLength\":1},\"schema_id\":{\"type\":\"string\",\"minLength\":1},\"title\":{\"type\":\"string\",\"minLength\":1},\"summary\":{\"type\":\"string\",\"minLength\":1},\"lifecycle_state\":{\"type\":\"string\",\"minLength\":1},\"attention\":{\"type\":\"string\",\"minLength\":1},\"place_refs\":{\"type\":\"array\",\"uniqueItems\":true,\"items\":{\"type\":\"string\"}},\"related_refs\":{\"type\":\"array\",\"uniqueItems\":true,\"items\":{\"type\":\"string\"}},\"workflow_refs\":{\"type\":\"array\",\"uniqueItems\":true,\"items\":{\"type\":\"string\"}},\"run_refs\":{\"type\":\"array\",\"uniqueItems\":true,\"items\":{\"type\":\"string\"}},\"evidence_refs\":{\"type\":\"array\",\"uniqueItems\":true,\"items\":{\"type\":\"string\"}},\"operation_ids\":{\"type\":\"array\",\"uniqueItems\":true,\"items\":{\"type\":\"string\"}},\"domain_payload\":{\"type\":\"object\"}}}}}}\n"
}

///|
fn town_candidate_schema_text() -> String {
  "{\"$schema\":\"https://json-schema.org/draft/2020-12/schema\",\"$id\":\"moontown.pack-candidate-intake.v1\",\"type\":\"object\",\"additionalProperties\":false,\"required\":[\"contract_id\",\"candidate_ref\",\"origin_ref\",\"target_pack_id\",\"intake_operation_id\",\"submitted_by\",\"submitted_at\",\"title\",\"rationale\",\"claim_ceiling\",\"evidence_refs\",\"domain_payload\"],\"properties\":{\"contract_id\":{\"const\":\"moontown.pack-candidate-intake.v1\"},\"candidate_ref\":{\"type\":\"string\",\"minLength\":1},\"origin_ref\":{\"type\":\"string\",\"minLength\":1},\"target_pack_id\":{\"type\":\"string\",\"minLength\":1},\"intake_operation_id\":{\"type\":\"string\",\"minLength\":1},\"submitted_by\":{\"type\":\"string\",\"minLength\":1},\"submitted_at\":{\"type\":\"string\",\"minLength\":1},\"title\":{\"type\":\"string\",\"minLength\":1},\"rationale\":{\"type\":\"string\",\"minLength\":1},\"claim_ceiling\":{\"enum\":[\"observation\",\"research-evidence\",\"execution-result\",\"accepted-knowledge\"]},\"evidence_refs\":{\"type\":\"array\",\"uniqueItems\":true,\"items\":{\"type\":\"string\"}},\"domain_payload\":{\"type\":\"object\"}}}\n"
}

///|
fn provider_port_text(intake_operation_id : String) -> String {
  "# MoonTown pack projection provider\n\n" +
  "This domain pack publishes `moontown.pack-projection.v1` as a replaceable, read-only projection.\n\n" +
  "Bottom-up candidates enter through `\{intake_operation_id}`. Intake creates a reviewable domain draft and grants no downstream execution authority.\n"
}

///|
fn domain_schema_text(schema_id : String) -> String {
  "{\"$schema\":\"https://json-schema.org/draft/2020-12/schema\",\"$id\":\"\{schema_id}@1.0.0\",\"type\":\"object\",\"additionalProperties\":true}\n"
}
