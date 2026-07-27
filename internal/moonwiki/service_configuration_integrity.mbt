///|
fn service_configuration_integrity_from_values(
  configured : Bool,
  command_available : Bool,
  working_directory_available : Bool,
) -> Json {
  {
    "valid": configured && command_available && working_directory_available,
    "reason": if !configured {
      "not-configured"
    } else if !command_available {
      "command-unavailable"
    } else if !working_directory_available {
      "working-directory-unavailable"
    } else {
      "configuration-valid"
    },
  }
}

///|
async fn service_command_available(
  command : String,
  working_directory : String,
) -> Bool {
  if command == "" {
    return false
  }
  if command.contains("/") {
    let executable = if @pathx.is_absolute(command) {
      command
    } else {
      @pathx.join(working_directory, command)
    }
    @fsx.exists(executable) &&
    !is_directory(executable) &&
    @async.with_timeout_opt(2000, () => {
      run_process_quiet("test", ["-x", executable])
    }).unwrap_or(-2) ==
    0
  } else {
    let captured = @async.with_timeout_opt(2000, () => {
      run_process_capture("which", [command])
    })
    match captured {
      Some((code, stdout, _)) => code == 0 && stdout.trim() != ""
      None => false
    }
  }
}

///|
async fn service_configuration_integrity(
  command : String,
  working_directory : String,
) -> Json {
  service_configuration_integrity_from_values(
    command != "",
    service_command_available(command, working_directory),
    is_directory(working_directory),
  )
}
