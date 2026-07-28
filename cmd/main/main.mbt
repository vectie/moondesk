///|
async fn main {
  let args = @env.args()
  match args[1:] {
    ["serve", .. rest] => run_serve(rest.to_owned())
    ["desktop", .. rest] => run_desktop(rest.to_owned())
    ["bundle", .. rest] => if !run_bundle(rest.to_owned()) { @sys.exit(1) }
    ["release", .. rest] => if !run_release(rest.to_owned()) { @sys.exit(1) }
    ["launch-agent", .. rest] => run_launch_agent(rest.to_owned())
    ["install-launch-agent", .. rest] =>
      run_install_launch_agent(rest.to_owned())
    ["uninstall-launch-agent", .. rest] =>
      run_uninstall_launch_agent(rest.to_owned())
    ["launch-agent-status", .. rest] => run_launch_agent_status(rest.to_owned())
    ["lepusa", .. rest] => ignore(run_lepusa_integration(rest.to_owned()))
    ["doctor", .. rest] => run_doctor(rest.to_owned())
    [] => print_usage()
    _ => print_usage()
  }
}
