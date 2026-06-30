///|
test "default workspace root uses dedicated moondesk workspace" {
  assert_eq(
    default_workspace_root_from_env("", "/home/example", ""),
    "/home/example/moondesk-workspace",
  )
  assert_eq(
    default_workspace_root_from_env("", "", "C:/home/example"),
    "C:/home/example/moondesk-workspace",
  )
  assert_eq(
    default_workspace_root_from_env(
      "/Volumes/Data/Moondesk", "/home/example", "",
    ),
    "/Volumes/Data/Moondesk",
  )
  assert_eq(
    default_workspace_root_from_env("  /tmp/moondesk-library  ", "", ""),
    "/tmp/moondesk-library",
  )
  assert_eq(default_workspace_root_from_env("", "", ""), "moondesk-workspace")
}

///|
async test "serve prepares moonbook library directories" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-default-workspace-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moondesk_workspace_root(root))
  assert_true(@fs.exists(@pathx.join(root, ".moontown/books")))
}

///|
async test "serve warns when workspace root is a source checkout" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-source-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let effective_root = serve_workspace_root(root)
  assert_true(effective_root != @pathx.normalize(root))
  assert_true(effective_root.contains("moondesk-workspace"))
  assert_false(@fs.exists(@pathx.join(root, ".moontown/books")))
  let warning = workspace_root_source_checkout_warning(root, effective_root~)
  assert_true(warning.contains("source checkout"))
  assert_true(warning.contains(effective_root))
  assert_true(warning.contains("moondesk-workspace"))
  let clean_root = @pathx.join(root, "moondesk-workspace")
  @fsx.make_directory(clean_root, recursive=true, exists_ok=true)
  assert_eq(
    workspace_root_source_checkout_warning(
      clean_root,
      effective_root=clean_root,
    ),
    "",
  )
}

///|
async test "source checkout redirect avoids configured root inside checkout" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-source-root-env-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let cwd = @pathx.dirname(root).to_owned()
  let home = @pathx.join(cwd, "safe-home")
  let home_effective = source_checkout_safe_workspace_root(
    root,
    configured_root=root,
    home~,
    user_profile="",
    cwd~,
  )
  assert_eq(home_effective, @pathx.join(home, "moondesk-workspace"))
  assert_false(
    workspace_root_contains_path(@pathx.normalize(root), home_effective),
  )
  let nested_home = @pathx.join(root, "nested-home")
  let sibling_effective = source_checkout_safe_workspace_root(
    root,
    configured_root=@pathx.join(root, "moondesk-workspace"),
    home=nested_home,
    user_profile="",
    cwd~,
  )
  assert_eq(sibling_effective, @pathx.join(cwd, "moondesk-workspace"))
  assert_false(
    workspace_root_contains_path(@pathx.normalize(root), sibling_effective),
  )
  assert_false(@fs.exists(@pathx.join(root, ".moontown/books")))
}

///|
async test "source checkout redirect resolves relative roots before safety checks" {
  let cwd = @pathx.join(
    "/tmp",
    "moondesk-source-root-relative-wbtest-" + @async.now().to_string(),
  )
  let root = @pathx.join(cwd, "checkout")
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let effective = source_checkout_safe_workspace_root(
    "checkout",
    configured_root="checkout/moondesk-workspace",
    home="checkout/home",
    user_profile="",
    cwd~,
  )
  assert_eq(effective, @pathx.join(cwd, "moondesk-workspace"))
  assert_false(workspace_root_contains_path(root, effective))
}

///|
async test "runtime entrypoint workspace resolver keeps user data out of checkout" {
  let repo_root = @pathx.join(
    "/tmp",
    "moondesk-entrypoint-source-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(repo_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(repo_root, "moon.mod"), "name = \"demo\"\n")
  let effective = resolve_user_workspace_root(".", repo_root)
  assert_true(effective.has_suffix("/moondesk-workspace"))
  assert_false(workspace_root_contains_path(repo_root, effective))
  assert_false(@fs.exists(@pathx.join(repo_root, ".moontown/books")))
}
