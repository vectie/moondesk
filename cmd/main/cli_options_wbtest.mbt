///|
test "default workspace root uses explicit override before home moonsuite" {
  assert_eq(
    default_workspace_root_from_environment("", "", "/Users/alice"),
    "/Users/alice/moonsuite",
  )
  assert_eq(
    default_workspace_root_from_environment(
      "/Volumes/Data/MoonDesk", "", "/Users/alice",
    ),
    "/Volumes/Data/MoonDesk",
  )
  assert_eq(
    default_workspace_root_from_environment(
      "  /tmp/moondesk-library  ", "", "/Users/alice",
    ),
    "/tmp/moondesk-library",
  )
  assert_eq(default_moonsuite_workspace_root_from_home(""), "moonsuite")
  assert_true(parse_serve_args([]) is Some(_))
  assert_true(parse_bundle_args([]) is Some(_))
}

///|
test "default workspace root uses Lepusa app data for installed desktop app" {
  assert_eq(
    default_workspace_root_from_environment(
      "", "/Users/alice/Library/Application Support/app.vectie.moondesk", "/Users/alice",
    ),
    "/Users/alice/Library/Application Support/app.vectie.moondesk/workspace",
  )
  assert_eq(
    default_workspace_root_from_environment(
      "/Users/alice/moonsuite", "/Users/alice/Library/Application Support/app.vectie.moondesk",
      "/Users/alice",
    ),
    "/Users/alice/moonsuite",
  )
}

///|
async test "first initialization creates default MoonSuite root" {
  let home = @pathx.join(
    "/tmp",
    "moondesk-default-home-wbtest-" + @async.now().to_string(),
  )
  let root = default_workspace_root_from_environment("", "", home)
  assert_eq(root, @pathx.join(home, "moonsuite"))
  assert_false(@fs.exists(root))
  assert_true(prepare_moondesk_workspace_root(root))
  assert_true(@fs.exists(root))
  assert_true(@fs.exists(@pathx.join(root, "books")))
  assert_true(@fs.exists(@pathx.join(root, ".tmp")))
  assert_true(@fs.exists(@pathx.join(root, ".moonsuite/suite.json")))
  assert_true(@fs.exists(@pathx.join(root, ".moonsuite/product-registry.json")))
}

///|
async test "serve prepares MoonSuite workspace directories" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-default-workspace-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moondesk_workspace_root(root))
  assert_true(@fs.exists(@pathx.join(root, "books")))
  assert_true(@fs.exists(@pathx.join(root, "inbox")))
  assert_true(@fs.exists(@pathx.join(root, "exports")))
  assert_true(@fs.exists(@pathx.join(root, ".tmp")))
  assert_true(@fs.exists(@pathx.join(root, ".moonsuite/suite.json")))
  let registry_path = @pathx.join(root, ".moonsuite/product-registry.json")
  assert_true(@fs.exists(registry_path))
  let registry = @json.parse(@fs.read_file(registry_path).text())
  let registry_products = @mooncore.json_array_items(registry, "products")
  let registry_product_ids = registry_products.map(product => {
    @mooncore.json_string(product, "id", default="")
  })
  for
    product_id in [
      "moondesk", "moonbook", "moonwiki", "mooncode", "moonclaw", "moontown", "moongate",
      "moonfish", "moonmoon", "moonchat", "moonvis", "moonrobo", "bookkeeper", "lepusa",
      "rabbita",
    ] {
    assert_true(
      @fs.exists(@pathx.join(root, ".moonsuite/products/\{product_id}")),
    )
    assert_true(registry_product_ids.contains(product_id))
  }
  for
    legacy_home in [
      ".moondesk", ".moonbook", ".moonwiki", ".mooncode", ".moonclaw", ".moontown",
      ".moongate", ".moonfish", ".moonmoon", ".moonchat", ".moonvis", ".bookkeeper",
      ".lepusa", ".rabbita",
    ] {
    assert_false(@fs.exists(@pathx.join(root, legacy_home)))
  }
}

///|
async test "workspace resolver redirects source checkout root to fallback" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-source-root-wbtest-" + @async.now().to_string(),
  )
  let fallback = @pathx.join(root, "../dedicated-workspace")
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let resolution = resolve_user_workspace_root_with_default(
    root,
    @pathx.dirname(root).to_owned(),
    fallback,
    "/Users/alice",
  )
  assert_true(resolution.redirected)
  assert_eq(resolution.requested_root, @pathx.normalize(root))
  assert_eq(resolution.workspace_root, @pathx.normalize(fallback))
  assert_true(prepare_moondesk_workspace_root(resolution.workspace_root))
  assert_false(@fs.exists(@pathx.join(root, ".moonsuite/suite.json")))
  assert_false(@fs.exists(@pathx.join(root, "books")))
  assert_true(@fs.exists(@pathx.join(fallback, ".moonsuite/suite.json")))
  assert_true(@fs.exists(@pathx.join(fallback, "books")))
}

///|
async test "workspace resolver uses home moonsuite if fallback is source checkout" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-source-root-env-wbtest-" + @async.now().to_string(),
  )
  let home = @pathx.join(root, "../home")
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let resolution = resolve_user_workspace_root_with_default(
    root,
    @pathx.dirname(root).to_owned(),
    root,
    home,
  )
  assert_true(resolution.redirected)
  assert_eq(resolution.workspace_root, @pathx.join(home, "moonsuite"))
}

///|
async test "workspace resolver keeps non-source roots inside checkout" {
  let cwd = @pathx.join(
    "/tmp",
    "moondesk-source-root-nested-wbtest-" + @async.now().to_string(),
  )
  let root = @pathx.join(cwd, "checkout")
  let nested = @pathx.join(root, "nested-suite")
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  assert_eq(resolve_user_workspace_root(nested, cwd), nested)
}

///|
async test "runtime entrypoint workspace resolver protects checkout root" {
  let repo_root = @pathx.join(
    "/tmp",
    "moondesk-entrypoint-source-root-wbtest-" + @async.now().to_string(),
  )
  let fallback = @pathx.join(repo_root, "../runtime-workspace")
  @fsx.make_directory(repo_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(repo_root, "moon.mod"), "name = \"demo\"\n")
  let resolution = resolve_user_workspace_root_with_default(
    ".", repo_root, fallback, "/Users/alice",
  )
  assert_true(resolution.redirected)
  assert_eq(resolution.requested_root, repo_root)
  assert_eq(resolution.workspace_root, @pathx.normalize(fallback))
  assert_true(
    workspace_root_guard_message(resolution).contains("MOONDESK_WORKSPACE_ROOT"),
  )
}
