///|
async fn run_eb_moonclaw_confirmed_run(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  run_id~ : String,
  moonclaw_root~ : String,
  home~ : String,
  timeout_ms~ : Int,
) -> Json {
  @fsx.make_directory(
    @pathx.dirname(
      @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    ).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  let args = [
    "-C", moonclaw_root, "run", "cmd/main", "--", "proposal", "run", run_id, "--home",
    home, "--cwd", book_root,
  ]
  let mut exit_code = -1
  let mut stdout = ""
  let mut stderr = ""
  let mut timed_out = false
  let collected = Some(
    @async.with_timeout(timeout_ms, () => {
      @process.collect_output("moon", args, cwd=moonclaw_root)
    }),
  ) catch {
    error => {
      timed_out = true
      stderr = "MoonClaw confirmed run timed out or failed after \{timeout_ms}ms: \{error}"
      None
    }
  }
  match collected {
    Some((code, out, err)) => {
      exit_code = code
      stdout = out.text()
      stderr = err.text()
    }
    None => ()
  }
  let meta_path = @pathx.join(home, "jobs/runs/" + run_id + "/meta.json")
  let meta = if @fs.exists(meta_path) {
    read_json_file_or_object(meta_path)
  } else {
    Json::object({})
  }
  let status = json_string(meta, "status", default="")
  let orphaned_after_timeout = timed_out && status == "Running"
  let ok = exit_code == 0 && !timed_out && status == "Succeeded"
  let receipt : Json = {
    "kind": "moonclaw-confirmed-run-receipt",
    "book_id": book_id,
    "run_id": run_id,
    "ok": ok,
    "status": if ok {
      "succeeded"
    } else if timed_out {
      "timed_out"
    } else if status != "" {
      status
    } else {
      "failed"
    },
    "timed_out": timed_out,
    "orphaned_after_timeout": orphaned_after_timeout,
    "retry_recommended": orphaned_after_timeout,
    "recovery_action": if orphaned_after_timeout {
      "fresh_import_and_run"
    } else {
      ""
    },
    "timeout_ms": timeout_ms,
    "exit_code": exit_code,
    "moonclaw_root": moonclaw_root,
    "home": home,
    "cwd": book_root,
    "meta_path": meta_path,
    "meta": meta,
    "command": "moon " + args.join(" "),
    "stdout": trim_for_record(stdout),
    "stderr": trim_for_record(stderr),
    "recorded_at": @async.now().to_string(),
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  ignore(root)
  receipt
}

///|
async fn reconcile_eb_moonclaw_run(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  requested_run_id~ : String,
) -> Json {
  let receipt_path = @pathx.join(
    book_root,
    eb_moonclaw_import_receipt_relative_path(),
  )
  let receipt = read_json_file_or_object(receipt_path)
  let receipt_run_id = json_string(receipt, "run_id", default="")
    .trim()
    .to_owned()
  let run_id = trimmed_payload_text(requested_run_id, default=receipt_run_id)
  let home = trimmed_payload_text(
    json_string(receipt, "home", default=""),
    default=@pathx.join(root, ".moonclaw"),
  )
  let meta_path = if run_id == "" {
    ""
  } else {
    @pathx.join(home, "jobs/runs/" + run_id + "/meta.json")
  }
  let meta = if meta_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(meta_path)
  }
  let local_run_root = if run_id == "" {
    ""
  } else {
    @pathx.join(book_root, "moonclaw-jobs/" + run_id)
  }
  let run_workspace = trimmed_payload_text(
    json_string(meta, "workspace_dir", default=""),
    default=local_run_root,
  )
  let result_source_path = eb_first_existing_path([
    @pathx.join(run_workspace, "result.json"),
    @pathx.join(local_run_root, "result.json"),
  ])
  let run_result = if result_source_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(result_source_path)
  }
  let result_output_relative = eb_result_output_relative_path(
    book_root, run_result,
  )
  let output_validation = eb_output_validation(book_root, book_id)
  let manifest_output_relative = eb_valid_accepted_output_relative_for_run(
    book_root, run_id, output_validation,
  )
  let output_relative = if result_output_relative != "" &&
    eb_output_manifest_run_id(book_root, result_output_relative) == run_id {
    result_output_relative
  } else {
    manifest_output_relative
  }
  let source_input_path = eb_result_source_screen_absolute(
    book_root, run_workspace, run_id, run_result,
  )
  let workbook_validation_input_path = eb_result_workbook_validation_absolute(
    book_root, run_workspace, output_relative, run_result,
  )
  let workbook_validation_relative = if output_relative == "" {
    ""
  } else {
    eb_output_workbook_validation_relative_path(output_relative)
  }
  let workbook_validation_absolute = if workbook_validation_relative == "" {
    ""
  } else {
    @pathx.join(book_root, workbook_validation_relative)
  }
  if workbook_validation_input_path != "" &&
    workbook_validation_absolute != "" &&
    @pathx.normalize(workbook_validation_input_path) !=
    @pathx.normalize(workbook_validation_absolute) {
    @fsx.make_directory(
      @pathx.dirname(workbook_validation_absolute).to_owned(),
      recursive=true,
      exists_ok=true,
    )
    let validation_text = @fs.read_file(workbook_validation_input_path).text() catch {
      _ => ""
    }
    if validation_text != "" {
      @fsx.write_to_file(
        workbook_validation_absolute,
        validation_text,
        create=0o644,
      )
    }
  }
  let canonical_source_relative = if run_id == "" {
    ""
  } else {
    eb_source_screen_relative_path(run_id)
  }
  let canonical_source_absolute = if canonical_source_relative == "" {
    ""
  } else {
    @pathx.join(book_root, canonical_source_relative)
  }
  let source_input_valid = source_input_path != "" &&
    eb_source_screen_valid(source_input_path)
  if source_input_valid && canonical_source_absolute != "" {
    @fsx.make_directory(
      @pathx.dirname(canonical_source_absolute).to_owned(),
      recursive=true,
      exists_ok=true,
    )
    let source_text = @fs.read_file(source_input_path).text() catch { _ => "" }
    if source_text != "" &&
      @pathx.normalize(source_input_path) !=
      @pathx.normalize(canonical_source_absolute) {
      @fsx.write_to_file(canonical_source_absolute, source_text, create=0o644)
    }
  }
  let candidate_input_path = eb_result_pdf_candidates_absolute(
    book_root, run_workspace, local_run_root, run_id,
  )
  let canonical_candidate_relative = if run_id == "" {
    ""
  } else {
    eb_pdf_candidates_relative_path(run_id)
  }
  let canonical_candidate_absolute = if canonical_candidate_relative == "" {
    ""
  } else {
    @pathx.join(book_root, canonical_candidate_relative)
  }
  if candidate_input_path != "" && canonical_candidate_absolute != "" {
    @fsx.make_directory(
      @pathx.dirname(canonical_candidate_absolute).to_owned(),
      recursive=true,
      exists_ok=true,
    )
    let candidate_text = @fs.read_file(candidate_input_path).text() catch {
      _ => ""
    }
    if candidate_text != "" &&
      @pathx.normalize(candidate_input_path) !=
      @pathx.normalize(canonical_candidate_absolute) {
      @fsx.write_to_file(
        canonical_candidate_absolute,
        candidate_text,
        create=0o644,
      )
    }
  }
  if source_input_valid &&
    run_workspace != "" &&
    canonical_source_absolute != "" {
    ignore(
      copy_eb_source_screen_durable_artifacts(
        book_root, run_workspace, canonical_source_absolute,
      ),
    )
  }
  let source_screen_ready = canonical_source_absolute != "" &&
    eb_production_source_screen_valid_for_book(
      book_root, canonical_source_absolute,
    )
  let output_ready = output_relative != "" &&
    eb_accepted_output_valid(book_root, output_relative)
  let receipt_ready = @fs.exists(receipt_path) &&
    json_bool(receipt, "ok", default=false) &&
    json_string(receipt, "proposal_id", default="") != "" &&
    receipt_run_id != ""
  let receipt_run_matches = receipt_run_id != "" && run_id == receipt_run_id
  let meta_ready = meta_path != "" && @fs.exists(meta_path)
  let meta_succeeded = json_string(meta, "status", default="") == "Succeeded"
  let result_ready = result_source_path != "" && @fs.exists(result_source_path)
  let live_result = result_ready &&
    eb_run_result_is_live_moonclaw_result(run_result)
  let failed : Array[String] = []
  push_failed_unless(
    failed, receipt_ready, "MoonClaw proposal import receipt accepted",
  )
  push_failed_unless(failed, run_id != "", "MoonClaw run id available")
  push_failed_unless(
    failed, receipt_run_matches, "reconciled run matches MoonClaw receipt",
  )
  push_failed_unless(
    failed, meta_ready, "MoonClaw confirmed run metadata exists",
  )
  push_failed_unless(failed, meta_succeeded, "MoonClaw confirmed run succeeded")
  push_failed_unless(failed, result_ready, "MoonClaw result.json available")
  push_failed_unless(
    failed, live_result, "MoonClaw result is from a live imported run",
  )
  push_failed_unless(
    failed, output_ready, "accepted EB workbook exists with output manifest",
  )
  push_failed_unless(
    failed, source_screen_ready, "production official source screen proves live official PDF fetch/extract",
  )
  let accepted = failed.length() == 0
  if accepted {
    @fsx.make_directory(
      @pathx.join(local_run_root, "outputs"),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(
      @pathx.join(local_run_root, "result.json"),
      eb_live_run_result_json(
        book_id~,
        run_id~,
        output_relative~,
        source_screen_relative=canonical_source_relative,
        run_result~,
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    let report_source_path = eb_first_existing_path([
      @pathx.join(run_workspace, "report.md"),
      @pathx.join(local_run_root, "report.md"),
    ])
    if report_source_path != "" &&
      @pathx.normalize(report_source_path) !=
      @pathx.normalize(@pathx.join(local_run_root, "report.md")) {
      let report_text = @fs.read_file(report_source_path).text() catch {
        _ => ""
      }
      if report_text != "" {
        @fsx.write_to_file(
          @pathx.join(local_run_root, "report.md"),
          report_text,
          create=0o644,
        )
      }
    }
    @fsx.write_to_file(
      @pathx.join(book_root, "wiki/reviews/bookkeeper-" + run_id + ".md"),
      eb_live_bookkeeper_review_markdown(
        book_id~,
        run_id~,
        output_relative~,
        source_screen_relative=canonical_source_relative,
      ),
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, eb_output_validation_relative_path()),
      eb_output_validation(book_root, book_id).stringify(indent=2) + "\n",
      create=0o644,
    )
    let goal_id = eb_standing_goal_id_for_book(root, book_id)
    @fsx.make_directory(
      @pathx.join(root, ".moontown/watchers"),
      recursive=true,
      exists_ok=true,
    )
    append_json_line(
      @pathx.join(@pathx.join(root, ".moontown/watchers"), goal_id + ".jsonl"),
      eb_live_watcher_record(
        book_id~,
        run_id~,
        goal_id~,
        output_relative~,
        source_screen_relative=canonical_source_relative,
        run_result~,
      ),
    )
    @fsx.make_directory(
      @pathx.join(root, ".moontown/book-results"),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(
      @pathx.join(root, ".moontown/book-results/" + run_id + ".json"),
      eb_live_book_result_json(
        book_id~,
        run_id~,
        output_relative~,
        source_screen_relative=canonical_source_relative,
        run_result~,
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
  }
  let run_health = eb_durable_run_health(root, book_root, book_id)
  let receipt : Json = {
    "kind": "eb-moonclaw-run-reconciliation",
    "book_id": book_id,
    "run_id": run_id,
    "ok": accepted,
    "status": if accepted {
      "accepted_live_result"
    } else {
      "waiting_for_valid_live_result"
    },
    "failed_checks": json_from_string_array(failed),
    "source_result_path": result_source_path,
    "local_result_path": if local_run_root == "" {
      ""
    } else {
      "moonclaw-jobs/" + run_id + "/result.json"
    },
    "output_path": output_relative,
    "source_screen_path": canonical_source_relative,
    "candidate_artifact_path": canonical_candidate_relative,
    "moonclaw_meta_path": meta_path,
    "run_workspace": run_workspace,
    "run_health": run_health,
    "recorded_at": @async.now().to_string(),
  }
  if run_id != "" {
    @fsx.write_to_file(
      @pathx.join(book_root, eb_reconciliation_receipt_relative_path(run_id)),
      receipt.stringify(indent=2) + "\n",
      create=0o644,
    )
  }
  receipt
}

///|
async fn run_eb_production_proof(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  moonclaw_root~ : String,
  home~ : String,
  launch_if_missing~ : Bool,
  execute_moonclaw~ : Bool,
  force_execute~ : Bool,
  timeout_ms~ : Int,
) -> Json {
  let packet_relative = eb_moonclaw_proposal_packet_relative_path()
  let packet_path = @pathx.join(book_root, packet_relative)
  let runtime_refresh = refresh_eb_runtime_artifacts(root, book_root, book_id)
  let standing_goal_sync = sync_book_standing_goal(root, book_root, book_id) catch {
    _ => Json::object({})
  }
  let runtime_artifacts_changed = json_bool(
    runtime_refresh,
    "changed",
    default=false,
  )
  let target_readiness = eb_production_target_readiness(book_root)
  let targets_ready = json_bool(target_readiness, "ok", default=false)
  let import_receipt_path = @pathx.join(
    book_root,
    eb_moonclaw_import_receipt_relative_path(),
  )
  let previous_production_proof_receipt = read_json_file_or_object(
    @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
  )
  let retry_import_receipt_relative = eb_moonclaw_retry_import_receipt_relative_path()
  let retry_import_receipt_path = @pathx.join(
    book_root, retry_import_receipt_relative,
  )
  let raw_import_receipt = read_json_file_or_object(import_receipt_path)
  let mut import_receipt = eb_recovered_moonclaw_import_receipt(
    book_root, book_id, raw_import_receipt, previous_production_proof_receipt,
  )
  let mut import_receipt_recovered = json_bool(
    import_receipt,
    "recovered",
    default=false,
  )
  let mut retry_import_receipt = read_json_file_or_object(
    retry_import_receipt_path,
  )
  let mut retry_import_receipt_ready = @fs.exists(retry_import_receipt_path)
  let mut import_step = "reused_existing_import"
  let mut run_id = json_string(import_receipt, "run_id", default="")
    .trim()
    .to_owned()
  let import_stale_after_runtime_refresh = eb_import_stale_after_runtime_refresh(
    book_root, import_receipt, runtime_refresh,
  )
  let imported_run_health = if run_id == "" {
    Json::object({})
  } else {
    eb_durable_run_health(root, book_root, book_id)
  }
  let imported_run_receipt_path = if run_id == "" {
    ""
  } else {
    @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id))
  }
  let preserve_reconciled_import = run_id != "" &&
    @fs.exists(imported_run_receipt_path) &&
    json_bool(imported_run_health, "production_ready", default=false) &&
    json_string(imported_run_health, "run_id", default="") == run_id
  if (runtime_artifacts_changed || import_stale_after_runtime_refresh) &&
    !preserve_reconciled_import {
    import_receipt = Json::object({})
    import_step = if runtime_artifacts_changed {
      "runtime_refreshed_reimport_required"
    } else {
      "runtime_refresh_newer_than_import"
    }
    run_id = ""
  } else if preserve_reconciled_import &&
    (runtime_artifacts_changed || import_stale_after_runtime_refresh) {
    import_step = "reused_reconciled_import_after_runtime_refresh"
  }
  let proof_failed : Array[String] = []
  if !targets_ready {
    for
      failed_check in json_string_array_items(target_readiness, "failed_checks") {
      proof_failed.push(failed_check)
    }
  }
  let mut orphaned_relaunch_attempted = false
  let mut orphaned_relaunch_failed = false
  if targets_ready &&
    run_id != "" &&
    launch_if_missing &&
    (force_execute || execute_moonclaw) {
    let prior_run_receipt_path = @pathx.join(
      book_root,
      eb_moonclaw_run_receipt_relative_path(run_id),
    )
    let prior_run_receipt = read_json_file_or_object(prior_run_receipt_path)
    if eb_moonclaw_run_receipt_orphaned_after_timeout(prior_run_receipt) {
      orphaned_relaunch_attempted = true
      if @fs.exists(packet_path) {
        let prior_import_receipt = import_receipt
        let prior_run_id = run_id
        let relaunch_receipt = run_eb_moonclaw_proposal_import(
          root~,
          book_root~,
          book_id~,
          packet_relative~,
          packet_path~,
          moonclaw_root~,
          home~,
          confirm=true,
          inline=false,
          timeout_ms~,
        )
        let relaunch_run_id = json_string(
            relaunch_receipt,
            "run_id",
            default="",
          )
          .trim()
          .to_owned()
        if json_bool(relaunch_receipt, "ok", default=false) &&
          relaunch_run_id != "" {
          import_receipt = relaunch_receipt
          import_receipt_recovered = false
          import_step = "relaunched_after_orphaned_timeout"
          run_id = relaunch_run_id
        } else {
          orphaned_relaunch_failed = true
          retry_import_receipt = relaunch_receipt
          retry_import_receipt_ready = true
          @fsx.make_directory(
            @pathx.dirname(retry_import_receipt_path).to_owned(),
            recursive=true,
            exists_ok=true,
          )
          @fsx.write_to_file(
            retry_import_receipt_path,
            retry_import_receipt.stringify(indent=2) + "\n",
            create=0o644,
          )
          @fsx.write_to_file(
            import_receipt_path,
            prior_import_receipt.stringify(indent=2) + "\n",
            create=0o644,
          )
          import_receipt = prior_import_receipt
          import_receipt_recovered = json_bool(
            import_receipt,
            "recovered",
            default=false,
          )
          import_step = "relaunch_failed_preserved_orphaned_import"
          run_id = prior_run_id
          proof_failed.push(
            "MoonClaw orphaned-run retry import produced a replacement run id",
          )
        }
      } else {
        import_step = "missing_proposal_packet"
        proof_failed.push("MoonClaw proposal packet exists")
      }
    }
  }
  if targets_ready && run_id == "" {
    if launch_if_missing {
      if @fs.exists(packet_path) {
        import_receipt = run_eb_moonclaw_proposal_import(
          root~,
          book_root~,
          book_id~,
          packet_relative~,
          packet_path~,
          moonclaw_root~,
          home~,
          confirm=true,
          inline=false,
          timeout_ms~,
        )
        import_receipt_recovered = false
        import_step = "launched_confirmed_import"
        run_id = json_string(import_receipt, "run_id", default="")
          .trim()
          .to_owned()
      } else {
        import_step = "missing_proposal_packet"
        proof_failed.push("MoonClaw proposal packet exists")
      }
    } else {
      if import_step == "reused_existing_import" {
        import_step = "missing_run_not_launched"
      }
      proof_failed.push(
        "MoonClaw run id available or launch_if_missing enabled",
      )
    }
  }
  let import_ok = json_bool(import_receipt, "ok", default=false) &&
    json_string(import_receipt, "proposal_id", default="") != ""
  push_failed_unless(
    proof_failed, import_ok, "MoonClaw proposal import receipt accepted",
  )
  let run_receipt_relative = if run_id == "" {
    ""
  } else {
    eb_moonclaw_run_receipt_relative_path(run_id)
  }
  let run_receipt_path = if run_receipt_relative == "" {
    ""
  } else {
    @pathx.join(book_root, run_receipt_relative)
  }
  let mut run_receipt = if run_receipt_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(run_receipt_path)
  }
  let mut run_step = if run_id == "" {
    "missing_run_id"
  } else {
    "reused_existing_run_receipt"
  }
  let existing_run_ok = run_receipt_path != "" &&
    @fs.exists(run_receipt_path) &&
    json_string(run_receipt, "kind", default="") ==
    "moonclaw-confirmed-run-receipt" &&
    json_string(run_receipt, "run_id", default="") == run_id &&
    json_bool(run_receipt, "ok", default=false)
  if targets_ready &&
    run_id != "" &&
    !orphaned_relaunch_failed &&
    (force_execute || (execute_moonclaw && !existing_run_ok)) {
    write_eb_production_proof_progress(
      root, book_root, book_id, run_id, import_step, "executing_confirmed_run", timeout_ms,
      import_receipt, retry_import_receipt, import_receipt_recovered, retry_import_receipt_ready,
    )
    run_receipt = run_eb_moonclaw_confirmed_run(
      root~,
      book_root~,
      book_id~,
      run_id~,
      moonclaw_root~,
      home~,
      timeout_ms~,
    )
    run_step = "executed_confirmed_run"
  } else if run_id != "" && existing_run_ok {
    run_step = "reused_successful_run_receipt"
  } else if run_id != "" && orphaned_relaunch_failed {
    run_step = "orphaned_relaunch_failed_execution_skipped"
  } else if run_id != "" && !execute_moonclaw {
    run_step = "execution_skipped"
  }
  push_failed_unless(proof_failed, run_id != "", "MoonClaw run id available")
  push_failed_unless(
    proof_failed,
    json_bool(run_receipt, "ok", default=false),
    "MoonClaw confirmed run receipt succeeded",
  )
  let reconciliation = if !targets_ready {
    (
      {
        "kind": "eb-moonclaw-run-reconciliation",
        "book_id": book_id,
        "run_id": run_id,
        "ok": false,
        "status": "target_not_ready",
        "failed_checks": json_from_string_array(
          json_string_array_items(target_readiness, "failed_checks"),
        ),
        "target_readiness": target_readiness,
        "run_health": eb_durable_run_health(root, book_root, book_id),
        "recorded_at": @async.now().to_string(),
      } : Json)
  } else if run_id == "" {
    (
      {
        "kind": "eb-moonclaw-run-reconciliation",
        "book_id": book_id,
        "run_id": "",
        "ok": false,
        "status": "missing_moonclaw_run",
        "failed_checks": json_from_string_array(["MoonClaw run id available"]),
        "run_health": eb_durable_run_health(root, book_root, book_id),
        "recorded_at": @async.now().to_string(),
      } : Json)
  } else {
    reconcile_eb_moonclaw_run(
      root~,
      book_root~,
      book_id~,
      requested_run_id=run_id,
    )
  }
  let run_health = eb_durable_run_health(root, book_root, book_id)
  for
    failed_check in json_string_array_items(
      run_health, "production_failed_checks",
    ) {
    proof_failed.push(failed_check)
  }
  let production_ready = json_bool(
    run_health,
    "production_ready",
    default=false,
  )
  let run_health_status = json_string(run_health, "status", default="")
  let status = if production_ready {
    "production_ready"
  } else if !targets_ready {
    "not_proven_target_not_ready"
  } else if import_step == "runtime_refreshed_reimport_required" ||
    import_step == "runtime_refresh_newer_than_import" {
    "not_proven_refreshed_runtime_requires_new_moonclaw_import"
  } else if run_id == "" {
    "not_proven_missing_moonclaw_run"
  } else if run_health_status != "" {
    "not_proven_" + run_health_status
  } else {
    "not_proven"
  }
  let proof : Json = {
    "kind": "eb-production-proof",
    "book_id": book_id,
    "ok": production_ready,
    "status": status,
    "proof_level": if production_ready {
      "live-production"
    } else {
      "not-proven"
    },
    "run_id": run_id,
    "import_step": import_step,
    "run_step": run_step,
    "timeout_ms": timeout_ms,
    "target_readiness": target_readiness,
    "import_stale_after_runtime_refresh": import_stale_after_runtime_refresh,
    "orphaned_relaunch_attempted": orphaned_relaunch_attempted,
    "orphaned_relaunch_failed": orphaned_relaunch_failed,
    "receipt_path": eb_production_proof_receipt_relative_path(),
    "moonclaw_import_receipt_path": eb_moonclaw_import_receipt_relative_path(),
    "moonclaw_import_receipt_recovered": import_receipt_recovered,
    "moonclaw_import_recovery_source": json_string(
      import_receipt,
      "recovery_source",
      default="",
    ),
    "moonclaw_retry_import_receipt_path": retry_import_receipt_relative,
    "moonclaw_retry_import_receipt_ready": retry_import_receipt_ready,
    "moonclaw_run_receipt_path": run_receipt_relative,
    "reconciliation_receipt_path": if run_id == "" {
      ""
    } else {
      eb_reconciliation_receipt_relative_path(run_id)
    },
    "runtime_refresh": runtime_refresh,
    "standing_goal_sync": standing_goal_sync,
    "import_receipt": import_receipt,
    "retry_import_receipt": retry_import_receipt,
    "run_receipt": run_receipt,
    "reconciliation": reconciliation,
    "run_health": run_health,
    "failed_checks": json_from_string_array(proof_failed),
    "recorded_at": @async.now().to_string(),
  }
  @fsx.make_directory(
    @pathx.dirname(
      @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
    ).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
    proof.stringify(indent=2) + "\n",
    create=0o644,
  )
  let final_run_health = eb_durable_run_health(root, book_root, book_id)
  let final_proof : Json = {
    "kind": "eb-production-proof",
    "book_id": book_id,
    "ok": production_ready,
    "status": status,
    "proof_level": if production_ready {
      "live-production"
    } else {
      "not-proven"
    },
    "run_id": run_id,
    "import_step": import_step,
    "run_step": run_step,
    "timeout_ms": timeout_ms,
    "target_readiness": target_readiness,
    "import_stale_after_runtime_refresh": import_stale_after_runtime_refresh,
    "orphaned_relaunch_attempted": orphaned_relaunch_attempted,
    "orphaned_relaunch_failed": orphaned_relaunch_failed,
    "receipt_path": eb_production_proof_receipt_relative_path(),
    "moonclaw_import_receipt_path": eb_moonclaw_import_receipt_relative_path(),
    "moonclaw_import_receipt_recovered": import_receipt_recovered,
    "moonclaw_import_recovery_source": json_string(
      import_receipt,
      "recovery_source",
      default="",
    ),
    "moonclaw_retry_import_receipt_path": retry_import_receipt_relative,
    "moonclaw_retry_import_receipt_ready": retry_import_receipt_ready,
    "moonclaw_run_receipt_path": run_receipt_relative,
    "reconciliation_receipt_path": if run_id == "" {
      ""
    } else {
      eb_reconciliation_receipt_relative_path(run_id)
    },
    "runtime_refresh": runtime_refresh,
    "standing_goal_sync": standing_goal_sync,
    "import_receipt": import_receipt,
    "retry_import_receipt": retry_import_receipt,
    "run_receipt": run_receipt,
    "reconciliation": reconciliation,
    "run_health": final_run_health,
    "failed_checks": json_from_string_array(proof_failed),
    "recorded_at": json_string(proof, "recorded_at", default=""),
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
    final_proof.stringify(indent=2) + "\n",
    create=0o644,
  )
  final_proof
}

///|
async fn eb_first_existing_path(paths : Array[String]) -> String {
  for path in paths {
    if path != "" && @fs.exists(path) {
      return path
    }
  }
  ""
}
