///|
async fn run_process_quiet(cmd : String, args : Array[String]) -> Int {
  @async.with_task_group(group => {
    let (pipe, output) = @process.read_from_process()
    let drain = group.spawn(() => {
      defer pipe.close()
      ignore(pipe.read_all())
    })
    let code = @process.run(cmd, args, stdout=output, stderr=output) catch {
      _ => -1
    }
    drain.wait()
    code
  }) catch {
    _ => -1
  }
}

///|
/// Runs a child process while draining both output streams. Callers receive
/// bounded text values instead of inheriting terminal output or losing a
/// canonical machine receipt.
async fn run_process_capture(
  cmd : String,
  args : Array[String],
) -> (Int, String, String) {
  @async.with_task_group(group => {
    let (stdout_pipe, stdout_output) = @process.read_from_process()
    let (stderr_pipe, stderr_output) = @process.read_from_process()
    let stdout_task = group.spawn(() => {
      defer stdout_pipe.close()
      stdout_pipe.read_all().text() catch {
        _ => ""
      }
    })
    let stderr_task = group.spawn(() => {
      defer stderr_pipe.close()
      stderr_pipe.read_all().text() catch {
        _ => ""
      }
    })
    let code = @process.run(
      cmd,
      args,
      stdout=stdout_output,
      stderr=stderr_output,
    ) catch {
      _ => -1
    }
    (code, stdout_task.wait(), stderr_task.wait())
  }) catch {
    _ => (-1, "", "")
  }
}
