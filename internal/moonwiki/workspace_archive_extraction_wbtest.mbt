///|
fn archive_test_bytes(text : String) -> FixedArray[Byte] {
  @encoding/utf8.encode(text).to_fixedarray()
}

///|
async fn archive_test_write(path : String, bytes : FixedArray[Byte]) -> Unit {
  @fs.write_file(
    path,
    Bytes::makei(bytes.length(), index => bytes[index]),
    create_mode=CreateNew,
    permission=0o600,
  ) catch {
    error => fail("could not write archive fixture: \{error}")
  }
}

///|
async test "stored MoonBook ZIP stages payload as data without executing it" {
  @moonlib/fsx.with_temporary_directory("moondesk-stored-archive-marker-", root => {
    let marker = @pathx.join(root, "payload-executed")
    let payload = "open('" + marker + "', 'w').write('executed')"
    let archive = @moonzip.zip_sync(
      [
        ("book.toml", archive_test_bytes("title = \"Stored Book\"\n")),
        ("wiki/index.md", archive_test_bytes("# Stored Book\n")),
        ("payload.py", archive_test_bytes(payload)),
      ],
      opts={ ..@zip_types.ZipOptions::default(), level: 0 },
    )
    let archive_path = @pathx.join(root, "book.zip")
    let extract_root = @pathx.join(root, "extract")
    archive_test_write(archive_path, archive)
    @fs.mkdir(extract_root, recursive=true)
    assert_true(
      import_extract_zip_archive(archive_path, extract_root) is ArchiveExtracted,
    )
    assert_eq(
      @fs.read_file(@pathx.join(extract_root, "payload.py")).text(),
      payload,
    )
    assert_false(@fs.exists(marker))
  })
}

///|
async test "deflated MoonBook ZIP fails closed without staging or marker execution" {
  @moonlib/fsx.with_temporary_directory("moondesk-deflated-archive-marker-", root => {
    let marker = @pathx.join(root, "payload-executed")
    let archive = @moonzip.zip_sync([
      (
        "payload.py",
        archive_test_bytes(
          "open('" + marker + "', 'w').write('executed')".repeat(64),
        ),
      ),
    ])
    let archive_path = @pathx.join(root, "book.zip")
    let extract_root = @pathx.join(root, "extract")
    archive_test_write(archive_path, archive)
    @fs.mkdir(extract_root, recursive=true)
    guard import_extract_zip_archive(archive_path, extract_root)
      is ArchiveRejected(reason) else {
      fail("deflated archive must be rejected")
    }
    assert_true(reason.contains("execution sandbox"))
    assert_false(@fs.exists(@pathx.join(extract_root, "payload.py")))
    assert_false(@fs.exists(marker))
  })
}

///|
async test "stored ZIP symlink metadata is rejected before staging" {
  @moonlib/fsx.with_temporary_directory("moondesk-symlink-archive-", root => {
    let archive = @moonzip.zip_sync(
      [("link", archive_test_bytes("../outside"))],
      opts={ ..@zip_types.ZipOptions::default(), level: 0 },
      entry_opts=[
        Some({
          ..@zip_types.ZipEntryOptions::default(),
          level: 0,
          attrs: Some({
            os: Some(3),
            attrs: Some(0xA000 << 16),
            comment: None,
            extra: None,
          }),
        }),
      ],
    )
    let archive_path = @pathx.join(root, "book.zip")
    let extract_root = @pathx.join(root, "extract")
    archive_test_write(archive_path, archive)
    @fs.mkdir(extract_root, recursive=true)
    assert_true(
      import_extract_zip_archive(archive_path, extract_root)
      is ArchiveRejected(_),
    )
    assert_false(@fs.exists(@pathx.join(extract_root, "link")))
  })
}
