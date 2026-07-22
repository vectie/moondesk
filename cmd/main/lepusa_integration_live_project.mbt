///|
async fn lepusa_integration_resolve_live_paths(
  options : LepusaIntegrationOptions,
  repo_root : String,
) -> LepusaIntegrationOptions {
  let workspace_root = resolve_user_workspace_root(
    options.workspace_root,
    repo_root,
  )
  let ui_dir = if options.ui_dir == "" {
    @pathx.join(repo_root, "ui/rabbita-desk/dist")
  } else {
    absolute_path(options.ui_dir, repo_root)
  }
  { ..options, workspace_root, ui_dir }
}

///|
async fn write_lepusa_integration_live_project(
  options : LepusaIntegrationOptions,
  repo_root : String,
  path : String,
) -> Bool {
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => {
      println("lepusa failed: could not create live project dir: \{error}")
      return false
    }
  }
  @fsx.write_to_file(
    path,
    lepusa_integration_live_project_json(options, repo_root).stringify(indent=2) +
    "\n",
    create=0o644,
  ) catch {
    error => {
      println("lepusa failed: could not write live project: \{error}")
      return false
    }
  }
  true
}

///|
fn lepusa_integration_live_project_json(
  options : LepusaIntegrationOptions,
  repo_root : String,
) -> Json {
  let host = "127.0.0.1"
  let sidecar = moondesk_sidecar_build_output(repo_root)
  let icon = @pathx.join(repo_root, "assets/moondesk.icns")
  {
    "identifier": "app.vectie.moondesk.lepusa.live",
    "productName": "MoonDesk",
    "version": "0.1.0",
    "icon": icon,
    "signing": { "identity": "-" },
    "bundleResources": [
      { "source": sidecar, "path": "moondesk-sidecar", "executable": true },
      { "source": options.ui_dir, "path": "lepusa/assets/main" },
    ],
    "runtime": {
      "backend": "system-webview",
      "assetProtocol": "lepusa",
      "devtools": false,
    },
    "window": {
      "label": "main",
      "title": "MoonDesk",
      "width": 1280,
      "height": 820,
      "resizable": true,
      "source": {
        "localhost": {
          "host": host,
          "port": options.serve_port,
          "path": "/",
          "readinessPath": @moonwiki.moondesk_health_path(),
          "command": [
            "moondesk-sidecar",
            "serve",
            "--ui",
            "lepusa/assets/main",
            "--host",
            host,
            "--port",
            options.serve_port.to_string(),
          ],
        },
      },
    },
    "plugins": [
      { "name": "localhost" },
      { "name": "serviceDiscovery" },
      { "name": "browserHost" },
    ],
    "capabilities": [
      {
        "name": "main",
        "windows": ["main"],
        "permissions": [
          "localhost", "service-discovery", "custom:browserHost.execute", "custom:browserHost.complete",
          "custom:browserHost.captureScreenshot", "custom:browserHost.status",
        ],
      },
    ],
  }
}

///|
fn lepusa_integration_live_project_path(out_dir : String) -> String {
  @pathx.join(out_dir, "live-project/lepusa.json")
}
