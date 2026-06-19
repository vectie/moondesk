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
