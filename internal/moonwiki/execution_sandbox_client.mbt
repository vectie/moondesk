///|
/// Operations that MoonDesk may request from an isolated executor. The client
/// boundary intentionally contains no process primitive and no host fallback.
priv enum ExecutionSandboxOperation {
  MoonFlowValidateGraph
  MoonFlowImportGraph
  MoonFlowControl
  MoonFlowInspectCollaboration
  MoonFlowListHandovers
  MoonFlowRecoverReceiverReceipts
  MoonFlowReceiveOperatorReceipt
  MoonFlowCommitPackHandoff
  SupervisorSubmitBookkeeperOutcome
}

///|
priv struct ExecutionSandboxRequest {
  operation : ExecutionSandboxOperation
  input : Json
}

///|
priv enum ExecutionSandboxClientError {
  SandboxUnavailable
}

///|
fn execution_sandbox_client_available() -> Bool {
  false
}

///|
fn execution_sandbox_client_submit(
  request : ExecutionSandboxRequest,
) -> Result[Json, ExecutionSandboxClientError] {
  // Keep the request typed and consumed so wiring a backend later is an
  // explicit implementation change. Never reinterpret payload fields as a
  // local command, executable, cwd, or argument vector.
  match request.operation {
    MoonFlowValidateGraph => ()
    MoonFlowImportGraph => ()
    MoonFlowControl => ()
    MoonFlowInspectCollaboration => ()
    MoonFlowListHandovers => ()
    MoonFlowRecoverReceiverReceipts => ()
    MoonFlowReceiveOperatorReceipt => ()
    MoonFlowCommitPackHandoff => ()
    SupervisorSubmitBookkeeperOutcome => ()
  }
  ignore(request.input)
  Err(SandboxUnavailable)
}

///|
fn execution_sandbox_unavailable_message() -> String {
  "Execution sandbox is unavailable; MoonDesk refused host execution"
}
