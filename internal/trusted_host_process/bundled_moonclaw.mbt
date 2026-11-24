///|
fn bundled_moonclaw_version(metadata : String) -> Result[String, String] {
  if !metadata.contains("name = \"vectie/moonclaw\"") {
    return Err("Bundled Code runtime has an unexpected product identity")
  }
  for line in metadata.split("\n") {
    let line = line.trim().to_owned()
    if line.has_prefix("version = ") {
      let value = @json.parse(line["version = ".length():]) catch {
        _ => return Err("Bundled Code runtime version is invalid")
      }
      if value is String(version) && safe_binding_segment(version) {
        return Ok(version)
      }
    }
  }
  Err("Bundled Code runtime has no valid version")
}

///|
/// Provision only the application-owned resource. No URL, executable or
/// arguments are accepted from a workspace or an HTTP request, and no updater
/// or initialization command is executed here.
pub async fn provision_bundled_moonclaw() -> Result[String?, String] {
  let app_dir = @env.get_env_var("LEPUSA_APP_DIR").unwrap_or("")
  if app_dir == "" {
    return Ok(None)
  }
  let runtime_root = match managed_runtime_root() {
    Ok(root) => root
    Err(message) => return Err(message)
  }
  provision_bundled_moonclaw_at(app_dir, runtime_root)
}

///|
async fn provision_bundled_moonclaw_at(
  app_dir : String,
  runtime_root : String,
) -> Result[String?, String] {
  let bundled = join_daemon_path(app_dir, "Resources/moonclaw-runtime")
  if !@fs.exists(bundled) {
    return Ok(None)
  }
  try {
    let bundled = @fs.realpath(bundled)
    let metadata_path = join_daemon_path(bundled, "moon.mod")
    let source = join_daemon_path(bundled, "bin/moonclaw")
    if @fs.kind(metadata_path, follow_symlink=false) != Regular ||
      @fs.kind(source, follow_symlink=false) != Regular ||
      !@fs.can_execute(source) {
      return Err("Bundled Code runtime files are unavailable")
    }
    let version = match
      bundled_moonclaw_version(@fs.read_file(metadata_path).text()) {
      Ok(version) => version
      Err(message) => return Err(message)
    }
    @fs.mkdir(runtime_root, recursive=true, allow_exist=true, permission=0o700)
    let runtime_root = @fs.realpath(runtime_root)
    let relative = "moonclaw/" + version + "/bin"
    let bin_dir = join_daemon_path(runtime_root, relative)
    @fs.mkdir(bin_dir, recursive=true, allow_exist=true, permission=0o700)
    if @fs.realpath(bin_dir) != bin_dir {
      return Err(
        "Managed Code runtime directory must not redirect outside its registry",
      )
    }
    let target = join_daemon_path(bin_dir, "moonclaw")
    let data = @fs.read_file(source).binary()
    if @fs.exists(target) {
      if @fs.kind(target, follow_symlink=false) != Regular ||
        @fs.read_file(target).binary() != data {
        return Err(
          "A different Code runtime already uses this version; update the app runtime version before replacing it",
        )
      }
    } else {
      // Publish only a complete copy; an interrupted install cannot select it.
      let staging = @fsx.mkdtemp(join_daemon_path(bin_dir, ".install-XXXXXX"))
      defer remove_bundled_staging(staging)
      let staged = join_daemon_path(staging, "moonclaw")
      @fs.write_file(staged, data, create_mode=CreateNew, permission=0o755)
      @fs.rename(staged, target, replace=false)
    }
    @fs.chmod(target, 0o755)
    Ok(Some(version))
  } catch {
    _ =>
      Err(
        "Could not provision the bundled Code runtime; check app resources and runtime-directory permissions",
      )
  }
}

///|
async fn remove_bundled_staging(path : String) -> Unit {
  @fsx.remove(path) catch {
    _ => ()
  }
}
