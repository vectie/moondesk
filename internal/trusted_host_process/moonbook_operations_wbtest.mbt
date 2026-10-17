///|
test "MoonBook host executable resolution does not search workspace or PATH" {
  assert_eq(
    moonbook_executable_candidates(Some("/opt/moonbook/bin/moonbook")).unwrap(),
    ["/opt/moonbook/bin/moonbook"],
  )
  assert_eq(moonbook_executable_candidates(None).unwrap(), [
    "/usr/local/bin/moonbook", "/opt/homebrew/bin/moonbook", "/usr/bin/moonbook",
  ])
  for
    value in [
      "", "moonbook", "./moonbook", "../moonbook", "/repo/../moonbook", "/repo//moonbook",
      "/repo/./moonbook", "/repo/moonbook/", "/repo/moonbook\n", "/repo/moonbook\u0000",
      "/repo/moonbook\t",
    ] {
    assert_true(moonbook_executable_candidates(Some(value)) is Err(_))
  }
}

///|
test "MoonBook capability requires exact compatible selection and source help" {
  let help =
    #|moonbook agent pack [root] [version] [output] [outputs.json]
    #|moonbook agent source <bundle>
    #|moonbook agent inspect <bundle>
    #|moonbook agent verify <bundle>
  assert_true(moonbook_compatible_help(2, help))
  assert_false(moonbook_compatible_help(0, help))
  assert_false(moonbook_compatible_help(1, help))
  assert_false(moonbook_compatible_help(2, ""))
  let without_selection =
    #|moonbook agent pack [root] [version] [output]
    #|moonbook agent source <bundle>
    #|moonbook agent inspect <bundle>
    #|moonbook agent verify <bundle>
  assert_false(moonbook_compatible_help(2, without_selection))
  let without_source =
    #|moonbook agent pack [root] [version] [output] [outputs.json]
    #|moonbook agent inspect <bundle>
    #|moonbook agent verify <bundle>
  assert_false(moonbook_compatible_help(2, without_source))
  let invalid_prefix =
    #|prefix moonbook agent pack [root] [version] [output] [outputs.json]
    #|moonbook agent source <bundle>
    #|moonbook agent inspect <bundle>
    #|moonbook agent verify <bundle>
  assert_false(moonbook_compatible_help(2, invalid_prefix))
}

///|
test "MoonBook closed operations keep values as separate arguments" {
  let root = "/books/inert;$(not-a-command)"
  let package_path = root + "/book/agents/desk-0123/package.moonbook-agent"
  let selection = root + "/book/agents/desk-0123/selection.json"
  assert_eq(
    moonbook_operation_arguments(
      root,
      Pack(version="release-1.2_3", output=package_path, selection~),
    ).unwrap(),
    ["agent", "pack", root, "release-1.2_3", package_path, selection],
  )
  assert_eq(
    moonbook_operation_arguments(root, Inspect(package_path~)).unwrap(),
    ["agent", "inspect", package_path],
  )
  assert_eq(
    moonbook_operation_arguments(root, Verify(package_path~)).unwrap(),
    ["agent", "verify", package_path],
  )
  assert_eq(
    moonbook_operation_arguments(root, Source(package_path~)).unwrap(),
    ["agent", "source", package_path],
  )
}

///|
test "MoonBook arguments reject traversal root siblings and ambiguous output" {
  let root = "/books/approved"
  let selection = root + "/book/agents/selection.json"
  for
    package_path in [
      "/books/approved-other/package", "/books/approved", "/books/approved/../escape",
      "/books/approved//package", "/books/approved/./package", "/tmp/package", "package",
      "--help", "/books/approved/package\r--flag", "/books/approved/package\u0000",
    ] {
    assert_true(
      moonbook_operation_arguments(root, Inspect(package_path~)) is Err(_),
    )
    assert_true(
      moonbook_operation_arguments(root, Verify(package_path~)) is Err(_),
    )
    assert_true(
      moonbook_operation_arguments(root, Source(package_path~)) is Err(_),
    )
    assert_true(
      moonbook_operation_arguments(
        root,
        Pack(version="1.0", output=package_path, selection~),
      )
      is Err(_),
    )
  }
  assert_true(
    moonbook_operation_arguments(
      root,
      Pack(version="1.0", output=selection, selection~),
    )
    is Err(_),
  )
  assert_true(
    moonbook_operation_arguments(
      root,
      Pack(version="1.0", output=root + "/bundle", selection="/tmp/selection"),
    )
    is Err(_),
  )
  assert_true(
    moonbook_operation_arguments("/", Inspect(package_path="/package"))
    is Err(_),
  )
  for version in ["", "--help", "1 2", "1\n2", "1/2", "1;echo", "1".repeat(129)] {
    assert_false(moonbook_safe_version(version))
  }
}

///|
test "MoonBook child environment excludes ambient credentials and config" {
  let environment = moonbook_export_environment()
  assert_eq(environment.length(), 8)
  assert_eq(environment.get("HOME"), Some("/dev/null"))
  assert_eq(environment.get("XDG_CONFIG_HOME"), Some("/dev/null"))
  assert_eq(environment.get("PATH"), Some("/dev/null"))
  assert_eq(environment.get("MOONDESK_MOONBOOK_BIN"), None)
  assert_eq(environment.get("OPENAI_API_KEY"), None)
  assert_eq(environment.get("MOONGATE_CONTROL_TOKEN"), None)
  assert_eq(environment.get("MOONDESK_EXECUTION_SANDBOX_CONFIG"), None)
}

///|
test "MoonBook local import requires reviewed source capability and typed confined arguments" {
  let help =
    #|moonbook agent pack [root] [version] [output] [outputs.json]
    #|moonbook agent source <bundle>
    #|moonbook agent inspect <bundle>
    #|moonbook agent verify <bundle>
  assert_false(moonbook_compatible_import_help(2, help))
  assert_false(
    moonbook_compatible_import_help(
      2,
      help +
      "\nmoonbook agent import <bundle> <new-book>\nmoonbook agent verify-import <bundle> <book>",
    ),
  )
  assert_true(
    moonbook_compatible_import_help(
      2,
      help +
      "\nmoonbook agent import <bundle> <new-book> [source.json]\nmoonbook agent verify-import <bundle> <book>",
    ),
  )
  let root = "/suite"
  let destination = root + "/books/new-book"
  let package_path = root + "/.moonsuite/import/received/package.moonbook-agent"
  let source_path = root + "/.moonsuite/import/received/source.json"
  assert_eq(
    moonbook_operation_arguments(
      root,
      Import(destination~, package_path~, source_path~),
    ).unwrap(),
    ["agent", "import", package_path, destination, source_path],
  )
  assert_eq(
    moonbook_operation_arguments(
      root,
      VerifyImport(destination~, package_path~),
    ).unwrap(),
    ["agent", "verify-import", package_path, destination],
  )
  for
    destination in [
      "/elsewhere/new", "/suite/books/../new", "/suite/books/new/child", "/suite/books",
      "/suite/books//new",
    ] {
    assert_true(
      moonbook_operation_arguments(
        root,
        Import(destination~, package_path~, source_path~),
      )
      is Err(_),
    )
    assert_true(
      moonbook_operation_arguments(
        root,
        VerifyImport(destination~, package_path~),
      )
      is Err(_),
    )
  }
  assert_true(
    moonbook_operation_arguments(
      root,
      Import(destination~, package_path=destination + "/package", source_path~),
    )
    is Err(_),
  )
  assert_true(
    moonbook_operation_arguments(
      root,
      Import(
        destination~,
        package_path~,
        source_path="/suite/other/source.json",
      ),
    )
    is Err(_),
  )
}

///|
test "MoonBook exact import uses only the explicit exact command and original sibling binding" {
  let help =
    #|moonbook agent pack [root] [version] [output] [outputs.json]
    #|moonbook agent source <bundle>
    #|moonbook agent inspect <bundle>
    #|moonbook agent verify <bundle>
    #|moonbook agent import <bundle> <new-book> [source.json]
    #|moonbook agent verify-import <bundle> <book>
  assert_true(moonbook_compatible_import_help(2, help))
  assert_false(moonbook_compatible_exact_import_help(2, help))
  assert_true(
    moonbook_compatible_exact_import_help(
      2,
      help +
      "\nmoonbook agent import-exact <bundle> <new-book> <town-binding.json>",
    ),
  )
  let root = "/suite"
  let destination = root + "/books/new"
  let package_path = root + "/staged/package.moonbook-agent"
  let source_path = root + "/staged/town-binding.json"
  assert_eq(
    moonbook_operation_arguments(
      root,
      ImportExact(destination~, package_path~, source_path~),
    ).unwrap(),
    ["agent", "import-exact", package_path, destination, source_path],
  )
  assert_true(
    moonbook_operation_arguments(
      root,
      ImportExact(
        destination="/suite/books/../other",
        package_path~,
        source_path~,
      ),
    )
    is Err(_),
  )
  assert_true(
    moonbook_operation_arguments(
      root,
      ImportExact(
        destination~,
        package_path~,
        source_path="/suite/other/town-binding.json",
      ),
    )
    is Err(_),
  )
}

///|
async test "MoonBook import path checks reject aliases existing roots and dangling targets" {
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-import-host-"))
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/books")
  @fs.mkdir(root + "/staged")
  let package_path = root + "/staged/package.moonbook-agent"
  let source_path = root + "/staged/source.json"
  let destination = root + "/books/new-book"
  @fs.write_file(package_path, "{}", create_mode=CreateNew)
  @fs.write_file(source_path, "{}", create_mode=CreateNew)
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Import(destination~, package_path~, source_path~),
    )
    is Ok(_),
  )
  @fs.symlink(destination, target=root + "/missing")
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Import(destination~, package_path~, source_path~),
    )
    is Err(_),
  )
  @fs.mkdir(root + "/books/existing")
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Import(destination=root + "/books/existing", package_path~, source_path~),
    )
    is Err(_),
  )
  @fs.symlink(root + "/staged/alias.json", target=source_path)
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Import(
        destination=root + "/books/other",
        package_path~,
        source_path=root + "/staged/alias.json",
      ),
    )
    is Err(_),
  )
}

///|
async test "MoonBook live library launch fence prevents child creation" {
  let captured = moonbook_capture(
    "/nonexistent-moonbook-must-not-launch",
    ["agent", "import"],
    "/",
    1000,
    1024,
    may_run=() => false,
  )
  match captured {
    Err(message) =>
      assert_eq(message, "MoonBook operation context changed before launch")
    Ok(_) => fail("A superseded library must not launch a child")
  }
}

///|
async test "MoonBook denied launch fences do not retain file descriptors" {
  guard moonbook_test_fd_count() is Some(before) else { return }
  for _ in 0..<64 {
    let result = moonbook_capture(
      "/nonexistent-moonbook-must-not-launch",
      [],
      "/",
      1000,
      1024,
      may_run=() => false,
    )
    assert_true(result is Err(_))
  }
  for _ in 0..<16 {
    let failed = moonbook_capture(
      "/nonexistent-moonbook-must-not-launch",
      [],
      "/",
      1000,
      1024,
    )
    assert_true(failed is Err(_))
  }
  let after = moonbook_test_fd_count().unwrap()
  // Allow incidental test-runner descriptors, not per-denial retained handles.
  assert_true(after <= before + 4)
}

///|
async test "MoonBook capture closes stdin and preserves literal argv and separate output" {
  let empty = moonbook_capture("/bin/cat", [], "/", 2000, 1024).unwrap()
  assert_eq(empty.status, 0)
  assert_eq(empty.stdout, b"")
  assert_eq(empty.stderr, b"")
  let literal = "space ; $(never-executed) \"quoted\" 中"
  let printed = moonbook_capture(
    "/usr/bin/printf",
    ["%s", literal],
    "/",
    2000,
    1024,
  ).unwrap()
  assert_eq(printed.status, 0)
  assert_eq(@utf8.decode(printed.stdout), literal)
  assert_eq(printed.stderr, b"")
  let failed = moonbook_capture(
    "/bin/ls",
    ["/nonexistent-moonbook-capture-fixture"],
    "/",
    2000,
    1024,
  ).unwrap()
  assert_true(failed.status != 0)
  assert_eq(failed.stdout, b"")
  assert_true(failed.stderr.length() > 0)
}

///|
async test "MoonBook capture enforces exact byte bounds and cancels overflowing child" {
  let exact = moonbook_capture(
    "/usr/bin/printf",
    ["%s", "1234567890abcdef"],
    "/",
    2000,
    16,
  ).unwrap()
  assert_eq(exact.stdout, b"1234567890abcdef")
  assert_true(
    moonbook_capture("/usr/bin/yes", [], "/", 2000, 16)
    is Err("MoonBook output exceeds the export limit"),
  )
}

///|
async test "MoonBook capture times out sleeping child and releases descriptors" {
  let before = moonbook_test_fd_count()
  for _ in 0..<3 {
    assert_true(
      moonbook_capture("/bin/sleep", ["10"], "/", 30, 1024)
      is Err("MoonBook export operation timed out"),
    )
  }
  if before is Some(before) {
    assert_true(moonbook_test_fd_count().unwrap() <= before + 4)
  }
}

///|
async fn moonbook_test_fd_count() -> Int32? {
  if @fs.exists("/proc/self/fd") {
    return Some(@fs.readdir("/proc/self/fd").length())
  }
  guard @fs.exists("/dev/fd") else { return None }
  // Darwin's synthetic /dev/fd entries cannot be reliably enumerated with
  // asynchronous directory metadata queries. Probe the low descriptor range
  // directly; failed launches in this regression allocate well below 1024.
  let mut count = 0
  for fd in 0..<1024 {
    let open = @fs.exists("/dev/fd/" + fd.to_string()) catch {
      // EBADF is 9 on the Darwin/POSIX descriptor probe used here.
      @os_error.OSError(9, ..) => false
      error => raise error
    }
    if open {
      count += 1
    }
  }
  Some(count)
}

///|
test "MoonBook export limits are finite and separated by purpose" {
  assert_eq(moonbook_metadata_limit_bytes, 8 * 1024 * 1024)
  assert_eq(moonbook_error_limit_bytes, 64 * 1024)
  assert_true(
    moonbook_pack_timeout_ms > 0 && moonbook_pack_timeout_ms <= 120_000,
  )
  assert_true(
    moonbook_read_timeout_ms > 0 && moonbook_read_timeout_ms <= 30_000,
  )
  assert_true(
    moonbook_probe_timeout_ms > 0 && moonbook_probe_timeout_ms <= 30_000,
  )
}

///|
async test "MoonBook bounded reader accepts exactly its limit and rejects overflow" {
  let exact = @io.MemoryReader(writer => writer.write("1234567890abcdef"))
  defer exact.close()
  assert_eq(moonbook_read_bounded(exact, 16).unwrap(), b"1234567890abcdef")
  let overflow = @io.MemoryReader(writer => writer.write("1234567890abcdef!"))
  defer overflow.close()
  assert_eq(
    moonbook_read_bounded(overflow, 16),
    Err("MoonBook output exceeds the export limit"),
  )
  let empty = @io.MemoryReader(_ => ())
  defer empty.close()
  assert_eq(moonbook_read_bounded(empty, 0).unwrap(), b"")
}

///|
async test "MoonBook bounded reader preserves byte counts across UTF-8 chunks" {
  let split = @io.MemoryReader(writer => {
    writer.write(b"\xe4")
    writer.write(b"\xb8\xad")
  })
  defer split.close()
  let bytes = moonbook_read_bounded(split, 3).unwrap()
  assert_eq(bytes.length(), 3)
  assert_eq(@utf8.decode(bytes), "中")
  let overflow = @io.MemoryReader(writer => writer.write("中"))
  defer overflow.close()
  assert_true(moonbook_read_bounded(overflow, 2) is Err(_))
}

///|
async test "MoonBook canonical paths reject symlink files parents and existing output" {
  let directory = @fs.tmpdir(prefix="moondesk-moonbook-boundary-")
  defer @fs.rmdir(directory, recursive=true)
  let root = @fs.realpath(directory)
  @fs.mkdir(root + "/book")
  @fs.mkdir(root + "/book/agents")
  let selection = root + "/book/agents/selection.json"
  let output = root + "/book/agents/package.moonbook-agent"
  @fs.write_file(selection, "[]", create_mode=CreateNew)
  let operation : MoonBookExportOperation = Pack(
    version="1.0",
    output~,
    selection~,
  )
  assert_true(moonbook_validate_operation_paths(root, operation) is Ok(_))
  @fs.write_file(output, "existing", create_mode=CreateNew)
  assert_true(moonbook_validate_operation_paths(root, operation) is Err(_))
  assert_true(
    moonbook_validate_operation_paths(root, Inspect(package_path=output))
    is Ok(_),
  )
  @fs.symlink(root + "/book/selection-link.json", target=selection)
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Pack(
        version="1.0",
        output=root + "/book/new-package",
        selection=root + "/book/selection-link.json",
      ),
    )
    is Err(_),
  )
  @fs.symlink(root + "/book/agents-link", target=root + "/book/agents")
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Pack(
        version="1.0",
        output=root + "/book/agents-link/new-package",
        selection~,
      ),
    )
    is Err(_),
  )
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Pack(version="1.0", output=root + "/missing/new-package", selection~),
    )
    is Err(_),
  )
  @fs.symlink(root + "/book/package-link", target=output)
  assert_true(
    moonbook_validate_operation_paths(
      root,
      Source(package_path=root + "/book/package-link"),
    )
    is Err(_),
  )
}
