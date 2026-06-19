///|
fn run_doctor(args : Array[String]) -> Unit {
  let root = match args {
    [root] => root
    _ => ".."
  }
  let config = @host.default_config(root)
  println("Moondesk doctor")
  println("configured root: \{config.roots[0].path}")
  println("ui package: ui/rabbita-desk")
  println("host mode: scoped local reads and inbox writes only")
}

///|
fn print_usage() -> Unit {
  println(
    (
      #|Moondesk
      #|
      #|Usage:
      #|  moon run cmd/main -- doctor [root]
      #|  moon run cmd/main -- serve [root] [--ui ui/rabbita-desk/dist] [--host 127.0.0.1] [--port 4188] [--open]
      #|  moon run cmd/main -- desktop [root] [--ui ui/rabbita-desk/dist] [--host 127.0.0.1] [--port 4188]
      #|  moon run cmd/main -- bundle [root] [--ui ui/rabbita-desk/dist] [--out dist] [--host 127.0.0.1] [--port 4199] [--shell native-window|browser] [--sign-identity -] [--skip-sign] [--no-archive]
      #|  moon run cmd/main -- release [root] [bundle options] [--notary-profile keychain-profile] [--no-staple] [--no-dmg]
      #|  moon run cmd/main -- launch-agent [root] [--service desk|town] [--out dist/app.vectie.moondesk.plist] [--port 4188]
      #|  moon run cmd/main -- install-launch-agent [root] [--service desk|town] [--port 4188]
      #|  moon run cmd/main -- uninstall-launch-agent [--service desk|town]
      #|  moon run cmd/main -- launch-agent-status [--service desk|town]
      #|
      #|Build the UI first with:
      #|  npm --prefix ui/rabbita-desk run build
    ),
  )
}
