///|
async test "desktop control pairing is private stable and grants no Book roots" {
  @moonlib/fsx.with_temporary_directory("desk-private-control-", directory => {
    let root = @fs.realpath(directory)
    let path = prepare_moonclaw_private_control_at(root, root + "/control")
    let before = @fs.read_file(path).text()
    let payload = @json.parse(before)
    assert_true(payload is { "trusted_book_roots": Array([]), .. })
    assert_eq(json_string(payload, "workspace_root", default=""), root)
    assert_eq(
      prepare_moonclaw_private_control_at(root, root + "/control"),
      path,
    )
    assert_eq(@fs.read_file(path).text(), before)
    @fs.write_file(path, "{}", create_mode=CreateOrTruncate)
    try prepare_moonclaw_private_control_at(root, root + "/control") catch {
      _ => ()
    } noraise {
      _ => fail("Malformed existing control file must not be replaced")
    }
    assert_eq(@fs.read_file(path).text(), "{}")
  })
}
