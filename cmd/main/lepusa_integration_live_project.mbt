///|
fn lepusa_integration_resolve_live_paths(
  options : LepusaIntegrationOptions,
  repo_root : String,
) -> LepusaIntegrationOptions {
  let workspace_root = if options.workspace_root == "" {
    resolve_user_workspace_root(default_workspace_root(), repo_root)
  } else {
    resolve_user_workspace_root(options.workspace_root, repo_root)
  }
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
  let out_dir = absolute_path(options.out_dir, repo_root)
  let sidecar = lepusa_integration_sidecar_path(options.target, out_dir)
  {
    "identifier": "app.vectie.moondesk.lepusa.live",
    "productName": "Moondesk Lepusa",
    "version": "0.1.0",
    "runtime": {
      "backend": "system-webview",
      "assetProtocol": "lepusa",
      "devtools": false,
    },
    "window": {
      "label": "main",
      "title": "Moondesk",
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
            sidecar,
            "serve",
            options.workspace_root,
            "--ui",
            options.ui_dir,
            "--host",
            host,
            "--port",
            options.serve_port.to_string(),
          ],
        },
      },
    },
    "plugins": [{ "name": "localhost" }, { "name": "serviceDiscovery" }],
    "capabilities": [
      {
        "name": "main",
        "windows": ["main"],
        "permissions": ["localhost", "service-discovery"],
      },
    ],
  }
}

///|
fn lepusa_integration_live_project_path(out_dir : String) -> String {
  @pathx.join(out_dir, "live-project/lepusa.json")
}
