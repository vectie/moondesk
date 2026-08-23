///|
async test "Pack Studio scaffolds validates installs and deactivates a bridge pack" {
  let parent = @fs.tmpdir(prefix="moondesk-pack-studio-source")
  let workspace = @fs.tmpdir(prefix="moondesk-pack-studio-workspace")
  let created = create_domain_pack_scaffold(
    {
      parent_root: parent,
      pack_id: "mobility-pack",
      display_name: "Mobility Pack",
      product_id: "mobility-pack",
      intake_operation_id: "mobility.candidate.intake",
      output_schema_id: "mobility-case",
    },
    workspace,
  )
  assert_true(created.valid)
  assert_true(created.bridge_ready)
  assert_true(
    @fs.exists(
      created.source_root +
      "/schemas/pack-candidate-acknowledgement.schema.json",
    ),
  )
  assert_eq(created.intake_operation_ids, ["mobility.candidate.intake"])
  let receipt = install_pack_source(
    {
      source_root: created.source_root,
      granted_authorities: [WorkspaceMutation],
      runtime_extensions: ["moontown"],
    },
    workspace,
  )
  assert_eq(receipt.pack_id, "mobility-pack")
  let installed = inspect_pack_source(created.source_root, workspace)
  assert_true(installed.active)
  assert_true(deactivate_pack({ pack_id: "mobility-pack" }, workspace))
  @fs.rmdir(parent, recursive=true)
  @fs.rmdir(workspace, recursive=true)
}

///|
async test "Pack Studio reports governed mailbox lifecycle artifacts" {
  let workspace = @fs.tmpdir(prefix="moondesk-pack-studio-mailbox")
  let inbox = workspace +
    "/.moonsuite/products/mobility-pack/pack-bridge/inbox/candidates"
  let receipts = workspace +
    "/.moonsuite/products/mobility-pack/pack-bridge/outbox/candidate-receipts"
  ensure_directory(inbox)
  ensure_directory(receipts)
  write_text(inbox + "/one.json", "{}")
  write_text(receipts + "/one.json", "{}")
  write_text(
    workspace +
    "/.moonsuite/products/mobility-pack/pack-bridge/outbox/projection.json",
    "{}",
  )
  let status = pack_bridge_mailbox_status(workspace, "mobility-pack")
  assert_true(status.stringify().contains("\"delivered_candidates\":1"))
  assert_true(status.stringify().contains("\"candidate_receipts\":1"))
  assert_true(status.stringify().contains("\"projection_present\":true"))
  @fs.rmdir(workspace, recursive=true)
}

///|
async test "Pack Studio adopts bridge without dropping custom manifest fields" {
  let parent = @fs.tmpdir(prefix="moondesk-pack-studio-adopt")
  let workspace = @fs.tmpdir(prefix="moondesk-pack-studio-adopt-workspace")
  let created = create_domain_pack_scaffold(
    {
      parent_root: parent,
      pack_id: "custom-pack",
      display_name: "Custom Pack",
      product_id: "custom-pack",
      intake_operation_id: "custom.original.intake",
      output_schema_id: "custom-record",
    },
    workspace,
  )
  let path = created.source_root + "/pack.json"
  let parsed = @json.parse(@fs.read_file(path).text())
  guard parsed is Object(fields) else { fail("expected manifest") }
  fields["app_presentation"] = { "contract_id": "custom.presentation.v1" }
  @fs.write_file(
    path,
    @encoding/utf8.encode(parsed.stringify(indent=2)),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
  let adopted = adopt_pack_bridge(
    {
      source_root: created.source_root,
      intake_operation_id: "custom.second.intake",
      output_schema_id: "custom-record",
    },
    workspace,
  )
  assert_true(adopted.bridge_ready)
  let text = @fs.read_file(path).text()
  assert_true(text.contains("app_presentation"))
  assert_true(text.contains("custom.second.intake"))
  @fs.rmdir(parent, recursive=true)
  @fs.rmdir(workspace, recursive=true)
}
