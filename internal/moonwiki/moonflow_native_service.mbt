///|
async fn moonflow_native_service(
  workspace : String,
  operation : @trusted_host.MoonFlowServiceOperation,
) -> Result[Json, String] {
  let runtime = match @trusted_host.moonflow_service_runtime() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  @trusted_host.run_moonflow_service(runtime, workspace, operation)
}

///|
fn moonflow_native_error(result : Result[Json, String]) -> String {
  match result {
    Err(message) => message
    Ok(_) => ""
  }
}
