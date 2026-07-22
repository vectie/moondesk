///|
fn moonclaw_release_manifest_url() -> String {
  @sys.get_env_var("MOONCLAW_RELEASE_MANIFEST_URL").unwrap_or(
    "http://gl.vectie.xyz/vectie/moonclaw/-/releases/v0.1.3/downloads/release-manifest-gitlab.json",
  )
}

///|
fn moonclaw_runtime_root() -> String {
  match @sys.get_env_var("MOONDESK_RUNTIME_ROOT") {
    Some(path) if path.trim().length() > 0 => @pathx.normalize(path)
    _ => {
      let home = @sys.get_env_var("HOME").unwrap_or("")
      if home == "" {
        ""
      } else {
        @pathx.join(
          home, "Library/Application Support/app.vectie.moondesk/runtimes",
        )
      }
    }
  }
}

///|
async fn moonclaw_install_platform() -> (String, String) {
  let forced_platform = @sys.get_env_var("MOONCLAW_INSTALL_PLATFORM").unwrap_or(
    "",
  )
  let forced_architecture = @sys.get_env_var("MOONCLAW_INSTALL_ARCHITECTURE").unwrap_or(
    "",
  )
  if forced_platform != "" && forced_architecture != "" {
    return (forced_platform, forced_architecture)
  }
  let (_, system, _) = run_process_capture("uname", ["-s"])
  let (_, machine, _) = run_process_capture("uname", ["-m"])
  let platform = match system.trim().to_owned() {
    "Darwin" => "macos"
    "Linux" => "linux"
    _ => "unsupported"
  }
  let architecture = match machine.trim().to_owned() {
    "arm64" | "aarch64" => "arm64"
    "x86_64" | "amd64" => "x86_64"
    _ => "unsupported"
  }
  (platform, architecture)
}

///|
fn moonclaw_release_asset(
  manifest : Json,
  platform : String,
  architecture : String,
) -> Json? {
  for asset in json_array_items(manifest, "assets") {
    if json_string(asset, "platform", default="") == platform &&
      json_string(asset, "architecture", default="") == architecture {
      return Some(asset)
    }
  }
  None
}

///|
fn moonclaw_release_segment_valid(value : String) -> Bool {
  if value == "" || value.length() > 160 {
    return false
  }
  for char in value {
    if !char.is_ascii_alphabetic() &&
      !char.is_ascii_digit() &&
      char != '.' &&
      char != '-' &&
      char != '_' {
      return false
    }
  }
  true
}

///|
fn moonclaw_release_checksum_valid(value : String) -> Bool {
  if value.length() != 64 {
    return false
  }
  for char in value {
    if !(char >= '0' && char <= '9') && !(char >= 'a' && char <= 'f') {
      return false
    }
  }
  true
}

///|
fn moonclaw_release_url_allowed(url : String, manifest_url : String) -> Bool {
  url.has_prefix("https://") ||
  (
    manifest_url.has_prefix("http://gl.vectie.xyz/") &&
    url.has_prefix("http://gl.vectie.xyz/")
  ) ||
  (
    @sys.get_env_var("MOONCLAW_ALLOW_LOCAL_RELEASE").unwrap_or("") == "1" &&
    manifest_url.has_prefix("file://") &&
    url.has_prefix("file://")
  )
}

///|
async fn moonclaw_file_sha256(path : String) -> String {
  let (code, stdout, _) = run_process_capture("shasum", ["-a", "256", path])
  if code != 0 {
    return ""
  }
  let text = stdout.trim().to_owned()
  match text.find(" ") {
    Some(index) => text[:index].to_owned()
    None => text
  }
}

///|
async fn moonclaw_install_temp_dir() -> String {
  let (code, stdout, _) = run_process_capture("mktemp", [
    "-d", "-t", "moondesk-moonclaw.XXXXXX",
  ])
  if code == 0 {
    stdout.trim().to_owned()
  } else {
    ""
  }
}

///|
async fn moonclaw_remove_install_temp(path : String) -> Unit {
  if path != "" && path.contains("moondesk-moonclaw.") {
    ignore(run_process_quiet("rm", ["-rf", path]))
  }
}

///|
async fn moonclaw_install_failure(
  workspace_root : String,
  status : String,
  message : String,
) -> Json {
  let current = moonclaw_daemon_status(workspace_root)
  api_contract_response(
    {
      "running": false,
      "port": json_int(current, "port", default=0),
      "pid": json_int(current, "pid", default=0),
      "service_configured": json_bool(
        current,
        "service_configured",
        default=false,
      ),
      "service_config_path": json_string(
        current,
        "service_config_path",
        default="",
      ),
    },
    ok=false,
    status~,
    message~,
    next_action="install_moonclaw",
  )
}

///|
async fn install_moonclaw_release(workspace_root : String) -> Json {
  let root = workspace_context(workspace_root).suite_root
  let runtime_root = moonclaw_runtime_root()
  if runtime_root == "" {
    return moonclaw_install_failure(
      root, "runtime_root_missing", "MoonDesk could not resolve its application-support directory",
    )
  }
  let manifest_url = moonclaw_release_manifest_url()
  if !moonclaw_release_url_allowed(manifest_url, manifest_url) {
    return moonclaw_install_failure(
      root, "release_url_rejected", "MoonClaw release metadata must use HTTPS or the trusted GitLab mirror",
    )
  }
  let temp_dir = moonclaw_install_temp_dir()
  if temp_dir == "" {
    return moonclaw_install_failure(
      root, "temporary_directory_failed", "MoonDesk could not create a temporary installation directory",
    )
  }
  let result = install_moonclaw_release_from_temp(
    root, runtime_root, manifest_url, temp_dir,
  )
  moonclaw_remove_install_temp(temp_dir)
  result
}

///|
async fn install_moonclaw_release_from_temp(
  root : String,
  runtime_root : String,
  manifest_url : String,
  temp_dir : String,
) -> Json {
  let manifest_path = @pathx.join(temp_dir, "release-manifest.json")
  let (manifest_code, _, manifest_error) = run_process_capture("curl", [
    "-fL", "--retry", "2", "--connect-timeout", "10", "--max-time", "180", "-o",
    manifest_path, manifest_url,
  ])
  if manifest_code != 0 {
    return moonclaw_install_failure(
      root,
      "manifest_download_failed",
      "Could not download MoonClaw release metadata: " +
      trim_for_record(manifest_error),
    )
  }
  let manifest_text = @fs.read_file(manifest_path).text() catch {
    _ =>
      return moonclaw_install_failure(
        root, "manifest_read_failed", "Could not read MoonClaw release metadata",
      )
  }
  let manifest = @json.parse(manifest_text) catch {
    _ =>
      return moonclaw_install_failure(
        root, "manifest_invalid", "MoonClaw release metadata is not valid JSON",
      )
  }
  if json_string(manifest, "schema", default="") !=
    "moonclaw-release-manifest.v1" {
    return moonclaw_install_failure(
      root, "manifest_unsupported", "MoonClaw release metadata uses an unsupported schema",
    )
  }
  let version = json_string(manifest, "version", default="")
  if !moonclaw_release_segment_valid(version) {
    return moonclaw_install_failure(
      root, "version_invalid", "MoonClaw release metadata contains an invalid version",
    )
  }
  let (platform, architecture) = moonclaw_install_platform()
  guard moonclaw_release_asset(manifest, platform, architecture) is Some(asset) else {
    return moonclaw_install_failure(
      root,
      "platform_unsupported",
      "No MoonClaw release is available for " + platform + " " + architecture,
    )
  }
  let asset_name = json_string(asset, "name", default="")
  let asset_url = json_string(asset, "url", default="")
  let expected_sha256 = json_string(asset, "sha256", default="")
  let binary_name = json_string(asset, "binary", default="")
  if !moonclaw_release_segment_valid(asset_name) ||
    binary_name != "moonclaw" ||
    !moonclaw_release_checksum_valid(expected_sha256) ||
    !moonclaw_release_url_allowed(asset_url, manifest_url) {
    return moonclaw_install_failure(
      root, "asset_invalid", "MoonClaw release metadata contains an unsafe asset declaration",
    )
  }
  let archive_path = @pathx.join(temp_dir, asset_name)
  let (download_code, _, download_error) = run_process_capture("curl", [
    "-fL", "--retry", "2", "--connect-timeout", "10", "--max-time", "300", "-o",
    archive_path, asset_url,
  ])
  if download_code != 0 {
    return moonclaw_install_failure(
      root,
      "asset_download_failed",
      "Could not download MoonClaw: " + trim_for_record(download_error),
    )
  }
  let actual_sha256 = moonclaw_file_sha256(archive_path)
  if actual_sha256 != expected_sha256 {
    return moonclaw_install_failure(
      root, "checksum_mismatch", "MoonClaw download verification failed; nothing was installed",
    )
  }
  let (list_code, list_stdout, _) = run_process_capture("tar", [
    "-tzf", archive_path,
  ])
  let archive_entries = list_stdout
    .split("\n")
    .map(line => line.to_owned().trim().to_owned())
    .filter(line => line != "")
    .to_array()
  if list_code != 0 ||
    archive_entries.length() != 1 ||
    archive_entries[0] != "moonclaw" {
    return moonclaw_install_failure(
      root, "archive_invalid", "MoonClaw archive has an unexpected layout; nothing was installed",
    )
  }
  let extract_dir = @pathx.join(temp_dir, "extract")
  @fsx.make_directory(extract_dir, recursive=true, exists_ok=true) catch {
    _ =>
      return moonclaw_install_failure(
        root, "extract_directory_failed", "MoonDesk could not prepare the MoonClaw archive",
      )
  }
  let (extract_code, _, extract_error) = run_process_capture("tar", [
    "-xzf", archive_path, "-C", extract_dir,
  ])
  if extract_code != 0 {
    return moonclaw_install_failure(
      root,
      "extract_failed",
      "Could not extract MoonClaw: " + trim_for_record(extract_error),
    )
  }
  let extracted_binary = @pathx.join(extract_dir, "moonclaw")
  let binary_bytes = @fs.read_file(extracted_binary) catch {
    _ =>
      return moonclaw_install_failure(
        root, "binary_missing", "The verified MoonClaw archive did not contain its executable",
      )
  }
  let install_dir = @pathx.join(runtime_root, "moonclaw/" + version)
  let bin_dir = @pathx.join(install_dir, "bin")
  @fsx.make_directory(bin_dir, recursive=true, exists_ok=true) catch {
    _ =>
      return moonclaw_install_failure(
        root, "install_directory_failed", "MoonDesk could not create the MoonClaw runtime directory",
      )
  }
  let installed_binary = @pathx.join(bin_dir, "moonclaw")
  @fs.write_file(
    installed_binary,
    binary_bytes,
    create_mode=CreateOrTruncate,
    permission=0o755,
  ) catch {
    _ =>
      return moonclaw_install_failure(
        root, "install_write_failed", "MoonDesk could not install the MoonClaw executable",
      )
  }
  let product_dir = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "",
  )
  @fsx.make_directory(product_dir, recursive=true, exists_ok=true) catch {
    _ =>
      return moonclaw_install_failure(
        root, "service_directory_failed", "MoonDesk could not create the MoonClaw product directory",
      )
  }
  let service_config : Json = {
    "kind": "moondesk-moonclaw-service.v1",
    "version": version,
    "cwd": install_dir,
    "daemon": {
      "command": installed_binary,
      "args": ["daemon", "--port", "0", "--serve", root],
    },
  }
  @fsx.write_to_file(
    moonclaw_service_config_path(root),
    service_config.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ =>
      return moonclaw_install_failure(
        root, "service_config_failed", "MoonDesk installed MoonClaw but could not configure its service",
      )
  }
  let started = ensure_moonclaw_daemon_running(root, action="install")
  if json_bool(started, "running", default=false) {
    let fields = match started {
      Object(fields) => fields.copy()
      _ => {}
    }
    fields["installed_version"] = version.to_json()
    fields["installed_binary"] = installed_binary.to_json()
    fields["status"] = "installed_and_running".to_json()
    fields["message"] = ("MoonClaw " + version + " is installed and running").to_json()
    Json::object(fields)
  } else {
    started
  }
}
