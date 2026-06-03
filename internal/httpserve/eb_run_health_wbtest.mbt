///|
async test "eb production source screen requires durable pdf evidence records" {
  let root = "/tmp/moondesk-eb-source-screen-evidence-wbtest"
  let run_id = "run-eb-source-screen-evidence"
  let book_id = "research-eb-source-screen-evidence"
  let valid_path = @pathx.join(root, "valid-source-screen.json")
  let counter_only_path = @pathx.join(root, "counter-only-source-screen.json")
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let valid_screen = eb_live_official_source_screen_json(
    book_id~,
    run_id~,
    bond_code="132018",
    bond_short_name="G三峡EB1",
    as_of="20260602",
    official_url="https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2024-03-27/132018_20240327_CFRC.pdf",
  )
  @fsx.write_to_file(
    valid_path,
    valid_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(root, "raw/pdfs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(root, "raw/extracted"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "raw/pdfs/" + run_id + "-official-evidence.pdf"),
    "%PDF-1.4\n% durable EB evidence fixture\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(root, "raw/extracted/" + run_id + "-official-evidence.txt"),
    "durable extracted EB evidence fixture\n",
    create=0o644,
  )
  let counter_only_screen : Json = {
    "kind": "eb-official-source-screen",
    "status": "official_source_screened",
    "book_id": book_id,
    "run_id": run_id,
    "bond_code": "132018",
    "bond_short_name": "G三峡EB1",
    "as_of": "20260602",
    "official_domains": json_from_string_array(eb_official_domains()),
    "official_domain_count": eb_official_domains().length(),
    "checked_official_urls": json_from_string_array([
      "https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2024-03-27/132018_20240327_CFRC.pdf",
    ]),
    "checked_sources_count": 1,
    "downloaded_pdf_count": 1,
    "extracted_pdf_count": 1,
    "live_fetch_performed": true,
  }
  @fsx.write_to_file(
    counter_only_path,
    counter_only_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_true(eb_production_source_screen_valid(valid_path))
  assert_true(eb_production_source_screen_valid_for_book(root, valid_path))
  assert_false(eb_production_source_screen_valid(counter_only_path))
  assert_false(
    eb_production_source_screen_valid_for_book(root, counter_only_path),
  )
}

///|
async test "eb run health marks timed-out running moonclaw run as orphaned" {
  let root = "/tmp/moondesk-eb-orphaned-timeout-wbtest"
  let book_id = "research-eb-orphaned-timeout-eb-watch"
  let run_id = "run-eb-orphaned-timeout"
  let home = @pathx.join(root, ".moonclaw")
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(town_standing_goals_path(root), "[]\n", create=0o644)
  ignore(create_pdf_watch_book_dirs(book_root))
  let target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB orphaned timeout",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate timed-out Running MoonClaw run health.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB orphaned timeout",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate timed-out Running MoonClaw run health.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        eb_target_bonds=[target],
      ),
      method_body=default_eb_analysis_method("EB orphaned timeout"),
      websites=eb_default_source_websites(),
      eb_target_fields=target,
      eb_target_bonds=[target],
    ),
  )
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB orphaned timeout",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate timed-out Running MoonClaw run health.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id="exchangeable-bond-evidence-watch",
      goal~,
    ),
  )
  let import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": true,
    "status": "run_confirmed",
    "proposal_id": "proposal-eb-orphaned-timeout",
    "run_id": run_id,
    "home": home,
    "exit_code": 0,
    "stderr": "",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    import_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(home, "jobs/runs/" + run_id),
    recursive=true,
    exists_ok=true,
  )
  let run_meta : Json = {
    "id": run_id,
    "job_id": "job-eb-orphaned-timeout",
    "status": "Running",
    "workspace_dir": @pathx.join(book_root, "moonclaw-jobs/" + run_id),
  }
  @fsx.write_to_file(
    @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    run_meta.stringify(indent=2) + "\n",
    create=0o644,
  )
  let run_receipt : Json = {
    "kind": "moonclaw-confirmed-run-receipt",
    "book_id": book_id,
    "run_id": run_id,
    "ok": false,
    "status": "timed_out",
    "timed_out": true,
    "orphaned_after_timeout": true,
    "retry_recommended": true,
    "timeout_ms": 1000,
    "exit_code": -1,
    "home": home,
    "meta_path": @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    "meta": run_meta,
    "stderr": "MoonClaw confirmed run timed out or failed after 1000ms: TimeoutError",
  }
  assert_true(eb_moonclaw_run_receipt_orphaned_after_timeout(run_receipt))
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    run_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  let health = eb_durable_run_health(root, book_root, book_id)
  assert_eq(
    json_string(health, "status", default=""),
    "moonclaw_run_orphaned_after_timeout",
  )
  assert_true(
    json_bool(health, "moonclaw_run_orphaned_after_timeout", default=false),
  )
  assert_true(
    json_bool(health, "moonclaw_run_retry_recommended", default=false),
  )
  assert_false(json_bool(health, "production_ready", default=true))
  assert_true(
    json_string_array_items(health, "production_failed_checks").contains(
      "MoonClaw timed-out run is not orphaned",
    ),
  )
  assert_false(
    eb_checklist_item_ok(
      json_array_items(health, "production_checklist"),
      "moonclaw_run_not_orphaned",
      default=true,
    ),
  )
}

///|
async test "eb moonclaw missing-input fallback blocks production health" {
  let home = "/tmp/moondesk-eb-missing-input-health-wbtest/.moonclaw"
  let run_id = "run-eb-missing-input"
  let steps_root = @pathx.join(home, "jobs/runs/" + run_id + "/steps")
  @fsx.make_directory(steps_root, recursive=true, exists_ok=true)
  let step : Json = {
    "id": run_id + ":discover_official_pdfs",
    "run_id": run_id,
    "step_id": "discover_official_pdfs",
    "status": "Succeeded",
    "summary": "Best-effort continuation after missing input: Additional inputs are required to continue.",
    "output": {
      "status": "best_effort_missing_input",
      "step_id": "discover_official_pdfs",
    },
  }
  @fsx.write_to_file(
    @pathx.join(steps_root, "discover-official-pdfs.json"),
    step.stringify(indent=2) + "\n",
    create=0o644,
  )
  let health = eb_moonclaw_missing_input_step_health(home, run_id)
  assert_false(json_bool(health, "ok", default=true))
  assert_true(
    json_string_array_items(health, "failed_checks").contains(
      "MoonClaw step used missing-input fallback: discover_official_pdfs",
    ),
  )
}

///|
async test "eb moonclaw candidate discovery accepts official candidates" {
  let root = "/tmp/moondesk-eb-candidate-discovery-ready-wbtest"
  let book_root = @pathx.join(root, ".moontown/books/research-eb-candidates")
  let home = @pathx.join(root, ".moonclaw")
  let run_id = "run-eb-candidates-ready"
  let workspace = @pathx.join(root, "run-workspace")
  @fsx.make_directory(
    @pathx.join(workspace, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  let candidates : Json = {
    "status": "completed",
    "candidates": [
      {
        "url": "https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf",
        "title": "G三峡EB1 announcement",
      },
    ],
    "checked_domains": json_from_string_array(["sse.com.cn"]),
  }
  @fsx.write_to_file(
    @pathx.join(workspace, "outputs/official-pdf-candidates.json"),
    candidates.stringify(indent=2) + "\n",
    create=0o644,
  )
  let health = eb_moonclaw_candidate_discovery_health(book_root, home, run_id, {
    "workspace_dir": workspace,
  })
  assert_true(json_bool(health, "ok", default=false))
  assert_true(json_bool(health, "candidate_ready", default=false))
  assert_true(json_bool(health, "terminal_evidence_ready", default=false))
  assert_false(json_bool(health, "explicit_failure", default=true))
  assert_eq(json_int(health, "candidate_count", default=0), 1)
  assert_eq(json_int(health, "official_url_count", default=0), 1)
}

///|
async test "eb moonclaw candidate discovery records explicit failure" {
  let root = "/tmp/moondesk-eb-candidate-discovery-failed-wbtest"
  let book_root = @pathx.join(root, ".moontown/books/research-eb-candidates")
  let home = @pathx.join(root, ".moonclaw")
  let run_id = "run-eb-candidates-failed"
  let workspace = @pathx.join(root, "run-workspace")
  @fsx.make_directory(
    @pathx.join(workspace, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  let candidates : Json = {
    "status": "failed",
    "failure_reason": "web_fetch unavailable for official domains",
    "checked_domains": json_from_string_array(["sse.com.cn", "cninfo.com.cn"]),
    "standing_goal_decision": "failed",
  }
  @fsx.write_to_file(
    @pathx.join(workspace, "outputs/official-pdf-candidates.json"),
    candidates.stringify(indent=2) + "\n",
    create=0o644,
  )
  let health = eb_moonclaw_candidate_discovery_health(book_root, home, run_id, {
    "workspace_dir": workspace,
  })
  assert_true(json_bool(health, "ok", default=false))
  assert_false(json_bool(health, "candidate_ready", default=true))
  assert_true(json_bool(health, "explicit_failure", default=false))
  assert_true(json_bool(health, "terminal_evidence_ready", default=false))
  assert_eq(json_int(health, "checked_domain_count", default=0), 2)
}

///|
async test "eb reconciliation preserves candidate artifact before final output" {
  let root = "/tmp/moondesk-eb-candidate-reconcile-partial-wbtest"
  let book_id = "research-eb-candidate-reconcile-partial"
  let run_id = "run-eb-candidate-reconcile-partial"
  let home = @pathx.join(root, ".moonclaw")
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let run_workspace = @pathx.join(root, "run-workspace")
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(town_standing_goals_path(root), "[]\n", create=0o644)
  ignore(create_pdf_watch_book_dirs(book_root))
  let target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB candidate reconcile partial",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate candidate artifacts survive partial MoonClaw reconciliation.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB candidate reconcile partial",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate candidate artifacts survive partial MoonClaw reconciliation.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        skill_pack=default_skill_pack_for_pattern(
          "exchangeable-bond-evidence-watch",
        ),
        eb_target_bonds=[target],
      ),
      method_body=default_eb_analysis_method("EB candidate reconcile partial"),
      websites=eb_default_source_websites(),
      eb_target_fields=target,
      eb_target_bonds=[target],
    ),
  )
  let import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": true,
    "status": "run_confirmed",
    "proposal_id": "proposal-eb-candidate-partial",
    "run_id": run_id,
    "home": home,
    "exit_code": 0,
    "stderr": "",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    import_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(home, "jobs/runs/" + run_id),
    recursive=true,
    exists_ok=true,
  )
  let run_meta : Json = {
    "id": run_id,
    "status": "Succeeded",
    "workspace_dir": run_workspace,
  }
  @fsx.write_to_file(
    @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    run_meta.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(run_workspace, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  let candidates : Json = {
    "kind": "eb-official-pdf-candidates",
    "status": "completed",
    "run_id": run_id,
    "candidates": [
      {
        "url": "https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf",
        "title": "G三峡EB1 official candidate",
      },
    ],
    "checked_domains": json_from_string_array(["sse.com.cn"]),
    "standing_goal_decision": "update",
  }
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/official-pdf-candidates.json"),
    candidates.stringify(indent=2) + "\n",
    create=0o644,
  )
  let reconciled = reconcile_eb_moonclaw_run(
    root~,
    book_root~,
    book_id~,
    requested_run_id="",
  )
  assert_false(json_bool(reconciled, "ok", default=true))
  assert_eq(
    json_string(reconciled, "status", default=""),
    "waiting_for_valid_live_result",
  )
  assert_eq(
    json_string(reconciled, "candidate_artifact_path", default=""),
    eb_pdf_candidates_relative_path(run_id),
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, eb_pdf_candidates_relative_path(run_id))),
  )
  let health = json_object_field_or_empty(reconciled, "run_health")
  assert_true(
    json_bool(
      health,
      "moonclaw_candidate_discovery_terminal_ready",
      default=false,
    ),
  )
  assert_true(
    eb_checklist_item_ok(
      json_array_items(health, "production_checklist"),
      "moonclaw_pdf_candidates",
    ),
  )
  assert_false(json_bool(health, "production_ready", default=true))
}

///|
async test "eb run health recovers orphaned run after failed retry overwrote import receipt" {
  let root = "/tmp/moondesk-eb-historical-retry-recovery-wbtest"
  let book_id = "research-eb-historical-retry-recovery-eb-watch"
  let run_id = "run-eb-historical-retry-recovery"
  let home = @pathx.join(root, ".moonclaw")
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(town_standing_goals_path(root), "[]\n", create=0o644)
  ignore(create_pdf_watch_book_dirs(book_root))
  let target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB historical retry recovery",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate recovery from failed retry import state.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB historical retry recovery",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate recovery from failed retry import state.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        eb_target_bonds=[target],
      ),
      method_body=default_eb_analysis_method("EB historical retry recovery"),
      websites=eb_default_source_websites(),
      eb_target_fields=target,
      eb_target_bonds=[target],
    ),
  )
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB historical retry recovery",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate recovery from failed retry import state.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id="exchangeable-bond-evidence-watch",
      goal~,
    ),
  )
  ignore(refresh_eb_runtime_artifacts(root, book_root, book_id))
  let import_recorded_at = @async.now().to_string()
  let failed_import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": false,
    "status": "timed_out",
    "proposal_id": "",
    "run_id": "",
    "home": home,
    "timed_out": true,
    "recorded_at": import_recorded_at,
    "stderr": "MoonClaw proposal import timed out or failed after 1000ms: TimeoutError",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    failed_import_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(home, "jobs/runs/" + run_id),
    recursive=true,
    exists_ok=true,
  )
  let run_meta : Json = {
    "id": run_id,
    "job_id": "job-eb-historical-retry-recovery",
    "status": "Running",
    "workspace_dir": @pathx.join(book_root, "moonclaw-jobs/" + run_id),
  }
  @fsx.write_to_file(
    @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    run_meta.stringify(indent=2) + "\n",
    create=0o644,
  )
  let run_receipt : Json = {
    "kind": "moonclaw-confirmed-run-receipt",
    "book_id": book_id,
    "run_id": run_id,
    "ok": false,
    "status": "timed_out",
    "timed_out": true,
    "orphaned_after_timeout": true,
    "retry_recommended": true,
    "timeout_ms": 120000,
    "exit_code": -1,
    "home": home,
    "meta_path": @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    "meta": run_meta,
    "stderr": "MoonClaw confirmed run timed out or failed after 120000ms: TimeoutError",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    run_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  let previous_proof : Json = {
    "kind": "eb-production-proof",
    "book_id": book_id,
    "ok": false,
    "status": "not_proven_moonclaw_run_orphaned_after_timeout",
    "proof_level": "not-proven",
    "run_id": "",
    "standing_goal_sync": {
      "run_health": {
        "kind": "eb-durable-run-health",
        "book_id": book_id,
        "status": "moonclaw_run_orphaned_after_timeout",
        "moonclaw_import_status": "run_confirmed",
        "moonclaw_import_proposal_id": "proposal-eb-historical-retry-recovery",
        "moonclaw_import_run_id": run_id,
        "moonclaw_confirmed_run_home": home,
        "moonclaw_import_stderr": "",
        "recorded_at": import_recorded_at,
      },
    },
    "run_health": {
      "kind": "eb-durable-run-health",
      "book_id": book_id,
      "status": "moonclaw_import_timed_out",
      "moonclaw_import_run_id": "",
    },
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
    previous_proof.stringify(indent=2) + "\n",
    create=0o644,
  )
  let health = eb_durable_run_health(root, book_root, book_id)
  assert_eq(
    json_string(health, "status", default=""),
    "moonclaw_run_orphaned_after_timeout",
  )
  assert_true(
    json_bool(health, "moonclaw_import_receipt_recovered", default=false),
  )
  assert_eq(
    json_string(health, "moonclaw_import_recovery_source", default=""),
    "eb-production-proof.standing_goal_sync.run_health",
  )
  assert_true(json_bool(health, "moonclaw_import_receipt_ready", default=false))
  assert_eq(json_string(health, "moonclaw_import_run_id", default=""), run_id)
  assert_true(json_bool(health, "moonclaw_confirmed_run_ready", default=false))
  assert_true(
    json_bool(health, "moonclaw_run_orphaned_after_timeout", default=false),
  )
  assert_true(
    json_bool(health, "moonclaw_run_retry_recommended", default=false),
  )
  let proof = run_eb_production_proof(
    root~,
    book_root~,
    book_id~,
    moonclaw_root=@pathx.join(root, "empty-moonclaw"),
    home~,
    launch_if_missing=false,
    execute_moonclaw=false,
    force_execute=false,
    timeout_ms=1,
  )
  assert_eq(json_string(proof, "run_id", default=""), run_id)
  assert_true(
    json_bool(proof, "moonclaw_import_receipt_recovered", default=false),
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(proof, "run_health"),
      "status",
      default="",
    ),
    "moonclaw_run_orphaned_after_timeout",
  )
}

///|
async test "eb production proof relaunches orphaned import during normal execution and preserves on failure" {
  let root = "/tmp/moondesk-eb-orphaned-retry-preserve-wbtest"
  let book_id = "research-eb-orphaned-retry-preserve-eb-watch"
  let run_id = "run-eb-orphaned-retry-preserve"
  let home = @pathx.join(root, ".moonclaw")
  let moonclaw_root = @pathx.join(root, "empty-moonclaw")
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(moonclaw_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(town_standing_goals_path(root), "[]\n", create=0o644)
  ignore(create_pdf_watch_book_dirs(book_root))
  let target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB orphaned retry preserve",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate failed relaunch preserves prior orphaned run evidence.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB orphaned retry preserve",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate failed relaunch preserves prior orphaned run evidence.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        eb_target_bonds=[target],
      ),
      method_body=default_eb_analysis_method("EB orphaned retry preserve"),
      websites=eb_default_source_websites(),
      eb_target_fields=target,
      eb_target_bonds=[target],
    ),
  )
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB orphaned retry preserve",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate failed relaunch preserves prior orphaned run evidence.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id="exchangeable-bond-evidence-watch",
      goal~,
    ),
  )
  ignore(refresh_eb_runtime_artifacts(root, book_root, book_id))
  let import_recorded_at = @async.now().to_string()
  let import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": true,
    "status": "run_confirmed",
    "proposal_id": "proposal-eb-orphaned-retry-preserve",
    "run_id": run_id,
    "home": home,
    "exit_code": 0,
    "recorded_at": import_recorded_at,
    "stderr": "",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    import_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(home, "jobs/runs/" + run_id),
    recursive=true,
    exists_ok=true,
  )
  let run_meta : Json = {
    "id": run_id,
    "job_id": "job-eb-orphaned-retry-preserve",
    "status": "Running",
    "workspace_dir": @pathx.join(book_root, "moonclaw-jobs/" + run_id),
  }
  @fsx.write_to_file(
    @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    run_meta.stringify(indent=2) + "\n",
    create=0o644,
  )
  let run_receipt : Json = {
    "kind": "moonclaw-confirmed-run-receipt",
    "book_id": book_id,
    "run_id": run_id,
    "ok": false,
    "status": "timed_out",
    "timed_out": true,
    "orphaned_after_timeout": true,
    "retry_recommended": true,
    "timeout_ms": 1000,
    "exit_code": -1,
    "home": home,
    "meta_path": @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    "meta": run_meta,
    "stderr": "MoonClaw confirmed run timed out or failed after 1000ms: TimeoutError",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    run_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  let proof = run_eb_production_proof(
    root~,
    book_root~,
    book_id~,
    moonclaw_root~,
    home~,
    launch_if_missing=true,
    execute_moonclaw=true,
    force_execute=false,
    timeout_ms=1,
  )
  assert_false(json_bool(proof, "ok", default=true))
  assert_eq(
    json_string(proof, "import_step", default=""),
    "relaunch_failed_preserved_orphaned_import",
  )
  assert_eq(json_string(proof, "run_id", default=""), run_id)
  assert_true(json_bool(proof, "orphaned_relaunch_attempted", default=false))
  assert_true(json_bool(proof, "orphaned_relaunch_failed", default=false))
  assert_eq(
    json_string(proof, "run_step", default=""),
    "orphaned_relaunch_failed_execution_skipped",
  )
  assert_true(
    json_bool(proof, "moonclaw_retry_import_receipt_ready", default=false),
  )
  assert_false(
    json_bool(
      json_object_field_or_empty(proof, "retry_import_receipt"),
      "ok",
      default=true,
    ),
  )
  let persisted_import = read_json_file_or_object(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
  )
  assert_eq(json_string(persisted_import, "run_id", default=""), run_id)
  assert_true(
    @fs.exists(
      @pathx.join(book_root, eb_moonclaw_retry_import_receipt_relative_path()),
    ),
  )
  let health = eb_durable_run_health(root, book_root, book_id)
  assert_eq(
    json_string(health, "status", default=""),
    "moonclaw_run_orphaned_after_timeout",
  )
  assert_true(
    json_bool(health, "moonclaw_retry_import_receipt_ready", default=false),
  )
  assert_eq(json_string(health, "moonclaw_import_run_id", default=""), run_id)
  assert_true(
    json_bool(health, "moonclaw_run_orphaned_after_timeout", default=false),
  )
}

///|
async test "all pdf watch standing goals repair from book receipts and skip stale drafts" {
  let root = "/tmp/moondesk-all-pdf-watch-goal-sync-wbtest"
  let books_root = @pathx.join(root, ".moontown/books")
  let plain_book_id = "research-plain-not-watch"
  let generic_book_id = "research-policy-sync-pdf-watch"
  let eb_book_id = "research-eb-sync-eb-watch"
  let stale_book_id = "legacy-pdf-watch-draft"
  let generic_book_root = @pathx.join(books_root, generic_book_id)
  let eb_book_root = @pathx.join(books_root, eb_book_id)
  let plain_book_root = @pathx.join(books_root, plain_book_id)
  let stale_book_root = @pathx.join(books_root, stale_book_id)
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    town_standing_goals_path(root),
    Json::array([
      {
        "id": "watch-opc-news",
        "title": "Track OPC news",
        "target_book_id": "research-opc",
        "cadence_ticks": 60,
        "enabled": true,
      },
    ]).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  ignore(create_pdf_watch_book_dirs(generic_book_root))
  let generic_goal = pdf_watch_standing_goal(
    book_id=generic_book_id,
    topic="Policy Sync",
    pattern_id="pdf-evidence-watch",
    purpose="Validate all-book generic PDF sync.",
    cadence=45,
    source_policy="web-first",
    daemon_tick=10,
  )
  ignore(
    write_pdf_watch_book_files(
      book_root=generic_book_root,
      book_id=generic_book_id,
      topic="Policy Sync",
      pattern_id="pdf-evidence-watch",
      purpose="Validate all-book generic PDF sync.",
      book_json=pdf_watch_book_json(
        book_id=generic_book_id,
        topic="Policy Sync",
        pattern_id="pdf-evidence-watch",
        purpose="Validate all-book generic PDF sync.",
        cadence=45,
        websites=["https://example.org/reports"],
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
      ),
      method_body=default_pdf_analysis_method("Policy Sync"),
      websites=["https://example.org/reports"],
    ),
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root=generic_book_root,
      book_id=generic_book_id,
      pattern_id="pdf-evidence-watch",
      goal=generic_goal,
    ),
  )
  ignore(create_pdf_watch_book_dirs(eb_book_root))
  let eb_goal = pdf_watch_standing_goal(
    book_id=eb_book_id,
    topic="EB Sync",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate all-book EB sync.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=20,
  )
  ignore(
    write_pdf_watch_book_files(
      book_root=eb_book_root,
      book_id=eb_book_id,
      topic="EB Sync",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate all-book EB sync.",
      book_json=pdf_watch_book_json(
        book_id=eb_book_id,
        topic="EB Sync",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate all-book EB sync.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
      ),
      method_body=default_eb_analysis_method("EB Sync"),
      websites=eb_default_source_websites(),
      eb_target_fields={
        "bond_full_name_or_short_name": "G三峡EB1",
        "bond_code": "132018",
        "issuer": "中国长江三峡集团有限公司",
        "underlying_listed_company": "长江电力",
        "exchange": "上交所",
      },
    ),
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root=eb_book_root,
      book_id=eb_book_id,
      pattern_id="exchangeable-bond-evidence-watch",
      goal=eb_goal,
    ),
  )
  @fsx.make_directory(plain_book_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(plain_book_root, "book.json"),
    (
      {
        "id": plain_book_id,
        "type": "research-book",
        "book_type": "research-book",
        "title": "Plain research book",
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.make_directory(stale_book_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(stale_book_root, "book.json"),
    (
      {
        "id": stale_book_id,
        "book_type": "pdf-evidence-watch",
        "title": "Legacy PDF draft",
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let repaired = sync_all_pdf_watch_standing_goals(root)
  assert_true(json_bool(repaired, "ok", default=false))
  assert_eq(json_string(repaired, "status", default=""), "synced_with_skips")
  assert_eq(json_int(repaired, "synced_count", default=0), 2)
  assert_eq(json_int(repaired, "already_synced_count", default=-1), 0)
  assert_eq(json_int(repaired, "skipped_count", default=0), 1)
  assert_eq(json_int(repaired, "failed_count", default=-1), 0)
  let skipped = json_array_items(repaired, "skipped_books")
  assert_eq(skipped.length(), 1)
  assert_eq(json_string(skipped[0], "book_id", default=""), stale_book_id)
  let goals = read_json_array_file(town_standing_goals_path(root))
  assert_eq(goals.length(), 3)
  assert_true(json_record_with_target_book_exists(goals, "research-opc"))
  assert_true(json_record_with_target_book_exists(goals, generic_book_id))
  assert_true(json_record_with_target_book_exists(goals, eb_book_id))
  assert_false(json_record_with_target_book_exists(goals, plain_book_id))
  assert_false(json_record_with_target_book_exists(goals, stale_book_id))
  let repaired_again = sync_all_pdf_watch_standing_goals(root)
  assert_true(json_bool(repaired_again, "ok", default=false))
  assert_eq(
    json_string(repaired_again, "status", default=""),
    "already_synced_with_skips",
  )
  assert_eq(json_int(repaired_again, "synced_count", default=-1), 0)
  assert_eq(json_int(repaired_again, "already_synced_count", default=0), 2)
  assert_eq(json_int(repaired_again, "skipped_count", default=0), 1)
}

///|
async test "eb output target match rejects sample workbook for production target" {
  let root = "/tmp/moondesk-eb-output-target-mismatch-wbtest"
  let book_id = "research-eb-output-target-mismatch"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let output_relative = "book/outputs/EB追踪_132001_示例EB_20260601.xlsx"
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB output target mismatch",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate output filename target matching.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method("EB output target mismatch"),
      websites=eb_default_source_websites(),
      eb_target_fields={
        "bond_full_name_or_short_name": "G三峡EB1",
        "bond_code": "132018",
        "issuer": "中国长江三峡集团有限公司",
        "underlying_listed_company": "长江电力",
        "exchange": "上交所",
      },
    ),
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_output_manifest_relative_path(output_relative)),
    eb_tracking_output_manifest_json(
      book_id~,
      run_id="run-output-target-mismatch",
      bond_code="132001",
      bond_short_name="示例EB",
      as_of="20260601",
      output_relative~,
      source_screen_relative=eb_source_screen_relative_path(
        "run-output-target-mismatch",
      ),
      pdf_candidates_relative=eb_pdf_candidates_relative_path(
        "run-output-target-mismatch",
      ),
      accepted_by_bookkeeper=true,
      sample_run=false,
      xlsx_sha256="placeholder",
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let match_result = eb_output_target_match(book_root, output_relative)
  assert_false(json_bool(match_result, "ok", default=true))
  assert_eq(json_string(match_result, "bond_code", default=""), "132001")
  assert_eq(json_int(match_result, "matching_target_count", default=1), 0)
  let failed_text = json_string_array_items(match_result, "failed_checks").join(
    "\n",
  )
  assert_true(
    failed_text.contains(
      "output filename uses a real non-sample 132XXX EB code",
    ),
  )
  assert_true(
    failed_text.contains(
      "accepted workbook code/name match at least one configured production EB target",
    ),
  )
}

///|
async test "eb moonclaw web tool contract rejects planner-only blocked output" {
  let book_root = "/tmp/moondesk-eb-web-tool-contract-wbtest/book"
  let book_id = "research-eb-web-tool-contract"
  let run_id = "run-eb-web-tools-blocked"
  let run_root = @pathx.join(book_root, "moonclaw-jobs/" + run_id)
  @fsx.make_directory(
    @pathx.join(run_root, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "moonclaw-packets"),
    recursive=true,
    exists_ok=true,
  )
  let packet_path = @pathx.join(
    book_root,
    eb_moonclaw_proposal_packet_relative_path(),
  )
  @fsx.write_to_file(
    packet_path,
    eb_moonclaw_proposal_packet_json(
      book_root,
      book_id,
      "EB Web Tool Contract",
      eb_default_source_websites(),
      target_fields={
        "bond_full_name_or_short_name": "G三峡EB1",
        "bond_code": "132018",
        "issuer": "中国长江三峡集团有限公司",
        "underlying_listed_company": "长江电力",
        "exchange": "上交所",
      },
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let blocked_output : Json = {
    "step_id": "discover_official_pdfs",
    "result_decision": "accepted",
    "content": "Blocked: no working web search or web fetch function was exposed.",
    "metadata": {
      "role_runtime_contract": [
        {
          "runtime_mode": "PlannerOnly",
          "tool_access": "Limited",
          "allow_execution_tools": false,
        },
      ],
    },
  }
  @fsx.write_to_file(
    @pathx.join(run_root, "outputs/step-discover-official-pdfs.json"),
    blocked_output.stringify(indent=2) + "\n",
    create=0o644,
  )
  let health = eb_moonclaw_web_tool_contract_health(
    book_root,
    run_id,
    { "workspace_dir": run_root },
    packet_path,
  )
  assert_false(json_bool(health, "ok", default=true))
  assert_true(json_bool(health, "packet_requires_web_tools", default=false))
  let failed = json_string_array_items(health, "failed_checks")
  assert_true(
    failed.contains(
      "MoonClaw run output reports web_search or web_fetch unavailable",
    ),
  )
  let evidence = json_string_array_items(health, "evidence_paths")
  assert_true(evidence.length() > 0)
  assert_true(evidence[0].contains("step-discover-official-pdfs.json"))
}

///|
async test "eb runtime refresh repairs stale moonclaw packet for existing book" {
  let root = "/tmp/moondesk-eb-runtime-refresh-wbtest"
  let book_id = "research-eb-runtime-refresh-eb-watch"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(town_standing_goals_path(root), "[]\n", create=0o644)
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB runtime refresh",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate runtime refresh.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB runtime refresh",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate runtime refresh.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        eb_target_bonds=[
          {
            "bond_full_name_or_short_name": "G三峡EB1",
            "bond_code": "132018",
            "issuer": "中国长江三峡集团有限公司",
            "underlying_listed_company": "长江电力",
            "exchange": "上交所",
          },
        ],
      ),
      method_body=default_eb_analysis_method("EB runtime refresh"),
      websites=eb_default_source_websites(),
      eb_target_fields={
        "bond_full_name_or_short_name": "G三峡EB1",
        "bond_code": "132018",
        "issuer": "中国长江三峡集团有限公司",
        "underlying_listed_company": "长江电力",
        "exchange": "上交所",
      },
      eb_target_bonds=[
        {
          "bond_full_name_or_short_name": "G三峡EB1",
          "bond_code": "132018",
          "issuer": "中国长江三峡集团有限公司",
          "underlying_listed_company": "长江电力",
          "exchange": "上交所",
        },
      ],
    ),
  )
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB runtime refresh",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate runtime refresh.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id="exchangeable-bond-evidence-watch",
      goal~,
    ),
  )
  let prompt_path = @pathx.join(book_root, eb_operator_prompt_relative_path())
  let prompt_contract_path = @pathx.join(
    book_root,
    eb_prompt_contract_receipt_relative_path(),
  )
  let base_type_selection_path = @pathx.join(
    book_root,
    pdf_watch_base_type_selection_relative_path(),
  )
  let expected_output_contract_path = @pathx.join(
    book_root,
    eb_expected_output_contract_relative_path(),
  )
  assert_true(@fs.exists(prompt_path))
  assert_true(@fs.exists(prompt_contract_path))
  assert_true(@fs.exists(base_type_selection_path))
  assert_true(@fs.exists(expected_output_contract_path))
  assert_true(
    json_bool(
      read_json_file_or_object(base_type_selection_path),
      "verified",
      default=false,
    ),
  )
  let initial_prompt_contract = read_json_file_or_object(prompt_contract_path)
  assert_true(json_bool(initial_prompt_contract, "verified", default=false))
  assert_true(
    eb_expected_output_contract_valid(
      read_json_file_or_object(expected_output_contract_path),
    ),
  )
  @fs.remove(prompt_path) catch {
    _ => ()
  }
  @fs.remove(prompt_contract_path) catch {
    _ => ()
  }
  @fs.remove(base_type_selection_path) catch {
    _ => ()
  }
  @fs.remove(expected_output_contract_path) catch {
    _ => ()
  }
  let missing_prompt_contract = book_contract_verification(
    "", book_root, book_id, "exchangeable-bond-evidence-watch",
  )
  assert_false(json_bool(missing_prompt_contract, "verified", default=true))
  assert_true(
    json_string_array_items(missing_prompt_contract, "failed_checks")
    .join("\n")
    .contains("EB operator prompt artifact exists"),
  )
  assert_false(
    json_record_with_target_book_exists(
      read_json_array_file(town_standing_goals_path(root)),
      book_id,
    ),
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "moonclaw.jobs.json"),
    "{\"jobs\":{\"profiles\":{\"eb_pdf_evidence_watch\":{\"role\":\"controller\"}}}}\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_proposal_packet_relative_path()),
    "{\"profile\":\"eb_pdf_evidence_watch\",\"metadata\":{\"step_metadata\":{\"web_search\":true}}}\n",
    create=0o644,
  )
  let stale = eb_moonclaw_web_tool_contract_health(
    book_root,
    "",
    Json::object({}),
    @pathx.join(book_root, eb_moonclaw_proposal_packet_relative_path()),
  )
  assert_false(json_bool(stale, "packet_requires_web_tools", default=true))
  let refresh = refresh_eb_runtime_artifacts(root, book_root, book_id)
  assert_true(json_bool(refresh, "ok", default=false))
  assert_true(json_bool(refresh, "changed", default=false))
  let changed = json_string_array_items(refresh, "changed_paths")
  assert_true(changed.contains("moonclaw.jobs.json"))
  assert_true(changed.contains(eb_moonclaw_proposal_packet_relative_path()))
  assert_true(changed.contains(pdf_watch_base_type_selection_relative_path()))
  assert_true(changed.contains(eb_operator_prompt_relative_path()))
  assert_true(changed.contains(eb_prompt_contract_receipt_relative_path()))
  assert_true(changed.contains(eb_expected_output_contract_relative_path()))
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "raw/bootstrap/eb_discover_pdf_candidates.py"),
    ),
  )
  let repaired_base_type_selection = read_json_file_or_object(
    base_type_selection_path,
  )
  assert_true(
    json_bool(repaired_base_type_selection, "verified", default=false),
  )
  assert_true(
    pdf_watch_base_type_selection_valid_for_book(
      read_json_file_or_object(@pathx.join(book_root, "book.json")),
      repaired_base_type_selection,
    ),
  )
  let repaired_prompt_contract = read_json_file_or_object(prompt_contract_path)
  assert_true(json_bool(repaired_prompt_contract, "verified", default=false))
  assert_eq(
    json_string(repaired_prompt_contract, "prompt_path", default=""),
    eb_operator_prompt_relative_path(),
  )
  let repaired_expected_output_contract = read_json_file_or_object(
    expected_output_contract_path,
  )
  assert_true(
    eb_expected_output_contract_valid(repaired_expected_output_contract),
  )
  assert_eq(
    json_string(
      repaired_expected_output_contract,
      "output_contract",
      default="",
    ),
    "moondesk.exchangeable_bond_tracking.xlsx.v1",
  )
  assert_eq(
    json_int(repaired_prompt_contract, "lifecycle_stage_count", default=0),
    6,
  )
  assert_true(
    json_bool(
      book_contract_verification(
        "", book_root, book_id, "exchangeable-bond-evidence-watch",
      ),
      "verified",
      default=false,
    ),
  )
  let repaired = eb_moonclaw_web_tool_contract_health(
    book_root,
    "",
    Json::object({}),
    @pathx.join(book_root, eb_moonclaw_proposal_packet_relative_path()),
  )
  assert_true(json_bool(repaired, "ok", default=false))
  assert_true(json_bool(repaired, "packet_requires_web_tools", default=false))
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "raw/analysis-runs/eb-runtime-refresh.json"),
    ),
  )
  let stale_import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": true,
    "status": "run_confirmed",
    "proposal_id": "stale-proposal",
    "run_id": "run-stale",
    "home": @pathx.join(root, ".moonclaw"),
    "recorded_at": "1",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    stale_import_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  let proof = run_eb_production_proof(
    root~,
    book_root~,
    book_id~,
    moonclaw_root="../moonclaw",
    home=@pathx.join(root, ".moonclaw"),
    launch_if_missing=false,
    execute_moonclaw=false,
    force_execute=false,
    timeout_ms=1000,
  )
  assert_eq(
    json_string(proof, "import_step", default=""),
    "runtime_refresh_newer_than_import",
  )
  assert_eq(
    json_string(proof, "status", default=""),
    "not_proven_refreshed_runtime_requires_new_moonclaw_import",
  )
  assert_eq(json_string(proof, "run_id", default=""), "")
  let proof_sync = json_object_field_or_empty(proof, "standing_goal_sync")
  assert_true(json_bool(proof_sync, "ok", default=false))
  assert_eq(json_string(proof_sync, "status", default=""), "synced")
  assert_true(
    json_bool(proof_sync, "global_standing_goal_ready", default=false),
  )
  assert_true(
    json_bool(
      json_object_field_or_empty(proof, "run_health"),
      "global_standing_goal_ready",
      default=false,
    ),
  )
}

///|
async test "eb moonclaw reconciliation promotes valid live run into production health" {
  let root = "/tmp/moondesk-eb-live-reconcile-wbtest"
  let book_id = "research-eb-live-reconcile-eb-watch"
  let run_id = "run-eb-live-reconcile"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let home = @pathx.join(root, ".moonclaw")
  let run_workspace = @pathx.join(book_root, "moonclaw-jobs/" + run_id)
  let output_relative = "book/outputs/EB追踪_132018_G三峡EB1_20260601.xlsx"
  let target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  ignore(create_pdf_watch_book_dirs(book_root))
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB live reconcile",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate live MoonClaw result reconciliation.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    town_standing_goals_path(root),
    Json::array([goal]).stringify(indent=2) + "\n",
    create=0o644,
  )
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB live reconcile",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate live MoonClaw result reconciliation.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB live reconcile",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate live MoonClaw result reconciliation.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        eb_target_bonds=[target],
      ),
      method_body=default_eb_analysis_method("EB live reconcile"),
      websites=eb_default_source_websites(),
      eb_target_fields=target,
      eb_target_bonds=[target],
    ),
  )
  @fsx.write_to_file(
    town_moonbooks_path(root),
    Json::array([
      pdf_watch_catalog_entry(
        book_id~,
        topic="EB live reconcile",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate live MoonClaw result reconciliation.",
        book_root~,
      ),
    ]).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.make_directory(
    town_moondesk_requests_root(root),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(town_moondesk_requests_root(root), book_id + ".json"),
    pdf_watch_handoff_record(
      book_id~,
      topic="EB live reconcile",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate live MoonClaw result reconciliation.",
      book_root~,
      goal~,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id="exchangeable-bond-evidence-watch",
      goal~,
    ),
  )
  ignore(
    write_moontown_book_template_publish(
      root~,
      book_root~,
      book_id~,
      topic="EB live reconcile",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate live MoonClaw result reconciliation.",
      cadence=30,
      websites=eb_default_source_websites(),
      method_body=default_eb_analysis_method("EB live reconcile"),
      skill_pack=default_skill_pack_for_pattern(
        "exchangeable-bond-evidence-watch",
      ),
      goal~,
    ),
  )
  let import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": true,
    "status": "run_confirmed",
    "proposal_id": "proposal-eb-live-reconcile",
    "run_id": run_id,
    "home": home,
    "exit_code": 0,
    "stderr": "tcc: error: invalid option -- '--home'",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    import_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(home, "jobs/runs/" + run_id),
    recursive=true,
    exists_ok=true,
  )
  let run_meta : Json = {
    "id": run_id,
    "status": "Succeeded",
    "workspace_dir": run_workspace,
  }
  @fsx.write_to_file(
    @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    run_meta.stringify(indent=2) + "\n",
    create=0o644,
  )
  let run_receipt : Json = {
    "kind": "moonclaw-confirmed-run-receipt",
    "book_id": book_id,
    "run_id": run_id,
    "ok": true,
    "status": "succeeded",
    "timed_out": false,
    "timeout_ms": 120000,
    "exit_code": 0,
    "moonclaw_root": "../moonclaw",
    "home": home,
    "cwd": book_root,
    "meta_path": @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    "meta": run_meta,
    "command": "moon -C ../moonclaw run cmd/main -- proposal run \{run_id} --home \{home} --cwd \{book_root}",
    "stdout": "",
    "stderr": "",
    "recorded_at": "2026-06-02T00:00:00Z",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    run_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(run_workspace, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(run_workspace, "raw/pdfs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(run_workspace, "raw/extracted"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(run_workspace, "raw/pdfs/" + run_id + "-official-evidence.pdf"),
    "%PDF-1.4\n% live official EB evidence fixture\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(
      run_workspace,
      "raw/extracted/" + run_id + "-official-evidence.txt",
    ),
    "live extracted EB evidence fixture\n",
    create=0o644,
  )
  let candidate_artifact : Json = {
    "kind": "eb-official-pdf-candidates",
    "status": "completed",
    "run_id": run_id,
    "candidates": [
      {
        "url": "https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf",
        "title": "G三峡EB1 official exchangeable bond announcement",
        "platform": "上海证券交易所",
        "relevance": "target bond disclosure",
      },
    ],
    "checked_domains": json_from_string_array(["sse.com.cn"]),
    "standing_goal_decision": "update",
  }
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/official-pdf-candidates.json"),
    candidate_artifact.stringify(indent=2) + "\n",
    create=0o644,
  )
  write_eb_populated_workbook_fixture(
    @pathx.join(book_root, output_relative),
    bond_code="132018",
    bond_short_name="G三峡EB1",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_output_manifest_relative_path(output_relative)),
    eb_tracking_output_manifest_json(
      book_id~,
      run_id~,
      bond_code="132018",
      bond_short_name="G三峡EB1",
      as_of="20260601",
      output_relative~,
      source_screen_relative=eb_source_screen_relative_path(run_id),
      pdf_candidates_relative=eb_pdf_candidates_relative_path(run_id),
      accepted_by_bookkeeper=true,
      sample_run=false,
      xlsx_sha256=eb_file_sha256(@pathx.join(book_root, output_relative)),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(
      book_root,
      eb_output_workbook_validation_relative_path(output_relative),
    ),
    eb_tracking_workbook_validation_json(
      book_id~,
      run_id~,
      output_relative~,
      sample_run=false,
      xlsx_sha256=eb_file_sha256(@pathx.join(book_root, output_relative)),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/official-source-screen.json"),
    eb_live_official_source_screen_json(
      book_id~,
      run_id~,
      bond_code="132018",
      bond_short_name="G三峡EB1",
      as_of="20260601",
      official_url="https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf",
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let run_result : Json = {
    "step_id": "package_result",
    "result_decision": "accepted",
    "requires_review": false,
    "notify_town": true,
    "content": "Generated workbook and sidecars for the accepted live run.\n\nstanding_goal_decision: update\nbook_changed: yes",
    "metadata": {
      "job_id": "job.proposal.eb-live-reconcile",
      "run_id": run_id,
      "step_id": "package_result",
    },
  }
  @fsx.write_to_file(
    @pathx.join(run_workspace, "result.json"),
    run_result.stringify(indent=2) + "\n",
    create=0o644,
  )
  let reconciled = reconcile_eb_moonclaw_run(
    root~,
    book_root~,
    book_id~,
    requested_run_id="",
  )
  assert_true(eb_xlsx_data_rows_valid(@pathx.join(book_root, output_relative)))
  assert_true(
    eb_xlsx_official_hyperlinks_valid(@pathx.join(book_root, output_relative)),
  )
  assert_true(json_bool(reconciled, "ok", default=false))
  assert_eq(
    json_string(reconciled, "status", default=""),
    "accepted_live_result",
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, eb_reconciliation_receipt_relative_path(run_id)),
    ),
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, eb_source_screen_relative_path(run_id))),
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, eb_pdf_candidates_relative_path(run_id))),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "raw/pdfs/" + run_id + "-official-evidence.pdf"),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root,
        "raw/extracted/" + run_id + "-official-evidence.txt",
      ),
    ),
  )
  assert_true(
    @fs.exists(@pathx.join(root, ".moontown/book-results/" + run_id + ".json")),
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        root,
        ".moontown/watchers/" + json_string(goal, "id", default="") + ".jsonl",
      ),
    ),
  )
  let health = json_object_field_or_empty(reconciled, "run_health")
  assert_true(json_bool(health, "durable_ready", default=false))
  assert_true(json_bool(health, "production_ready", default=false))
  assert_true(json_bool(health, "base_type_selection_ready", default=false))
  assert_eq(json_string(health, "base_type", default=""), "research-book")
  assert_eq(
    json_string(health, "base_type_handoff_target", default=""),
    "Moontown",
  )
  assert_eq(
    json_string(health, "base_type_selection_path", default=""),
    pdf_watch_base_type_selection_relative_path(),
  )
  assert_true(
    json_bool(health, "moontown_template_publish_receipt_ready", default=false),
  )
  assert_eq(
    json_string(health, "moontown_template_publish_receipt_path", default=""),
    pdf_watch_moontown_publish_receipt_relative_path(),
  )
  assert_true(
    json_bool(health, "standing_goal_registration_ready", default=false),
  )
  assert_true(json_bool(health, "real_moonclaw_result_ready", default=false))
  assert_true(
    json_bool(health, "source_screen_production_ready", default=false),
  )
  assert_true(
    json_bool(
      health,
      "moonclaw_candidate_discovery_terminal_ready",
      default=false,
    ),
  )
  assert_false(
    json_bool(
      health,
      "moonclaw_candidate_discovery_explicit_failure",
      default=true,
    ),
  )
  assert_true(
    json_bool(health, "moonclaw_confirmed_run_succeeded", default=false),
  )
  assert_true(json_bool(health, "targets_production_ready", default=false))
  assert_true(json_bool(health, "moonclaw_import_stderr_clean", default=false))
  assert_true(
    json_bool(health, "moonclaw_import_stderr_tolerated", default=false),
  )
  assert_true(json_bool(health, "moonclaw_run_receipt_ready", default=false))
  assert_true(json_bool(health, "moonclaw_run_receipt_ok", default=false))
  assert_true(json_bool(health, "moonclaw_run_stderr_clean", default=false))
  assert_true(
    json_bool(health, "moonclaw_execution_stderr_clean", default=false),
  )
  assert_eq(
    json_string(health, "moonclaw_run_receipt_status", default=""),
    "succeeded",
  )
  assert_eq(
    json_string(health, "moonclaw_run_receipt_path", default=""),
    eb_moonclaw_run_receipt_relative_path(run_id),
  )
  assert_true(json_bool(health, "workbook_validation_ready", default=false))
  assert_false(
    json_bool(health, "workbook_validation_sample_run", default=true),
  )
  assert_true(json_bool(health, "output_target_match_ready", default=false))
  let output_target_match = json_object_field_or_empty(
    health, "output_target_match",
  )
  assert_eq(json_string(output_target_match, "bond_code", default=""), "132018")
  assert_eq(
    json_string(output_target_match, "bond_short_name", default=""),
    "G三峡EB1",
  )
  assert_eq(
    json_int(output_target_match, "matching_target_count", default=0),
    1,
  )
  assert_eq(json_string(health, "run_id", default=""), run_id)
  assert_eq(json_string(health, "output_path", default=""), output_relative)
  assert_eq(
    json_string(health, "source_screen_path", default=""),
    eb_source_screen_relative_path(run_id),
  )
  let production_checklist = json_array_items(health, "production_checklist")
  assert_true(production_checklist.length() >= 10)
  assert_true(eb_checklist_item_ok(production_checklist, "book_contract"))
  assert_true(eb_checklist_item_ok(production_checklist, "target_config"))
  assert_true(eb_checklist_item_ok(production_checklist, "standing_goal"))
  assert_true(eb_checklist_item_ok(production_checklist, "moonclaw_import"))
  assert_true(eb_checklist_item_ok(production_checklist, "moonclaw_run"))
  assert_true(
    eb_checklist_item_ok(production_checklist, "moonclaw_execution_stderr"),
  )
  assert_true(
    eb_checklist_item_ok(production_checklist, "moonclaw_pdf_candidates"),
  )
  assert_true(eb_checklist_item_ok(production_checklist, "live_result"))
  assert_true(eb_checklist_item_ok(production_checklist, "watcher_update"))
  assert_true(eb_checklist_item_ok(production_checklist, "book_result"))
  assert_true(eb_checklist_item_ok(production_checklist, "accepted_workbook"))
  assert_true(eb_checklist_item_ok(production_checklist, "workbook_validation"))
  assert_true(eb_checklist_item_ok(production_checklist, "appendix_notes"))
  assert_true(eb_checklist_item_ok(production_checklist, "quality_proof"))
  assert_true(eb_checklist_item_ok(production_checklist, "lifecycle_proof"))
  assert_true(eb_checklist_item_ok(production_checklist, "not_sample"))
  assert_true(eb_checklist_item_ok(production_checklist, "workbook_data_rows"))
  assert_true(eb_checklist_item_ok(production_checklist, "output_target_match"))
  assert_true(
    eb_checklist_item_ok(production_checklist, "official_source_screen"),
  )
  assert_true(eb_checklist_item_ok(production_checklist, "output_validation"))
  let proof = run_eb_production_proof(
    root~,
    book_root~,
    book_id~,
    moonclaw_root="../moonclaw",
    home~,
    launch_if_missing=false,
    execute_moonclaw=false,
    force_execute=false,
    timeout_ms=1000,
  )
  assert_true(json_bool(proof, "ok", default=false))
  assert_eq(json_string(proof, "status", default=""), "production_ready")
  assert_eq(json_string(proof, "proof_level", default=""), "live-production")
  assert_eq(json_string(proof, "run_id", default=""), run_id)
  assert_eq(
    json_string(proof, "run_step", default=""),
    "reused_successful_run_receipt",
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
    ),
  )
  let proven_health = eb_durable_run_health(root, book_root, book_id)
  assert_true(
    json_bool(proven_health, "production_proof_receipt_ready", default=false),
  )
  assert_eq(
    json_string(proven_health, "production_proof_status", default=""),
    "production_ready",
  )
  assert_eq(
    json_string(proven_health, "production_proof_level", default=""),
    "live-production",
  )
  assert_true(
    eb_checklist_item_ok(
      json_array_items(proven_health, "production_checklist"),
      "production_proof_attempt",
    ),
  )
}
