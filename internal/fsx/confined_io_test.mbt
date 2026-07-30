///|
async test "confined IO rejects traversal and symlink escapes for reads and writes" {
  let root = @fs.tmpdir(prefix="moondesk-confined-root-")
  let outside = @fs.tmpdir(prefix="moondesk-confined-outside-")
  @fs.write_file(
    @pathx.join(outside, "secret.txt"),
    @encoding/utf8.encode("secret"),
    create_mode=CreateOrTruncate,
  )
  @fs.symlink(target=outside, @pathx.join(root, "escape"))

  assert_true(@fsx.resolve_confined_existing(root, "../secret.txt") is None)
  assert_true(@fsx.resolve_confined_existing(root, "escape/secret.txt") is None)
  assert_true(@fsx.resolve_confined_write(root, "../written.txt") is None)
  assert_true(@fsx.resolve_confined_write(root, "escape/written.txt") is None)
  assert_false(@fsx.write_confined_text(root, "escape/written.txt", "escaped"))
  assert_false(@fs.exists(@pathx.join(outside, "written.txt")))
}

///|
async test "confined IO creates only verified descendants and refuses final symlinks" {
  let root = @fs.tmpdir(prefix="moondesk-confined-write-")
  let outside = @fs.tmpdir(prefix="moondesk-confined-target-")
  let outside_file = @pathx.join(outside, "outside.md")
  @fs.write_file(
    outside_file,
    @encoding/utf8.encode("outside"),
    create_mode=CreateOrTruncate,
  )

  assert_true(@fsx.write_confined_text(root, "wiki/nested/page.md", "inside"))
  assert_eq(
    @fs.read_file(@pathx.join(root, "wiki/nested/page.md")).text(),
    "inside",
  )
  assert_true(
    @fsx.read_confined_text(root, "wiki/nested/page.md") is Some("inside"),
  )

  let linked = @pathx.join(root, "wiki/linked.md")
  @fs.symlink(target=outside_file, linked)
  assert_false(@fsx.write_confined_text(root, "wiki/linked.md", "changed"))
  assert_eq(@fs.read_file(outside_file).text(), "outside")
}
