///|
test "bundled runtime metadata identifies MoonClaw and a safe version" {
  assert_eq(
    bundled_moonclaw_version(
      "name = \"vectie/moonclaw\"\nversion = \"0.1.7\"\n",
    ),
    Ok("0.1.7"),
  )
  assert_true(
    bundled_moonclaw_version("name = \"other/product\"\nversion = \"0.1.7\"")
    is Err(_),
  )
  assert_true(
    bundled_moonclaw_version(
      "name = \"vectie/moonclaw\"\nversion = \"../escape\"",
    )
    is Err(_),
  )
  assert_true(bundled_moonclaw_version("name = \"vectie/moonclaw\"") is Err(_))
}

///|
async test "bundled runtime copies without executing and retries idempotently" {
  @fsx.with_temporary_directory("moondesk-code-bundle-", root => {
    let app = root + "/Contents"
    let source = app + "/Resources/moonclaw-runtime"
    let registry = root + "/registry"
    assert_eq(provision_bundled_moonclaw_at(app, registry), Ok(None))
    assert_false(@fs.exists(registry))
    @fs.mkdir(source + "/bin", recursive=true)
    @fs.write_file(
      source + "/moon.mod",
      "name = \"vectie/moonclaw\"\nversion = \"0.1.7\"",
      permission=0o644,
    )
    @fs.write_file(
      source + "/bin/moonclaw",
      "inert runtime fixture; never execute",
      permission=0o755,
    )
    assert_eq(provision_bundled_moonclaw_at(app, registry), Ok(Some("0.1.7")))
    let installed = registry + "/moonclaw/0.1.7/bin/moonclaw"
    assert_eq(
      @fs.read_file(installed).text(),
      "inert runtime fixture; never execute",
    )
    assert_true(@fs.can_execute(installed))
    assert_eq(provision_bundled_moonclaw_at(app, registry), Ok(Some("0.1.7")))
    @fs.write_file(installed, "different runtime", create_mode=CreateOrTruncate)
    assert_true(provision_bundled_moonclaw_at(app, registry) is Err(_))
    assert_eq(@fs.read_file(installed).text(), "different runtime")
  })
}

///|
async test "incomplete bundled runtime cannot create a managed installation" {
  @fsx.with_temporary_directory("moondesk-code-bundle-invalid-", root => {
    let app = root + "/Contents"
    let source = app + "/Resources/moonclaw-runtime"
    @fs.mkdir(source, recursive=true)
    @fs.write_file(
      source + "/moon.mod",
      "name = \"other/product\"\nversion = \"0.1.7\"",
    )
    assert_true(
      provision_bundled_moonclaw_at(app, root + "/registry") is Err(_),
    )
    assert_false(@fs.exists(root + "/registry"))
  })
}
