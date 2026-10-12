///|
async fn review_test_http(
  base : String,
  path : String,
  account : String,
  payload : Json?,
) -> Json {
  let headers : Map[String, String] = { "Cookie": account, "Origin": base }
  let (response, body) = match payload {
    Some(value) => @http.post(base + path, value, headers~)
    None => @http.get(base + path, headers~)
  }
  assert_eq(response.code, 200)
  @json.parse(body.text())
}

///|
fn review_test_rewrite(value : Json, changes : Map[String, Json]) -> Json raise {
  let copy = @json.parse(value.stringify())
  if copy is Object(fields) {
    for key, value in changes {
      fields[key] = value
    }
  }
  copy
}

///|
async test "exact review real Desk HTTP authenticates maps existing human applies Flow and reopens immutable decision" {
  guard @env.get_env_var("MOONDESK_REVIEW_FIXTURE") is Some(root) &&
    @env.get_env_var("MOONDESK_REVIEW_UI_REQUEST") is Some(ui_request_path) &&
    @env.get_env_var("MOONDESK_REVIEW_EVIDENCE") is Some(evidence_path) else {
    println(
      "EXACT_REVIEW_HTTP_NOT_CONFIGURED: real identity/HTTP/Flow crossing was not exercised",
    )
    return
  }
  let request = @json.parse(@fs.read_file(ui_request_path).text())
  let identity = json_object_field(request, "identity").unwrap()
  let workspace_id = json_string(identity, "workspace_id", default="")
  let workspace_root = root + "/books/single-step-book"
  let snapshot_path = moonflow_collaboration_snapshot_path(
    workspace_root, workspace_id,
  )
  let before_snapshot = @fs.read_file(snapshot_path).binary()
  let baseline : Map[String, Bytes] = Map([])
  for
    prefix in [
      ".moonsuite/products/moonflow/runs", ".moonsuite/products/moongate", ".moonsuite/products/moonmold",
    ] {
    retained_test_snapshot(root, prefix, baseline)
  }
  let identity_server = Server::new("127.0.0.1", 48939, reuse_addr=true)
  defer identity_server.close()
  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  let auth_calls = Ref(0)
  let dist = @env.get_env_var("MOONDESK_REVIEW_UI_DIST").unwrap_or(root)
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        identity_server.server.run_forever(
          (request, _, conn) => {
            auth_calls.val += 1
            if request.path == "/auth/session" {
              let name = request.headers.get("cookie").unwrap_or("")
              if [
                  "reviewer", "submitter", "other", "outsider", "service", "suspended",
                ].contains(name) {
                send_json(conn, request.meth, {
                  "session_token": "lnxs_fixture_" + name,
                })
              } else {
                send_status(
                  conn, 401, "Unauthorized", "Synthetic login required",
                )
              }
            } else if request.path == "/v1/auth/self" {
              let token = request.headers.get("authorization").unwrap_or("")
              let name = token["Bearer lnxs_fixture_".length():].to_owned()
              guard token.has_prefix("Bearer lnxs_fixture_") else {
                send_status(
                  conn, 401, "Unauthorized", "Synthetic session required",
                )
                return
              }
              send_json(conn, request.meth, {
                "account_id": "account-" + name,
                "subject_ref": "subject-" + name,
                "state": if name == "suspended" {
                  "Suspended"
                } else {
                  "Active"
                },
                "roles": ["PlatformOperator"],
              })
            } else {
              send_status(conn, 404, "Not Found", "Not found")
            }
          },
          allow_failure=true,
        )
      },
      no_wait=true,
      allow_failure=true,
    )
    group.spawn_bg(
      () => server.serve_desk(dist, root),
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let base = "http://127.0.0.1:" + server.port().to_string()
    let url = "/api/moonflow/retained/" +
      workspace_id +
      "/" +
      json_string(identity, "run_id", default="") +
      "/" +
      json_string(identity, "work_item_id", default="") +
      "/" +
      json_string(identity, "attempt_id", default="") +
      "/" +
      json_string(identity, "result_id", default="") +
      "/" +
      json_string(identity, "action_id", default="") +
      "/1"
    let retained = review_test_http(base, url, "reviewer", None)
    let initial = review_test_http(base, url + "/review", "reviewer", None)
    assert_eq(json_string(initial, "status", default=""), "ready")
    assert_eq(json_array_items(initial, "reviews").length(), 2)
    assert_eq(
      json_string(initial, "head_digest", default=""),
      json_string(request, "expected_head", default=""),
    )
    // The ordinary public gate still uses exactly the active operator rule,
    // while review identity independently revalidates the same account seam.
    let calls = auth_calls.val
    assert_true(moondesk_operator_authorized("reviewer"))
    assert_true(moondesk_operator_authorized("reviewer"))
    assert_eq(auth_calls.val - calls, 4)
    assert_false(moondesk_operator_authorized("suspended"))
    let denials : Array[Json] = []
    for
      account in ["", "submitter", "other", "outsider", "service", "suspended"] {
      let response = review_test_http(
        base,
        "/api/moonflow/review",
        account,
        Some(request),
      )
      assert_eq(json_string(response, "status", default=""), "unavailable")
      assert_eq(@fs.read_file(snapshot_path).binary(), before_snapshot)
      denials.push({
        "case": if account == "" {
          "unauthenticated"
        } else {
          account
        },
        "status": "refused",
      })
    }
    let mapping = @env.get_env_var("MOONDESK_REVIEW_PRINCIPAL_MAP").unwrap()
    @fs.rename(mapping, mapping + ".held", replace=false)
    let missing = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(request),
    ) catch {
      error => {
        @fs.rename(mapping + ".held", mapping, replace=false)
        raise error
      }
    }
    @fs.rename(mapping + ".held", mapping, replace=false)
    assert_true(json_string(missing, "message", default="").contains("mapping"))
    let stale = review_test_rewrite(request, {
      "expected_head": ("sha256:" + "0".repeat(64)).to_json(),
      "mutation_id": "stale-head",
    })
    let stale_response = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(stale),
    )
    assert_true(
      json_string(stale_response, "message", default="").contains("Stale"),
    )
    assert_eq(json_string(stale_response, "status", default=""), "rejected")
    assert_eq(
      json_string(stale_response, "mutation_status", default=""),
      "not-applied",
    )
    assert_eq(
      json_object_field(stale_response, "rejected_request"),
      Some(stale),
    )
    let wrong_subject = review_test_rewrite(request, {
      "sha256": ("sha256:" + "0".repeat(64)).to_json(),
      "mutation_id": "wrong-subject",
    })
    assert_eq(
      json_string(
        review_test_http(
          base,
          "/api/moonflow/review",
          "reviewer",
          Some(wrong_subject),
        ),
        "status",
        default="",
      ),
      "unavailable",
    )
    let injected = review_test_rewrite(request, {
      "actor": review_test_principal("reviewer"),
    })
    assert_eq(
      json_string(
        review_test_http(
          base,
          "/api/moonflow/review",
          "reviewer",
          Some(injected),
        ),
        "status",
        default="",
      ),
      "unavailable",
    )
    let artifact = root + "/" + json_string(retained, "reference", default="")
    let original = @fs.read_file(artifact).binary()
    @fs.write_file(
      artifact,
      original + b"changed",
      create_mode=TruncateExisting,
    )
    let changed = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(request),
    ) catch {
      error => {
        @fs.write_file(artifact, original, create_mode=TruncateExisting)
        raise error
      }
    }
    @fs.write_file(artifact, original, create_mode=TruncateExisting)
    assert_eq(json_string(changed, "status", default=""), "unavailable")
    assert_eq(@fs.read_file(snapshot_path).binary(), before_snapshot)
    let applied = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(request),
    )
    assert_eq(
      json_string(applied, "mutation_status", default=""),
      "persisted",
      msg=applied.stringify(),
    )
    let approved_snapshot = @fs.read_file(snapshot_path).binary()
    // Deliberately discard applied from the browser state. Original-id retry
    // goes through the actual HTTP route and the existing Flow CLI replay.
    let replayed = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(request),
    )
    assert_eq(
      json_string(replayed, "mutation_status", default=""),
      "reconciled",
    )
    assert_eq(@fs.read_file(snapshot_path).binary(), approved_snapshot)
    let conflict = review_test_rewrite(request, {
      "notes": "Different content for same mutation",
    })
    let conflict_response = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(conflict),
    )
    assert_true(
      json_string(conflict_response, "message", default="").contains(
        "different content",
      ),
    )
    assert_eq(@fs.read_file(snapshot_path).binary(), approved_snapshot)
    let begin = review_test_rewrite(request, {
      "review_id": "review-changes",
      "mutation_id": "begin-changes",
      "action": "begin",
      "notes": "",
      "expected_head": json_object_field(replayed, "head_digest").unwrap(),
    })
    let begun = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(begin),
    )
    assert_eq(json_string(begun, "mutation_status", default=""), "persisted")
    let changes = review_test_rewrite(begin, {
      "mutation_id": "decide-changes",
      "action": "changes-requested",
      "notes": "Needs another exact artifact revision",
      "expected_head": json_object_field(begun, "head_digest").unwrap(),
    })
    let changed_review = review_test_http(
      base,
      "/api/moonflow/review",
      "reviewer",
      Some(changes),
    )
    assert_eq(
      json_string(changed_review, "mutation_status", default=""),
      "persisted",
    )
    let reopened = review_test_http(base, url + "/review", "reviewer", None)
    let reviews = json_array_items(reopened, "reviews")
    assert_true(
      reviews.any(entry => {
        json_string(
          json_object_field(entry, "review").unwrap(),
          "state",
          default="",
        ) ==
        "approved"
      }),
    )
    assert_true(
      reviews.any(entry => {
        json_string(
          json_object_field(entry, "review").unwrap(),
          "state",
          default="",
        ) ==
        "changes-requested"
      }),
    )
    for entry in reviews {
      let review = json_object_field(entry, "review").unwrap()
      let evidence = json_object_field(entry, "evidence").unwrap()
      assert_eq(
        json_string(evidence, "subject_digest", default=""),
        json_string(retained, "sha256", default=""),
      )
      assert_true(json_string(evidence, "notes", default="") != "")
      let bytes = moonflow_retained_bytes(
        workspace_root,
        json_string(review, "decision_evidence_ref", default=""),
      )
      assert_eq(
        moonflow_retained_sha(bytes),
        json_string(review, "decision_evidence_digest", default=""),
      )
    }
    let final_files : Map[String, Bytes] = Map([])
    for
      prefix in [
        ".moonsuite/products/moonflow/runs", ".moonsuite/products/moongate", ".moonsuite/products/moonmold",
      ] {
      retained_test_snapshot(root, prefix, final_files)
    }
    assert_eq(final_files, baseline)
    let projection = review_test_http(
      base,
      "/api/moonflow/runs/single-retained-export",
      "reviewer",
      None,
    )
    let mut served_feature = false
    for name in @fs.readdir(dist + "/assets") {
      if name.has_suffix(".js") {
        let (response, data) = @http.get(base + "/assets/" + name)
        assert_eq(response.code, 200)
        let bytes = @fs.read_file(dist + "/assets/" + name).binary()
        assert_eq(data.binary(), bytes)
        if @encoding/utf8.decode(bytes).contains("flow-exact-review") {
          served_feature = true
        }
      }
    }
    assert_true(served_feature)
    @fs.write_file(
      evidence_path,
      (
        {
          "request": request,
          "retained": retained,
          "initial": initial,
          "applied": applied,
          "replayed": replayed,
          "begun": begun,
          "changes_requested": changed_review,
          "reopened": reopened,
          "projection": projection,
          "denials": denials,
          "same_id_conflict_refused": true,
          "stale_head_refused": true,
          "stale_request": stale,
          "stale_rejection": stale_response,
          "changed_artifact_refused": true,
          "missing_mapping_refused": true,
          "served_compiled_ui": true,
          "run_gate_mold_files_unchanged": baseline.length(),
          "scope": "synthetic identity only; production principal mapping not established",
        } : Json).stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
    println(
      "EXACT_REVIEW_HTTP_PASS: compiled UI request through real Desk authentication/mapping and fixed Flow collaboration CLI, fresh persisted decisions and immutable evidence; no run Gate or Mold mutation",
    )
  })
}
