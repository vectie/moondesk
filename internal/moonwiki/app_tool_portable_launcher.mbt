///|
fn app_tool_portable_server_script_relative_path() -> String {
  @pathx.join(app_tool_portable_bundle_relative_dir(), "serve.py")
}

///|
fn app_tool_portable_run_script_relative_path() -> String {
  @pathx.join(app_tool_portable_bundle_relative_dir(), "run-local.command")
}

///|
async fn app_tool_write_static_host_launcher(bundle_root : String) -> Unit {
  let server_path = @pathx.join(bundle_root, "serve.py")
  let run_path = @pathx.join(bundle_root, "run-local.command")
  @fsx.write_to_file(
    server_path,
    app_tool_static_host_server_py(),
    create=0o755,
  )
  @fsx.write_to_file(run_path, app_tool_static_host_run_script(), create=0o755)
  @fs.chmod(server_path, 0o755) catch {
    _ => ()
  }
  @fs.chmod(run_path, 0o755) catch {
    _ => ()
  }
}

///|
fn app_tool_static_host_server_py() -> String {
  [
    "#!/usr/bin/env python3", "import functools", "import http.server", "import os",
    "import socket", "import socketserver", "import sys", "import webbrowser", "",
    "ROOT = os.path.abspath(os.path.dirname(__file__))", "PORT = int(os.environ.get('MOONDESK_APP_TOOL_PORT', sys.argv[1] if len(sys.argv) > 1 else '8765'))",
    "", "class Handler(http.server.SimpleHTTPRequestHandler):", "    def end_headers(self):",
    "        self.send_header('Cache-Control', 'no-store')", "        super().end_headers()",
    "", "class ReusableTCPServer(socketserver.TCPServer):", "    allow_reuse_address = True",
    "", "def choose_port(preferred):", "    if preferred == 0:", "        return 0",
    "    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:", "        if probe.connect_ex(('127.0.0.1', preferred)) != 0:",
    "            return preferred", "    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:",
    "        probe.bind(('127.0.0.1', 0))", "        return probe.getsockname()[1]",
    "", "def main():", "    handler = functools.partial(Handler, directory=ROOT)",
    "    with ReusableTCPServer(('127.0.0.1', choose_port(PORT)), handler) as httpd:",
    "        port = httpd.server_address[1]", "        url = f'http://127.0.0.1:{port}/index.html'",
    "        print(url, flush=True)", "        if os.environ.get('MOONDESK_APP_TOOL_NO_OPEN') != '1':",
    "            webbrowser.open(url)", "        httpd.serve_forever()", "", "if __name__ == '__main__':",
    "    main()", "",
  ].join("\n")
}

///|
fn app_tool_static_host_run_script() -> String {
  [
    "#!/bin/sh", "cd \"$(dirname \"$0\")\" || exit 1", "exec python3 ./serve.py \"$@\"",
    "",
  ].join("\n")
}
