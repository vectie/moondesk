///|
priv struct LepusaIntegrationOptions {
  command : String
  target : String
  lepusa_root : String
  project : String
  out_dir : String
  manifest_path : String
  asset_url : String
  workspace_root : String
  ui_dir : String
  serve_port : Int
  strict : Bool
}

///|
priv struct LepusaIntegrationProcessStep {
  name : String
  args : Array[String]
}

///|
priv struct LepusaIntegrationBundlePaths {
  app_root : String
  launcher : String
  runtime_executable : String
  manifest : String
  entrypoint : String
  platform_metadata : String
}

///|
fn default_lepusa_integration_options() -> LepusaIntegrationOptions {
  {
    command: "verify",
    target: "macos",
    lepusa_root: ".mooncakes/vectie/lepusa",
    project: "desktop/lepusa/moondesk/lepusa.json",
    out_dir: "_build/lepusa/moondesk",
    manifest_path: "",
    asset_url: "lepusa://packaged/main/index.html",
    workspace_root: "",
    ui_dir: "",
    serve_port: 4398,
    strict: false,
  }
}
