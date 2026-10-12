///|
/// This mirrors the existing v1 Book binding preflight for a reviewable preview.
/// MoonBook remains the importer and checks it again before creating a Book.
/// The digest is integrity metadata, never a publisher signature or approval.
fn agent_import_checked_binding(binding : Json, source : Json) -> Json raise {
  guard binding is Object(fields) &&
    source is Object(source_fields) &&
    fields.get("source") is Some(Object(expected_fields)) &&
    fields.get("contract") ==
    Some("moontown.portable-listing-binding.v1".to_json()) &&
    fields.get("binding_revision") == Some((1 : Int).to_json()) &&
    fields.get("reuse_mode") == Some("local_file_import".to_json()) &&
    fields.get("verification_scope") ==
    Some("publisher_declared_expected_source".to_json()) else {
    fail("Choose the original v1 Town binding received with this package")
  }
  for key in ["listing_id", "publisher_principal_id", "tenant_id"] {
    guard fields.get(key) is Some(String(value)) && value.trim() != "" else {
      fail("The Town binding is missing its source identity")
    }
  }
  guard expected_fields.get("package_filename") is Some(String(filename)) &&
    filename != "" else {
    fail("The Town binding has no package filename")
  }
  let expected_source = source_fields.copy()
  expected_source["package_filename"] = filename.to_json()
  guard Json::object(expected_source) == Json::object(expected_fields) else {
    fail(
      "The Town binding describes a different package. Choose its unchanged .moonbook-agent file",
    )
  }
  let unsigned : Json = {
    "contract": fields["contract"],
    "listing_id": fields["listing_id"],
    "publisher_principal_id": fields["publisher_principal_id"],
    "tenant_id": fields["tenant_id"],
    "binding_revision": fields["binding_revision"],
    "source": Json::object(expected_source),
    "reuse_mode": fields["reuse_mode"],
    "verification_scope": fields["verification_scope"],
  }
  guard fields.get("binding_digest") is Some(String(digest)) &&
    agent_import_hash(@encoding/utf8.encode(unsigned.stringify())) == digest else {
    fail(
      "The Town binding digest does not match. Use the original binding file",
    )
  }
  binding
}

///|
async fn agent_import_retained_binding(
  directory : String,
  manifest : Json,
  source : Json,
) -> Json? {
  let digest = json_string(manifest, "town_binding_sha256", default="")
  if digest == "" {
    return None
  }
  let binding = agent_import_read_json(directory + "/town-binding.json", 131072)
  guard agent_import_hash(@encoding/utf8.encode(binding.stringify())) == digest else {
    fail("The retained Town binding changed after inspection")
  }
  Some(agent_import_checked_binding(binding, source))
}

///|
async fn agent_import_exact_receipt(
  destination : String,
  binding : Json,
  installation : Json,
) -> Json {
  let receipt = agent_import_read_json(
    destination + "/state/portable-source-binding.json",
    131072,
  )
  guard receipt is Object(fields) &&
    binding is Object(expected) &&
    fields.get("contract") ==
    Some("moonbook.portable_import_receipt.v1".to_json()) &&
    fields.get("status") == Some("complete".to_json()) &&
    fields.get("member_bytes_verified") == Some(true.to_json()) &&
    fields.get("local_target_root") == Some(destination.to_json()) &&
    json_string(receipt, "local_book_id", default="") ==
    destination.split("/").last().unwrap_or("").to_owned() &&
    json_string(receipt, "installation_receipt_id", default="") ==
    json_string(installation, "receipt_id", default="") &&
    json_string(receipt, "installation_receipt_id", default="") != "" else {
    fail("The exact import receipt is missing or incomplete")
  }
  let imported_at : Int64 = @json.from_json(
    fields.get("imported_at").unwrap_or(Json::null()),
  )
  guard imported_at >= 0L else {
    fail("The exact import receipt timestamp is invalid")
  }
  for
    key in [
      "source", "listing_id", "publisher_principal_id", "tenant_id", "binding_digest",
    ] {
    guard fields.get(key) == expected.get(key) else {
      fail("The exact import receipt belongs to another Town binding")
    }
  }
  receipt
}
