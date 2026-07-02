///|
test "default workspace root only uses explicit environment override" {
  assert_eq(default_workspace_root_from_env(""), "")
  assert_eq(
    default_workspace_root_from_env("/Volumes/Data/Moondesk"),
    "/Volumes/Data/Moondesk",
  )
  assert_eq(
    default_workspace_root_from_env("  /tmp/moondesk-library  "),
    "/tmp/moondesk-library",
  )
  assert_true(parse_serve_args([]) is None)
  assert_true(parse_bundle_args([]) is None)
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
      "moondesk", "moonbook", "moonwiki", "mooncode", "moonclaw", "moontown", "moonstat",
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
      ".moonstat", ".moonfish", ".moonmoon", ".moonchat", ".moonvis", ".bookkeeper",
      ".lepusa", ".rabbita",
    ] {
    assert_false(@fs.exists(@pathx.join(root, legacy_home)))
  }
}

///|
async test "serve honors source checkout root as explicit MoonSuite root" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-source-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let effective_root = serve_workspace_root(root)
  assert_eq(effective_root, @pathx.normalize(root))
  assert_true(prepare_moondesk_workspace_root(effective_root))
  assert_true(@fs.exists(@pathx.join(root, ".moonsuite/suite.json")))
  assert_true(@fs.exists(@pathx.join(root, "books")))
}

///|
async test "workspace resolver honors configured root inside checkout" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-source-root-env-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let cwd = @pathx.dirname(root).to_owned()
  let nested = @pathx.join(root, "moondesk-workspace")
  assert_eq(resolve_user_workspace_root(root, cwd), root)
  assert_eq(resolve_user_workspace_root(nested, cwd), nested)
}

///|
async test "workspace resolver normalizes relative roots without redirect" {
  let cwd = @pathx.join(
    "/tmp",
    "moondesk-source-root-relative-wbtest-" + @async.now().to_string(),
  )
  let root = @pathx.join(cwd, "checkout")
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "moon.mod"), "name = \"demo\"\n")
  let effective = resolve_user_workspace_root("checkout", cwd)
  assert_eq(effective, root)
}

///|
async test "runtime entrypoint workspace resolver uses selected checkout root" {
  let repo_root = @pathx.join(
    "/tmp",
    "moondesk-entrypoint-source-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(repo_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(repo_root, "moon.mod"), "name = \"demo\"\n")
  let effective = resolve_user_workspace_root(".", repo_root)
  assert_eq(effective, repo_root)
}
