///|
/// A compatible native MoonBook executable selected exclusively by the host.
/// Its path and identity cannot be supplied by browser or workspace requests.
pub struct MoonBookExportRuntime {
  priv executable : String
  priv stamp : MoonBookExecutableStamp
  priv supports_import : Bool
  priv supports_exact_import : Bool
}

///|
/// The complete command vocabulary available to Desk-local package export.
/// Every path is absolute, canonical, and confined beneath the supplied root.
pub(all) enum MoonBookExportOperation {
  Pack(version~ : String, output~ : String, selection~ : String)
  Inspect(package_path~ : String)
  Verify(package_path~ : String)
  Source(package_path~ : String)
  Import(destination~ : String, package_path~ : String, source_path~ : String)
  ImportExact(
    destination~ : String,
    package_path~ : String,
    source_path~ : String
  )
  VerifyImport(destination~ : String, package_path~ : String)
}

///|
priv struct MoonBookExecutableStamp {
  size : Int64
  modified : (Int64, Int32)
  changed : (Int64, Int32)
} derive(Eq)

///|
priv struct MoonBookCapturedOutput {
  status : Int32
  stdout : Bytes
  stderr : Bytes
}

///|
let moonbook_metadata_limit_bytes : Int32 = 8 * 1024 * 1024

///|
let moonbook_error_limit_bytes : Int32 = 64 * 1024

///|
let moonbook_pack_timeout_ms = 120_000

///|
let moonbook_read_timeout_ms = 30_000

///|
let moonbook_probe_timeout_ms = 8_000

///|
fn moonbook_safe_path(path : String) -> Bool {
  safe_canonical_path_shape(path) &&
  !path.has_suffix("/") &&
  safe_bounded_value(path, 4096)
}

///|
fn moonbook_path_within(root : String, path : String) -> Bool {
  moonbook_safe_path(root) &&
  moonbook_safe_path(path) &&
  path.has_prefix(root + "/")
}

///|
fn moonbook_safe_version(version : String) -> Bool {
  version.length() > 0 &&
  version.length() <= 128 &&
  !version.has_prefix("-") &&
  version.all(char => {
    char.is_ascii_alphabetic() ||
    char.is_ascii_digit() ||
    char == '.' ||
    char == '-' ||
    char == '_'
  })
}

///|
fn moonbook_operation_arguments(
  root : String,
  operation : MoonBookExportOperation,
) -> Result[Array[String], String] {
  if !moonbook_safe_path(root) {
    return Err("MoonBook export root is invalid")
  }
  match operation {
    Pack(version~, output~, selection~) => {
      guard moonbook_safe_version(version) &&
        moonbook_path_within(root, output) &&
        moonbook_path_within(root, selection) &&
        output != selection else {
        return Err("MoonBook package export arguments are invalid")
      }
      Ok(["agent", "pack", root, version, output, selection])
    }
    Inspect(package_path~) | Verify(package_path~) | Source(package_path~) => {
      if !moonbook_path_within(root, package_path) {
        return Err("MoonBook package is outside the export root")
      }
      let command = match operation {
        Inspect(..) => "inspect"
        Verify(..) => "verify"
        Source(..) => "source"
        _ => return Err("MoonBook operation is invalid")
      }
      Ok(["agent", command, package_path])
    }
    Import(destination~, package_path~, source_path~)
    | ImportExact(destination~, package_path~, source_path~) => {
      guard moonbook_import_arguments_valid(root, destination, package_path) &&
        moonbook_path_within(root, source_path) &&
        path_parent(source_path) == path_parent(package_path) &&
        source_path != package_path else {
        return Err("MoonBook import arguments are invalid")
      }
      Ok([
        "agent",
        if operation is ImportExact(..) {
          "import-exact"
        } else {
          "import"
        },
        package_path,
        destination,
        source_path,
      ])
    }
    VerifyImport(destination~, package_path~) => {
      guard moonbook_import_arguments_valid(root, destination, package_path) else {
        return Err("MoonBook import verification arguments are invalid")
      }
      Ok(["agent", "verify-import", package_path, destination])
    }
  }
}

///|
fn moonbook_import_arguments_valid(
  root : String,
  destination : String,
  package_path : String,
) -> Bool {
  moonbook_path_within(root, destination) &&
  path_parent(destination) == root + "/books" &&
  moonbook_path_within(root, package_path) &&
  !package_path.has_prefix(root + "/books/")
}

///|
/// No HOME, config, credentials, workspace variables, or inherited PATH.
/// MoonBook's native package commands do not require another executable.
fn moonbook_export_environment() -> Map[String, String] {
  {
    "HOME": "/dev/null",
    "XDG_CONFIG_HOME": "/dev/null",
    "XDG_DATA_HOME": "/dev/null",
    "XDG_CACHE_HOME": "/dev/null",
    "PATH": "/dev/null",
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "TMPDIR": "/tmp",
  }
}

///|
/// The only ambient input is a host-owned environment override. An explicit
/// invalid override fails closed instead of selecting a different executable.
fn moonbook_executable_candidates(
  configured : String?,
) -> Result[Array[String], String] {
  match configured {
    Some(path) =>
      if moonbook_safe_path(path) {
        Ok([path])
      } else {
        Err("MoonBook host executable configuration is invalid")
      }
    None =>
      Ok([
        "/usr/local/bin/moonbook", "/opt/homebrew/bin/moonbook", "/usr/bin/moonbook",
      ])
  }
}

///|
async fn moonbook_executable_stamp(
  path : String,
) -> Result[MoonBookExecutableStamp, String] {
  if !moonbook_safe_path(path) {
    return Err("MoonBook native executable is unavailable")
  }
  match canonical_regular_file("MoonBook native executable", path) {
    Err(_) => return Err("MoonBook native executable is unavailable")
    Ok(_) => ()
  }
  let stamp = try {
    guard @fs.can_execute(path) else {
      return Err("MoonBook native executable is unavailable")
    }
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    guard file.kind() is Regular else {
      return Err("MoonBook native executable is unavailable")
    }
    MoonBookExecutableStamp::{
      size: file.size(),
      modified: file.mtime(),
      changed: file.ctime(),
    }
  } catch {
    _ => return Err("MoonBook native executable is unavailable")
  }
  Ok(stamp)
}

///|
/// Bounds are enforced on each read before storing bytes, with at most one
/// extra byte read to distinguish exact-limit EOF from overflow.
async fn moonbook_read_bounded(
  reader : &@io.Reader,
  limit : Int32,
) -> Result[Bytes, String] {
  let output = @buffer.Buffer(size_hint=limit.min(8192))
  for ;; {
    let chunk = reader.read_some(
      max_len=(limit - output.length() + 1).min(8192),
    ) catch {
      _ => return Err("MoonBook output could not be read")
    }
    guard chunk is Some(chunk) else { break }
    guard output.length() + chunk.length() <= limit else {
      return Err("MoonBook output exceeds the export limit")
    }
    output.write_bytes(chunk)
  }
  Ok(output.to_bytes())
}

///|
/// Private process boundary: separate executable/argv, closed stdin, no shell,
/// two concurrently drained bounded pipes, and immediate kill on cancellation.
async fn moonbook_capture(
  executable : String,
  args : Array[String],
  cwd : String,
  timeout_ms : Int32,
  stdout_limit : Int32,
  may_run~ : () -> Bool = () => true,
) -> Result[MoonBookCapturedOutput, String] {
  @async.with_timeout(timeout_ms, () => {
    @async.with_task_group() <| group => {
      guard may_run() else {
        return Err("MoonBook operation context changed before launch")
      }
      // Shared output channels retain explicit ownership on every exit path,
      // including pipe creation or spawn failure. Both readers stay bounded.
      let (stdout_reader, stdout_writer) = @process.read_from_process(
        shared=true,
      )
      defer stdout_reader.close()
      defer stdout_writer.close()
      let (stderr_reader, stderr_writer) = @process.read_from_process(
        shared=true,
      )
      defer stderr_reader.close()
      defer stderr_writer.close()
      // Allocate stdin last: its only writer is closed before the immediately
      // following spawn, so the child sees EOF without ambient input. The
      // process API consumes/closes the read end even when spawning fails.
      // All setup here is synchronous: no yield between fence and spawn.
      let (stdin, stdin_writer) = @process.write_to_process()
      stdin_writer.close()
      let process = @process.spawn(
        group,
        executable,
        args,
        cwd~,
        stdin~,
        stdout=stdout_writer,
        stderr=stderr_writer,
        extra_env=moonbook_export_environment(),
        inherit_env=false,
        cancel_handler=@process.hard_cancel(),
      )
      stdout_writer.close()
      stderr_writer.close()
      let stdout = group.spawn(() => {
        let result = moonbook_read_bounded(stdout_reader, stdout_limit)
        if result is Err(_) {
          process.cancel()
        }
        result
      })
      let stderr = group.spawn(() => {
        let result = moonbook_read_bounded(
          stderr_reader, moonbook_error_limit_bytes,
        )
        if result is Err(_) {
          process.cancel()
        }
        result
      })
      let status = process.wait()
      let stdout = stdout.wait()
      let stderr = stderr.wait()
      match (stdout, stderr) {
        (Ok(stdout), Ok(stderr)) => Ok({ status, stdout, stderr, })
        (Err(message), _) | (_, Err(message)) => Err(message)
      }
    }
  }) catch {
    @async.TimeoutError => Err("MoonBook export operation timed out")
    _ => Err("MoonBook export operation could not complete")
  }
}

///|
fn moonbook_compatible_help(status : Int32, help : String) -> Bool {
  status == 2 &&
  help
  .split("\n")
  .any(line => {
    line.trim() ==
    "moonbook agent pack [root] [version] [output] [outputs.json]"
  }) &&
  help.split("\n").any(line => line.trim() == "moonbook agent inspect <bundle>") &&
  help.split("\n").any(line => line.trim() == "moonbook agent verify <bundle>") &&
  help.split("\n").any(line => line.trim() == "moonbook agent source <bundle>")
}

///|
fn moonbook_compatible_import_help(status : Int32, help : String) -> Bool {
  moonbook_compatible_help(status, help) &&
  help
  .split("\n")
  .any(line => {
    line.trim() == "moonbook agent import <bundle> <new-book> [source.json]"
  }) &&
  help
  .split("\n")
  .any(line => line.trim() == "moonbook agent verify-import <bundle> <book>")
}

///|
fn moonbook_compatible_exact_import_help(status : Int32, help : String) -> Bool {
  moonbook_compatible_import_help(status, help) &&
  help
  .split("\n")
  .any(line => {
    line.trim() ==
    "moonbook agent import-exact <bundle> <new-book> <town-binding.json>"
  })
}

///|
pub async fn moonbook_import_runtime(
  exact~ : Bool = false,
) -> Result[MoonBookExportRuntime, String] {
  match moonbook_resolve_runtime(true) {
    Ok(runtime) if exact && !runtime.supports_exact_import =>
      Err(
        "The configured MoonBook executable needs agent import-exact support for a Town binding. Ordinary local package import remains available.",
      )
    Ok(runtime) if runtime.supports_import => Ok(runtime)
    _ => Err("A compatible native MoonBook package importer is unavailable")
  }
}

///|
/// Probe compatibility without selecting or reading any Book or workspace.
pub async fn moonbook_export_runtime() -> Result[MoonBookExportRuntime, String] {
  moonbook_resolve_runtime(false)
}

///|
async fn moonbook_resolve_runtime(
  require_import : Bool,
) -> Result[MoonBookExportRuntime, String] {
  let candidates = match
    moonbook_executable_candidates(@env.get_env_var("MOONDESK_MOONBOOK_BIN")) {
    Ok(candidates) => candidates
    Err(message) => return Err(message)
  }
  for executable in candidates {
    let stamp = match moonbook_executable_stamp(executable) {
      Ok(stamp) => stamp
      Err(_) => continue
    }
    let output = match
      moonbook_capture(
        executable,
        ["agent", "--help"],
        "/",
        moonbook_probe_timeout_ms,
        moonbook_error_limit_bytes,
      ) {
      Ok(output) => output
      Err(_) => continue
    }
    let stdout = @utf8.decode(output.stdout) catch { _ => continue }
    let stderr = @utf8.decode(output.stderr) catch { _ => continue }
    if !moonbook_compatible_help(output.status, stdout + "\n" + stderr) {
      continue
    }
    let supports_import = moonbook_compatible_import_help(
      output.status,
      stdout + "\n" + stderr,
    )
    if require_import && !supports_import {
      continue
    }
    guard moonbook_executable_stamp(executable) is Ok(current) &&
      current == stamp else {
      continue
    }
    let supports_exact_import = moonbook_compatible_exact_import_help(
      output.status,
      stdout + "\n" + stderr,
    )
    return Ok({ executable, stamp, supports_import, supports_exact_import, })
  }
  Err("A compatible native MoonBook package exporter is unavailable")
}

///|
async fn moonbook_validate_operation_paths(
  root : String,
  operation : MoonBookExportOperation,
) -> Result[Unit, String] {
  match canonical_directory("MoonBook export root", root) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  match operation {
    Pack(output~, selection~, ..) => {
      match canonical_regular_file("MoonBook output selection", selection) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
      // Require the immediate output parent, not merely an existing ancestor.
      // This excludes unresolved intermediate components and symlink parents.
      match
        canonical_directory("MoonBook package parent", path_parent(output)) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
      match canonical_output_path("MoonBook package output", output) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
    }
    Inspect(package_path~) | Verify(package_path~) | Source(package_path~) =>
      match canonical_regular_file("MoonBook package", package_path) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
    Import(destination~, package_path~, source_path~)
    | ImportExact(destination~, package_path~, source_path~) => {
      for path in [package_path, source_path] {
        match canonical_regular_file("MoonBook import proof", path) {
          Err(message) => return Err(message)
          Ok(_) => ()
        }
      }
      match
        canonical_directory("MoonBook import parent", path_parent(destination)) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
      match canonical_output_path("MoonBook import destination", destination) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
    }
    VerifyImport(destination~, package_path~) => {
      match canonical_regular_file("MoonBook import package", package_path) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
      match canonical_directory("MoonBook import destination", destination) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
/// Run only a package export/read operation against canonical confined paths.
/// Successful pack output is replaced with a path-free acknowledgement; error
/// streams and failing stdout are never forwarded to the caller or host logs.
pub async fn MoonBookExportRuntime::run(
  self : MoonBookExportRuntime,
  root : String,
  operation : MoonBookExportOperation,
  may_run~ : () -> Bool = () => true,
) -> Result[String, String] {
  if (operation is Import(..) || operation is VerifyImport(..)) &&
    !self.supports_import {
    return Err("MoonBook does not support reviewed local package import")
  }
  if operation is ImportExact(..) && !self.supports_exact_import {
    return Err(
      "This MoonBook executable does not support exact Town package import. Update the configured MoonBook executable, then check this operation.",
    )
  }
  let args = match moonbook_operation_arguments(root, operation) {
    Ok(args) => args
    Err(message) => return Err(message)
  }
  match moonbook_validate_operation_paths(root, operation) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  guard moonbook_executable_stamp(self.executable) is Ok(stamp) &&
    stamp == self.stamp else {
    return Err("MoonBook native exporter changed; resolve it again")
  }
  // Repeat filesystem checks after resolving the executable and immediately
  // before launch. The API never accepts prevalidated paths as authority.
  match moonbook_validate_operation_paths(root, operation) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let is_pack = operation is Pack(..)
  let output = match
    moonbook_capture(
      self.executable,
      args,
      root,
      if is_pack || operation is Import(..) || operation is ImportExact(..) {
        moonbook_pack_timeout_ms
      } else {
        moonbook_read_timeout_ms
      },
      if is_pack {
        moonbook_error_limit_bytes
      } else {
        moonbook_metadata_limit_bytes
      },
      may_run~,
    ) {
    Ok(output) => output
    Err(message) => return Err(message)
  }
  if output.status != 0 {
    return Err("MoonBook rejected the package export operation")
  }
  if is_pack {
    match operation {
      Pack(output~, ..) =>
        match canonical_regular_file("MoonBook package output", output) {
          Err(message) => return Err(message)
          Ok(_) => ()
        }
      _ => ()
    }
    return Ok("MoonBook package created")
  }
  let text = @utf8.decode(output.stdout) catch {
    _ => return Err("MoonBook metadata is not valid UTF-8")
  }
  Ok(text)
}
