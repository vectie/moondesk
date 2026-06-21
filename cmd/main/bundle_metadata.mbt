///|
fn bundle_app_root(options : BundleOptions) -> String {
  @pathx.join(options.out_dir, "moondesk-lepusa.app")
}

///|
fn bundle_archive_path(options : BundleOptions) -> String {
  @pathx.join(options.out_dir, "moondesk-lepusa.app.zip")
}

///|
fn bundle_runtime_manifest_path(options : BundleOptions) -> String {
  @pathx.join(
    bundle_app_root(options),
    "Contents/Resources/lepusa/runtime.json",
  )
}

///|
fn bundle_shell_policy() -> String {
  "lepusa"
}

///|
fn bundle_native_host_name() -> String {
  "lepusa"
}

///|
fn bundle_has_native_window() -> Bool {
  true
}

///|
fn bundle_path_leaf(path : String) -> String {
  let normalized = @pathx.normalize(path)
  let mut start = 0
  for index = 0; index < normalized.length(); index = index + 1 {
    if normalized[index:index + 1] == "/" {
      start = index + 1
    }
  }
  normalized[start:].to_owned()
}
