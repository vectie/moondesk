///|
async test "MoonFlow and supervisor requests cannot execute command-like marker payloads" {
  @moonlib/fsx.with_temporary_directory("moondesk-sandbox-client-marker-", root => {
    let marker = @pathx.join(root, "host-command-ran")
    let operations = [
      MoonFlowValidateGraph,
      MoonFlowImportGraph,
      MoonFlowControl,
      MoonFlowInspectCollaboration,
      MoonFlowListHandovers,
      MoonFlowRecoverReceiverReceipts,
      MoonFlowReceiveOperatorReceipt,
      MoonFlowCommitPackHandoff,
      SupervisorSubmitBookkeeperOutcome,
    ]
    for operation in operations {
      let result = execution_sandbox_client_submit({
        operation,
        input: { "command": "/usr/bin/touch", "args": [marker], "cwd": root },
      })
      assert_true(result is Err(SandboxUnavailable))
      assert_false(@fs.exists(marker))
    }
  })
}
