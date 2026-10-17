///|
async fn retained_test_snapshot(
  root : String,
  relative : String,
  values : Map[String, Bytes],
) -> Unit {
  for entry in @fs.readdir(root + "/" + relative) {
    let path = relative + "/" + entry
    match @fs.kind(root + "/" + path, follow_symlink=false) {
      Directory => retained_test_snapshot(root, path, values)
      Regular => values[path] = @fs.read_file(root + "/" + path).binary()
      _ => fail("Unexpected fixture link")
    }
  }
}

///|
async fn retained_test_refused(
  root : String,
  workspace : @desk.DeskWorkspace,
  identity : Json,
  contains : String,
) -> Unit {
  let message = try {
    ignore(moonflow_retained_result(root, workspace, identity))
    "unexpected-success"
  } catch {
    error => error.to_string()
  }
  assert_not_eq(message, "unexpected-success")
  assert_true(message.contains(contains), msg=message)
}

///|
async test "retained descriptor read is binary safe bounded and rejects traversal symlink directory and FIFO" {
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-retained-reader-"))
  @fs.mkdir(root + "/safe")
  let raw : Bytes = [0x00, 0xff, 0x80, 0x0a, 0x0d, 0x22, 0x3c, 0x26]
  @fs.write_file(root + "/safe/binary.bin", raw, create_mode=CreateNew)
  assert_eq(moonflow_retained_bytes(root, "safe/binary.bin"), raw)
  @fs.symlink(target=root + "/safe/binary.bin", root + "/safe/link")
  @fs.symlink(target=root + "/safe", root + "/alias")
  for
    reference in [
      "safe/link", "alias/binary.bin", "safe", "../safe/binary.bin", "/safe/binary.bin",
      "safe//binary.bin", "safe/./binary.bin", "file:safe/binary.bin", "safe\\binary.bin",
    ] {
    let refused = try {
      ignore(moonflow_retained_bytes(root, reference))
      false
    } catch {
      _ => true
    }
    assert_true(refused, msg=reference)
  }
  @fs.write_file(
    root + "/safe/large",
    "x".repeat(4 * 1024 * 1024 + 1),
    create_mode=CreateNew,
  )
  assert_true(
    try {
      ignore(moonflow_retained_bytes(root, "safe/large"))
      false
    } catch {
      _ => true
    },
  )
  let fifo = @process.run("mkfifo", [root + "/safe/fifo"])
  assert_eq(fifo, 0)
  let output = FixedArray::make(64, b'0')
  assert_eq(
    moonflow_retained_read_native(
      @encoding/utf8.encode(root + "\u0000"),
      @encoding/utf8.encode("safe/fifo\u0000"),
      output,
      64,
    ),
    -1,
  )
  assert_eq(
    moonflow_retained_read_native(
      @encoding/utf8.encode(root + "\u0000"),
      @encoding/utf8.encode("safe/link\u0000"),
      output,
      64,
    ),
    -1,
  )
  assert_eq(
    moonflow_retained_read_native(
      @encoding/utf8.encode(root + "\u0000"),
      @encoding/utf8.encode("alias/binary.bin\u0000"),
      output,
      64,
    ),
    -1,
  )
}

///|
fn retained_test_set(value : Json, key : String, replacement : Json) -> Json {
  let copy = @json.parse(value.stringify()) catch { _ => Json::null() }
  if copy is Object(fields) {
    fields[key] = replacement
  }
  copy
}

///|
async test "retained result native HTTP inspection and downloads preserve exact result and all canonical records" {
  guard @env.get_env_var("MOONDESK_RETAINED_FIXTURE") is Some(path) &&
    @env.get_env_var("MOONDESK_RETAINED_HTTP_EVIDENCE") is Some(evidence_path) &&
    @env.get_env_var("MOONDESK_RETAINED_UI_DIST") is Some(dist) else {
    println(
      "RETAINED_NATIVE_HTTP_NOT_CONFIGURED: requires the private actual native export fixture",
    )
    return
  }
  let root = @fs.realpath(path)
  let run_id = "single-retained-export"
  let prefix = ".moonsuite/products/moonflow/runs/" + run_id
  let projection = moonflow_plan_read(root, prefix + "/projection.json")
  let item = moonflow_graph_items(projection).filter(item => {
      json_string(item, "work_item_id", default="") == "other"
    })[0]
  let workspace = @desk.workspace(
    id=@desk.stable_id("book", "single-step-book"),
    name="Native retained fixture",
    root_path=root + "/books/single-step-book",
    kind=MoonBook,
  )
  let identity : Json = {
    "workspace_id": workspace.id,
    "run_id": run_id,
    "work_item_id": "other",
    "attempt_id": json_string(item, "active_attempt_id", default=""),
    "result_id": json_string(item, "result_id", default=""),
    "action_id": "desk-retained-export",
    "artifact_index": 0,
  }
  let artifact_identity = retained_test_set(identity, "artifact_index", 1)
  let before : Map[String, Bytes] = Map([])
  retained_test_snapshot(root, ".moonsuite/products/moonflow", before)
  retained_test_snapshot(root, ".moonsuite/products/moonmold", before)
  let receipt = moonflow_retained_result(root, workspace, identity)
  let artifact = moonflow_retained_result(root, workspace, artifact_identity)
  assert_eq(
    json_string(receipt.metadata, "identity_scope", default=""),
    "Adapter receipt byte identity",
  )
  assert_eq(
    json_string(artifact.metadata, "identity_scope", default=""),
    "Flow-recorded artifact byte identity",
  )
  let semantic = @json.parse(@encoding/utf8.decode(artifact.bytes))
  assert_not_eq(
    json_string(semantic, "digest", default=""),
    json_string(artifact.metadata, "sha256", default=""),
  )
  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(dist, root),
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let base = "http://127.0.0.1:\{server.port()}"
    let (_, html) = test_http_get(base + "/", 200)
    assert_true(html.contains("/assets/"))
    let assets : Array[Json] = []
    let mut feature_served = false
    for name in @fs.readdir(dist + "/assets") {
      if !name.has_suffix(".js") {
        continue
      }
      let (response, data) = @http.get(base + "/assets/" + name)
      assert_eq(response.code, 200)
      let expected = @fs.read_file(dist + "/assets/" + name).binary()
      assert_eq(data.binary(), expected)
      if @encoding/utf8.decode(expected).contains("flow-retained-inspection") {
        feature_served = true
      }
      assets.push({
        "name": name,
        "sha256": moonflow_retained_sha(expected),
        "byte_length": expected.length(),
        "served_exact": true,
      })
    }
    assert_true(
      feature_served,
      msg="Ordinary served compiled Desk assets must contain retained inspection",
    )
    let workspaces = test_http_get_json(base + "/api/workspaces", 200)
    assert_true(workspaces.stringify().contains(workspace.id))
    let url_prefix = "/api/moonflow/retained/" +
      workspace.id +
      "/" +
      run_id +
      "/other/" +
      json_string(identity, "attempt_id", default="") +
      "/" +
      json_string(identity, "result_id", default="") +
      "/desk-retained-export/"
    let observations : Array[Json] = []
    for ordinal, expected in [receipt, artifact] {
      let url = url_prefix + ordinal.to_string()
      let response = test_http_get_json(base + url, 200)
      assert_eq(response, expected.metadata)
      let download = url +
        "/download/" +
        json_string(response, "sha256", default="")[7:].to_owned() +
        "-" +
        json_string(response, "record_digest", default="")[7:].to_owned()
      let (headers, body) = @http.get(base + download)
      assert_eq(headers.code, 200)
      assert_eq(
        headers.headers.get("content-type"),
        Some("application/octet-stream"),
      )
      assert_eq(headers.headers.get("x-content-type-options"), Some("nosniff"))
      assert_eq(body.binary(), expected.bytes)
      ignore(test_http_get(base + url + "/download/" + "0".repeat(64), 409))
      observations.push({
        "inspection_url": url,
        "download_url": download,
        "response": response,
        "download_sha256": moonflow_retained_sha(expected.bytes),
        "download_bytes_equal": true,
      })
    }
    let actual_projection = test_http_get_json(
      base + "/api/moonflow/runs/" + run_id,
      200,
    )
    // Compiled UI consumes these actual native HTTP responses and proves its
    // click selection, escaped rendering and exact download URL against them.
    @fs.write_file(
      evidence_path,
      (
        {
          "projection": actual_projection,
          "observations": observations,
          "served_index": html,
          "served_assets": assets,
          "native_http": true,
          "semantic_digest_is_not_file_bytes": true,
          "canonical_snapshot_files": before.length(),
          "qualification": "fixture-reference-only",
        } : Json).stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
    let artifact_path = root +
      "/" +
      json_string(artifact.metadata, "reference", default="")
    @fs.write_file(
      artifact_path,
      @encoding/utf8.decode(artifact.bytes) + " ",
      create_mode=CreateOrTruncate,
    )
    let changed = test_http_get_json(base + url_prefix + "1", 200)
    assert_eq(json_string(changed, "status", default=""), "unavailable")
    ignore(
      test_http_get(
        base + json_string(observations[1], "download_url", default=""),
        409,
      ),
    )
    @fs.write_file(artifact_path, artifact.bytes, create_mode=CreateOrTruncate)
    ignore(test_http_get(base + url_prefix + "1", 200))
    let evidence_manifest = root +
      "/" +
      prefix +
      "/single-step/other.evidence.json"
    let manifest_original = @fs.read_file(evidence_manifest).binary()
    // Even semantically identical observation records invalidate a download
    // pinned to the earlier exact record bytes.
    @fs.write_file(
      evidence_manifest,
      @encoding/utf8.decode(manifest_original) + " ",
      create_mode=CreateOrTruncate,
    )
    ignore(
      test_http_get(
        base + json_string(observations[1], "download_url", default=""),
        409,
      ),
    )
    @fs.write_file(
      evidence_manifest,
      manifest_original,
      create_mode=CreateOrTruncate,
    )
    // Synthetic binary per-file observation tests the raw transfer boundary;
    // the unchanged native JSON artifact above is the protocol qualification.
    let binary : Bytes = [0x00, 0xff, 0x80, 0x0a, 0x0d, 0x3c, 0x26, 0x22]
    let binary_manifest = @json.parse(@encoding/utf8.decode(manifest_original))
    if binary_manifest is Array(entries) {
      entries[1] = retained_test_set(
        retained_test_set(
          entries[1],
          "sha256",
          ToJson::to_json(moonflow_retained_sha(binary)),
        ),
        "byte_length",
        ToJson::to_json(binary.length()),
      )
    }
    @fs.write_file(artifact_path, binary, create_mode=CreateOrTruncate)
    @fs.write_file(
      evidence_manifest,
      binary_manifest.stringify(),
      create_mode=CreateOrTruncate,
    )
    let binary_response = test_http_get_json(base + url_prefix + "1", 200)
    assert_eq(
      json_string(binary_response, "preview_kind", default=""),
      "binary",
    )
    let binary_url = base +
      url_prefix +
      "1/download/" +
      json_string(binary_response, "sha256", default="")[7:].to_owned() +
      "-" +
      json_string(binary_response, "record_digest", default="")[7:].to_owned()
    let (binary_headers, binary_body) = @http.get(binary_url)
    assert_eq(binary_headers.code, 200)
    assert_eq(binary_body.binary(), binary)
    @fs.write_file(artifact_path, artifact.bytes, create_mode=CreateOrTruncate)
    @fs.write_file(
      evidence_manifest,
      manifest_original,
      create_mode=CreateOrTruncate,
    )
  })
  // Wrong identities cannot be used as a path selector, including another Book.
  for
    key in [
      "workspace_id", "run_id", "work_item_id", "attempt_id", "result_id", "action_id",
    ] {
    retained_test_refused(
      root,
      workspace,
      retained_test_set(identity, key, "wrong"),
      "",
    )
  }
  retained_test_refused(
    root,
    workspace,
    retained_test_set(identity, "artifact_index", 9),
    "Unknown retained output",
  )
  let receipt_path = root +
    "/" +
    json_string(receipt.metadata, "reference", default="")
  @fs.write_file(
    receipt_path,
    @encoding/utf8.decode(receipt.bytes) + " ",
    create_mode=CreateOrTruncate,
  )
  retained_test_refused(
    root, workspace, identity, "receipt byte identity changed",
  )
  @fs.write_file(receipt_path, receipt.bytes, create_mode=CreateOrTruncate)
  let manifest_path = root + "/" + prefix + "/single-step/other.evidence.json"
  let manifest_bytes = @fs.read_file(manifest_path).binary()
  let manifest = @json.parse(@encoding/utf8.decode(manifest_bytes))
  if manifest is Array(records) {
    records[1] = retained_test_set(records[1], "sha256", "sha256:wrong")
  }
  @fs.write_file(
    manifest_path,
    manifest.stringify(),
    create_mode=CreateOrTruncate,
  )
  retained_test_refused(root, workspace, artifact_identity, "manifest differs")
  @fs.write_file(manifest_path, manifest_bytes, create_mode=CreateOrTruncate)
  let artifact_path = root +
    "/" +
    json_string(artifact.metadata, "reference", default="")
  let held = artifact_path + ".retained-test-held"
  @fs.rename(artifact_path, held, replace=false)
  retained_test_refused(root, workspace, artifact_identity, "missing")
  @fs.symlink(target=held, artifact_path)
  retained_test_refused(root, workspace, artifact_identity, "unsafe")
  @fs.remove(artifact_path)
  @fs.rename(held, artifact_path, replace=false)
  for record in ["action", "request", "result"] {
    let record_path = root +
      "/" +
      prefix +
      "/single-step/other." +
      record +
      ".json"
    let original = @fs.read_file(record_path).binary()
    let changed = retained_test_set(
      @json.parse(@encoding/utf8.decode(original)),
      "request_id",
      "wrong-request",
    )
    @fs.write_file(
      record_path,
      changed.stringify(),
      create_mode=CreateOrTruncate,
    )
    retained_test_refused(
      root, workspace, artifact_identity, "identity changed",
    )
    @fs.write_file(record_path, original, create_mode=CreateOrTruncate)
  }
  let projection_path = root + "/" + prefix + "/projection.json"
  let projection_bytes = @fs.read_file(projection_path).binary()
  let unsupported = @json.parse(@encoding/utf8.decode(projection_bytes))
  if unsupported is { "items": Array(items), .. } {
    for index, value in items {
      if json_string(value, "work_item_id", default="") == "other" {
        items[index] = retained_test_set(
          value, "operation", "moonmold/spatial.operation.execute@9.9.9",
        )
      }
    }
  }
  @fs.write_file(
    projection_path,
    unsupported.stringify(),
    create_mode=CreateOrTruncate,
  )
  retained_test_refused(
    root, workspace, artifact_identity, "Unsupported result protocol",
  )
  @fs.write_file(
    projection_path,
    projection_bytes,
    create_mode=CreateOrTruncate,
  )
  let after : Map[String, Bytes] = Map([])
  retained_test_snapshot(root, ".moonsuite/products/moonflow", after)
  retained_test_snapshot(root, ".moonsuite/products/moonmold", after)
  assert_eq(before.length(), after.length())
  for key, bytes in before {
    assert_eq(after.get(key), Some(bytes), msg=key)
  }
  println(
    "RETAINED_NATIVE_HTTP: actual native receipt + export artifact inspected/downloaded; all canonical Flow event/action/request/result/evidence/review and Mold attempt bytes unchanged; tamper, manifest mismatch, wrong identity, missing and symlink refused",
  )
}
