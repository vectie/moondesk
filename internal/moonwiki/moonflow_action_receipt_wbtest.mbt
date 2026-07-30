///|
async test "MoonFlow execution receipt persists through confined IO without changing payload" {
  let root = @fs.tmpdir(prefix="moondesk-moonflow-receipt-")
  let receipt : Json = {
    "contract_id": "moondesk.moonflow-action-receipt.v1",
    "run_id": "run-001",
    "action_id": "approve",
  }
  let relative = ".moondesk/action-receipts/moonflow-run-001-approve.json"
  assert_true(
    @fsx.write_confined_text(root, relative, receipt.stringify(), create=0o600),
  )
  let persisted = @json.parse(@fs.read_file(@pathx.join(root, relative)).text())
  assert_eq(persisted, receipt)
  @fs.symlink(target="/tmp", @pathx.join(root, "escape"))
  assert_false(
    @fsx.write_confined_text(root, "escape/receipt.json", receipt.stringify()),
  )
}
