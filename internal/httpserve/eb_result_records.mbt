///|
fn eb_moonclaw_import_stderr_tolerated(text : String, receipt : Json) -> Bool {
  let clean = text.trim().to_owned()
  if clean == "" {
    return false
  }
  if !json_bool(receipt, "ok", default=false) ||
    json_int(receipt, "exit_code", default=-1) != 0 ||
    json_string(receipt, "proposal_id", default="") == "" {
    return false
  }
  let mut saw_known = false
  for line in clean.split("\n") {
    let item = line.trim().to_owned()
    if item == "" {
      continue
    }
    if item == "tcc: error: invalid option -- '--home'" {
      saw_known = true
    } else {
      return false
    }
  }
  saw_known
}

///|
fn eb_result_output_relative_path(book_root : String, result : Json) -> String {
  for
    key in ["output_path", "xlsx_path", "accepted_output_path", "workbook_path"] {
    let relative = eb_book_relative_path(
      book_root,
      json_string(result, key, default=""),
    )
    if relative != "" {
      return relative
    }
  }
  for key in ["outputs", "output_paths"] {
    for item in json_array_items(result, key) {
      match item {
        Json::String(value) => {
          let relative = eb_book_relative_path(book_root, value)
          if relative != "" {
            return relative
          }
        }
        _ => ()
      }
    }
  }
  ""
}

///|
fn eb_book_relative_path(book_root : String, candidate : String) -> String {
  let clean = candidate.trim().to_owned()
  if clean == "" {
    return ""
  }
  if clean.has_prefix("/") || @pathx.is_absolute(clean) {
    let normalized = @pathx.normalize(clean)
    let root = @pathx.normalize(book_root)
    let prefix = root + "/"
    if normalized.has_prefix(prefix) {
      normalized[prefix.length():].to_string()
    } else {
      ""
    }
  } else {
    match clean_relative_path(clean) {
      Some(relative) => relative
      None => ""
    }
  }
}

///|
async fn eb_result_source_screen_absolute(
  book_root : String,
  run_workspace : String,
  run_id : String,
  result : Json,
) -> String {
  let candidates : Array[String] = []
  for key in ["source_screen_path", "official_source_screen_path"] {
    let candidate = json_string(result, key, default="").trim().to_owned()
    if candidate == "" {
      continue
    }
    if candidate.has_prefix("/") || @pathx.is_absolute(candidate) {
      candidates.push(@pathx.normalize(candidate))
    } else {
      candidates.push(@pathx.join(book_root, candidate))
      candidates.push(@pathx.join(run_workspace, candidate))
    }
  }
  if run_workspace != "" {
    candidates.push(
      @pathx.join(run_workspace, "outputs/official-source-screen.json"),
    )
    candidates.push(@pathx.join(run_workspace, "official-source-screen.json"))
  }
  if run_id != "" {
    candidates.push(
      @pathx.join(book_root, eb_source_screen_relative_path(run_id)),
    )
  }
  eb_first_existing_path(candidates)
}

///|
async fn eb_result_workbook_validation_absolute(
  book_root : String,
  run_workspace : String,
  output_relative : String,
  result : Json,
) -> String {
  let candidates : Array[String] = []
  for key in ["workbook_validation_path", "xlsx_validation_path"] {
    let candidate = json_string(result, key, default="").trim().to_owned()
    if candidate == "" {
      continue
    }
    if candidate.has_prefix("/") || @pathx.is_absolute(candidate) {
      candidates.push(@pathx.normalize(candidate))
    } else {
      candidates.push(@pathx.join(book_root, candidate))
      candidates.push(@pathx.join(run_workspace, candidate))
    }
  }
  if output_relative != "" {
    let validation_relative = eb_output_workbook_validation_relative_path(
      output_relative,
    )
    let output_name = eb_output_name_from_relative(output_relative)
    candidates.push(@pathx.join(book_root, validation_relative))
    candidates.push(@pathx.join(run_workspace, validation_relative))
    candidates.push(
      @pathx.join(run_workspace, output_name + ".validation.json"),
    )
    candidates.push(
      @pathx.join(run_workspace, "outputs/" + output_name + ".validation.json"),
    )
  }
  eb_first_existing_path(candidates)
}

///|
fn eb_reconciliation_receipt_relative_path(run_id : String) -> String {
  "raw/analysis-runs/" + run_id + "-moonclaw-reconciliation.json"
}

///|
fn eb_accepted_output_recovery_receipt_relative_path(run_id : String) -> String {
  "raw/analysis-runs/" + run_id + "-accepted-output-recovery.json"
}

///|
fn eb_run_result_is_live_moonclaw_result(run_result : Json) -> Bool {
  let kind = json_string(run_result, "kind", default="")
  let recovery_mode = json_string(run_result, "recovery_mode", default="")
  let helper_live_result = kind != "" &&
    kind != "moonclaw-eb-sample-result" &&
    kind != "moonclaw-eb-recovered-accepted-output" &&
    recovery_mode == ""
  let metadata = json_object_field_or_empty(run_result, "metadata")
  let moonclaw_wrapper_live_result = json_string(
      run_result,
      "step_id",
      default="",
    ) ==
    "package_result" &&
    json_string(run_result, "result_decision", default="") == "accepted" &&
    json_string(metadata, "run_id", default="") != "" &&
    json_string(run_result, "content", default="").contains(
      "standing_goal_decision",
    )
  helper_live_result || moonclaw_wrapper_live_result
}

///|
fn eb_live_run_result_json(
  book_id~ : String,
  run_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  run_result~ : Json,
) -> Json {
  {
    "kind": trimmed_payload_text(
      json_string(run_result, "kind", default=""),
      default="moonclaw-eb-live-result",
    ),
    "status": trimmed_payload_text(
      json_string(run_result, "status", default=""),
      default="completed",
    ),
    "decision": "accepted_source_backed_output",
    "book_id": book_id,
    "run_id": run_id,
    "output_path": output_relative,
    "source_screen_path": source_screen_relative,
    "accepted_by_bookkeeper": true,
    "sample_run": false,
    "summary": trimmed_payload_text(
      json_string(run_result, "summary", default=""),
      default="MoonClaw live run produced a Bookkeeper-accepted EB tracking workbook.",
    ),
    "original_result": run_result,
  }
}

///|
fn eb_recovered_run_result_json(
  book_id~ : String,
  run_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  reason~ : String,
  health_before~ : Json,
) -> Json {
  {
    "kind": "moonclaw-eb-recovered-accepted-output",
    "status": "accepted_recovered_output",
    "decision": "accepted_recovered_output",
    "book_id": book_id,
    "run_id": run_id,
    "output_path": output_relative,
    "source_screen_path": source_screen_relative,
    "accepted_by_bookkeeper": true,
    "sample_run": false,
    "recovery_mode": "accepted_output_recovery",
    "production_ready": false,
    "summary": "Moondesk accepted an already validated EB workbook/source-screen package as durable recovered output; live MoonClaw lifecycle proof is still required for production readiness.",
    "reason": reason,
    "accepted_output_health": {
      "workbook_validation_ready": json_bool(
        health_before,
        "workbook_validation_ready",
        default=false,
      ),
      "source_screen_production_ready": json_bool(
        health_before,
        "source_screen_production_ready",
        default=false,
      ),
      "output_target_match_ready": json_bool(
        health_before,
        "output_target_match_ready",
        default=false,
      ),
      "targets_production_ready": json_bool(
        health_before,
        "targets_production_ready",
        default=false,
      ),
    },
  }
}

///|
fn eb_recovered_book_result_json(
  book_id~ : String,
  run_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  reason~ : String,
  health_before~ : Json,
) -> Json {
  {
    "id": run_id,
    "kind": "eb-recovered-output",
    "status": "accepted",
    "book_id": book_id,
    "run_id": run_id,
    "title": "Accepted recovered EB workbook evidence for \{run_id}",
    "summary": "Moondesk accepted validated EB output evidence into the book result ledger without marking the MoonClaw lifecycle production-ready.",
    "updated_pages": json_from_string_array([
      "wiki/reviews/bookkeeper-" + run_id + "-recovered.md",
      eb_output_validation_relative_path(),
    ]),
    "outputs": json_from_string_array([output_relative]),
    "source_screen_path": source_screen_relative,
    "review_queued": false,
    "notify_town": true,
    "evidence_id": "EV-" + run_id,
    "recovery_mode": "accepted_output_recovery",
    "production_ready": false,
    "reason": reason,
    "production_blockers": json_from_string_array(
      json_string_array_items(health_before, "production_failed_checks"),
    ),
  }
}

///|
fn eb_recovered_watcher_record(
  book_id~ : String,
  run_id~ : String,
  goal_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  reason~ : String,
  health_before~ : Json,
) -> Json {
  {
    "id": "watcher-" + run_id,
    "goal_id": goal_id,
    "book_id": book_id,
    "run_id": run_id,
    "decision": "Update",
    "standing_goal_decision": "update",
    "delta_score": 100,
    "checked_sources_count": eb_official_domains().length(),
    "new_sources_found": 1,
    "accepted_facts_count": 1,
    "rejected_facts_count": 0,
    "wiki_pages_changed_count": 1,
    "book_changed": true,
    "notification_required": true,
    "notify_rule": "accepted-new-knowledge-only",
    "output_path": output_relative,
    "source_screen_path": source_screen_relative,
    "summary": "Moondesk accepted recovered validated EB output evidence into the standing watch ledger.",
    "recovery_mode": "accepted_output_recovery",
    "production_ready": false,
    "reason": reason,
    "production_blockers": json_from_string_array(
      json_string_array_items(health_before, "production_failed_checks"),
    ),
  }
}

///|
fn eb_recovered_bookkeeper_review_markdown(
  book_id~ : String,
  run_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  reason~ : String,
) -> String {
  [
    "# Bookkeeper Review: Recovered EB Output",
    "",
    "- Book: `\{book_id}`",
    "- Run: `\{run_id}`",
    "- Decision: accepted recovered output",
    "- Workbook: `\{output_relative}`",
    "- Source screen: `\{source_screen_relative}`",
    "- Reason: \{reason}",
    "",
    "This review accepts a workbook/source-screen package that already passed Moondesk's EB output gates. It does not prove the result came from a confirmed live MoonClaw run; production readiness still requires the MoonClaw import, run, metadata, web-tool, candidate-discovery, and no-missing-input checks.",
    "",
  ].join("\n")
}

///|
async fn accept_recovered_eb_output(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  reason~ : String,
) -> Json {
  let health_before = eb_durable_run_health(root, book_root, book_id)
  let contract = book_contract_verification(
    root, book_root, book_id, "exchangeable-bond-evidence-watch",
  )
  let output_validation = json_object_field_or_empty(
    health_before, "output_validation",
  )
  let run_id = json_string(health_before, "run_id", default="")
  let output_relative = json_string(health_before, "output_path", default="")
  let source_screen_relative = json_string(
    health_before,
    "source_screen_path",
    default="",
  )
  let failed : Array[String] = []
  push_failed_unless(
    failed,
    json_bool(contract, "verified", default=false),
    "book contract verified",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "moonclaw_profile_ready", default=false),
    "MoonClaw EB profile ready",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "moonclaw_proposal_packet_ready", default=false),
    "MoonClaw EB proposal packet ready",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "standing_goal_registration_ready", default=false),
    "Moontown standing goal registration ready",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "targets_production_ready", default=false),
    "EB target bond configuration is production-ready",
  )
  push_failed_unless(
    failed,
    run_id != "",
    "accepted output manifest has run id",
  )
  push_failed_unless(
    failed,
    output_relative != "",
    "accepted EB workbook path is available",
  )
  push_failed_unless(
    failed,
    json_bool(output_validation, "final_output_ready", default=false),
    "output validation final gate ready",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "workbook_validation_ready", default=false),
    "hash-bound workbook validation artifact exists",
  )
  push_failed_unless(
    failed,
    !json_bool(health_before, "workbook_validation_sample_run", default=true),
    "workbook validation is from a live run, not a sample",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "workbook_data_proof_ready", default=false),
    "workbook validation proves source-backed data rows in both sheets",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "workbook_hyperlinks_ready", default=false),
    "workbook XML contains official clickable hyperlinks in the original-link column",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "workbook_appendix_notes_ready", default=false),
    "workbook appendix notes include search keywords, retrieval date, and official source list",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "workbook_quality_proof_ready", default=false),
    "workbook validation proves EB quality rules",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "workbook_lifecycle_proof_ready", default=false),
    "workbook validation proves six lifecycle stages",
  )
  push_failed_unless(
    failed,
    json_bool(health_before, "output_target_match_ready", default=false),
    "accepted workbook filename and manifest match the configured production EB target",
  )
  push_failed_unless(
    failed,
    source_screen_relative != "" &&
    json_bool(health_before, "source_screen_production_ready", default=false),
    "production source screen proves live official PDF fetch/extract",
  )
  let accepted = failed.length() == 0
  if accepted {
    let local_run_root = @pathx.join(book_root, "moonclaw-jobs/" + run_id)
    @fsx.make_directory(local_run_root, recursive=true, exists_ok=true)
    @fsx.write_to_file(
      @pathx.join(local_run_root, "result.json"),
      eb_recovered_run_result_json(
        book_id~,
        run_id~,
        output_relative~,
        source_screen_relative~,
        reason~,
        health_before~,
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(
        book_root,
        "wiki/reviews/bookkeeper-" + run_id + "-recovered.md",
      ),
      eb_recovered_bookkeeper_review_markdown(
        book_id~,
        run_id~,
        output_relative~,
        source_screen_relative~,
        reason~,
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
      eb_recovered_watcher_record(
        book_id~,
        run_id~,
        goal_id~,
        output_relative~,
        source_screen_relative~,
        reason~,
        health_before~,
      ),
    )
    @fsx.make_directory(
      @pathx.join(root, ".moontown/book-results"),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(
      @pathx.join(root, ".moontown/book-results/" + run_id + ".json"),
      eb_recovered_book_result_json(
        book_id~,
        run_id~,
        output_relative~,
        source_screen_relative~,
        reason~,
        health_before~,
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
  }
  let run_health = eb_durable_run_health(root, book_root, book_id)
  let receipt : Json = {
    "kind": "eb-accepted-output-recovery",
    "book_id": book_id,
    "run_id": run_id,
    "ok": accepted,
    "status": if accepted {
      "accepted_recovered_output"
    } else {
      "recovery_not_accepted"
    },
    "failed_checks": json_from_string_array(failed),
    "output_path": output_relative,
    "source_screen_path": source_screen_relative,
    "reason": reason,
    "recovery_mode": "accepted_output_recovery",
    "production_ready": false,
    "receipt_path": if run_id == "" {
      ""
    } else {
      eb_accepted_output_recovery_receipt_relative_path(run_id)
    },
    "run_health": run_health,
  }
  if run_id != "" {
    @fsx.write_to_file(
      @pathx.join(
        book_root,
        eb_accepted_output_recovery_receipt_relative_path(run_id),
      ),
      receipt.stringify(indent=2) + "\n",
      create=0o644,
    )
  }
  receipt
}

///|
fn eb_live_book_result_json(
  book_id~ : String,
  run_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  run_result~ : Json,
) -> Json {
  {
    "id": run_id,
    "kind": "eb-live-output",
    "status": "accepted",
    "book_id": book_id,
    "run_id": run_id,
    "title": "Accepted source-backed EB workbook from MoonClaw run \{run_id}",
    "summary": trimmed_payload_text(
      json_string(run_result, "summary", default=""),
      default="MoonClaw live run passed Moondesk's EB output, official-source, and Bookkeeper acceptance gates.",
    ),
    "updated_pages": json_from_string_array([
      "wiki/reviews/bookkeeper-" + run_id + ".md",
      eb_output_validation_relative_path(),
    ]),
    "outputs": json_from_string_array([output_relative]),
    "source_screen_path": source_screen_relative,
    "review_queued": false,
    "notify_town": true,
    "evidence_id": "EV-" + run_id,
  }
}

///|
fn eb_live_watcher_record(
  book_id~ : String,
  run_id~ : String,
  goal_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  run_result~ : Json,
) -> Json {
  {
    "id": "watcher-" + run_id,
    "goal_id": goal_id,
    "book_id": book_id,
    "run_id": run_id,
    "decision": "Update",
    "standing_goal_decision": "update",
    "delta_score": json_int(run_result, "delta_score", default=100),
    "checked_sources_count": json_int(
      run_result,
      "checked_sources_count",
      default=eb_official_domains().length(),
    ),
    "new_sources_found": json_int(run_result, "new_sources_found", default=1),
    "accepted_facts_count": json_int(
      run_result,
      "accepted_facts_count",
      default=1,
    ),
    "rejected_facts_count": json_int(
      run_result,
      "rejected_facts_count",
      default=0,
    ),
    "wiki_pages_changed_count": json_int(
      run_result,
      "wiki_pages_changed_count",
      default=1,
    ),
    "book_changed": true,
    "notification_required": true,
    "output_path": output_relative,
    "source_screen_path": source_screen_relative,
    "summary": trimmed_payload_text(
      json_string(run_result, "summary", default=""),
      default="Moondesk reconciled a live MoonClaw EB result into the standing watch ledger.",
    ),
  }
}

///|
fn eb_live_bookkeeper_review_markdown(
  book_id~ : String,
  run_id~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
) -> String {
  [
    "# Bookkeeper Review: MoonClaw EB Result",
    "",
    "- Book: `\{book_id}`",
    "- Run: `\{run_id}`",
    "- Accepted output: `\{output_relative}`",
    "- Official source screen: `\{source_screen_relative}`",
    "- Decision: `accepted_source_backed_output`",
    "",
    "Moondesk reconciled this run only after the MoonClaw run metadata succeeded, `result.json` was present, the workbook manifest declared Bookkeeper acceptance, and the official-source screen passed the domain gate.",
    "",
  ].join("\n")
}

///|
fn eb_moontown_task_execution_record(
  book_id~ : String,
  packet_id~ : String,
  packet_path~ : String,
  packet_relative~ : String,
  proposal_id~ : String,
  run_id~ : String,
  ok~ : Bool,
  confirm~ : Bool,
  command~ : String,
  tick~ : Int,
) -> Json {
  let status = if !ok {
    "Failed"
  } else if run_id != "" {
    "RunConfirmed"
  } else if confirm {
    "ProposalImported"
  } else {
    "ProposalImported"
  }
  let task_id = @desk.stable_id("standing-watch-task", book_id)
  {
    "kind": "moontown-task-execution-record",
    "schema": "moontown.core.TaskExecutionRecord",
    "task_id": task_id,
    "book_id": book_id,
    "packet_id": packet_id,
    "packet_path": packet_path,
    "packet_relative_path": packet_relative,
    "proposal_id": if proposal_id == "" {
      null
    } else {
      proposal_id
    },
    "run_id": if run_id == "" {
      null
    } else {
      run_id
    },
    "status": status,
    "summary": if run_id != "" {
      "Moondesk imported EB standing-watch packet into MoonClaw proposal `\{proposal_id}` and confirmed run `\{run_id}`."
    } else if ok {
      "Moondesk imported EB standing-watch packet into MoonClaw proposal `\{proposal_id}`; run confirmation is still pending."
    } else {
      "Moondesk failed to import EB standing-watch packet into MoonClaw."
    },
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "context_pages": json_from_string_array([
      "raw/inbox/eb-tracking-request.json", "raw/inbox/eb-standing-watch-dispatch.json",
      "raw/bootstrap/EB_WATCH_CONTRACT.md", "wiki/methods/my-analysis-method.md",
      "schemas/eb-tracking-output.schema.md",
    ]),
    "skill_paths": json_from_string_array([
      "skills/pdf-watch/SKILL.md", "skills/pdf-analysis/SKILL.md", "skills/eb-credit-compliance/SKILL.md",
    ]),
    "last_command": command,
    "assigned_worker_id": "moonclaw-eb-pdf-evidence-watch",
    "attempt": 1,
    "heartbeat_tick": tick,
    "stale_after_tick": tick + 30,
    "next_retry_tick": null,
    "result_decision": if run_id != "" {
      "pending"
    } else {
      "queued"
    },
    "requires_review": true,
    "notify_town": true,
  }
}

///|
fn eb_sample_run_result_json(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
  output_relative~ : String,
) -> Json {
  {
    "kind": "moonclaw-eb-sample-result",
    "status": "completed",
    "decision": "accepted_sample_output",
    "book_id": book_id,
    "run_id": run_id,
    "bond_code": bond_code,
    "bond_short_name": bond_short_name,
    "as_of": as_of,
    "output_path": output_relative,
    "source_screen_path": eb_source_screen_relative_path(run_id),
    "sheets": json_from_string_array([
      "公告追踪主表", "关键指标监控表",
    ]),
    "official_domain_policy": json_from_string_array(eb_official_domains()),
    "quality_checks": json_from_string_array([
      "official-domain URL gate", "six-stage lifecycle coverage gate", "two-sheet XLSX output gate",
      "Bookkeeper acceptance gate",
    ]),
    "note": "Deterministic Moondesk validation run. It proves durable packaging and output readiness, not live web evidence collection.",
  }
}

///|
fn eb_source_screen_relative_path(run_id : String) -> String {
  "raw/analysis-runs/" + run_id + "-official-source-screen.json"
}

///|
fn eb_pdf_candidates_relative_path(run_id : String) -> String {
  "raw/analysis-runs/" + run_id + "-official-pdf-candidates.json"
}

///|
async fn eb_result_pdf_candidates_absolute(
  book_root : String,
  run_workspace : String,
  local_run_root : String,
  run_id : String,
) -> String {
  let candidates : Array[String] = []
  if run_workspace != "" {
    candidates.push(
      @pathx.join(run_workspace, "outputs/official-pdf-candidates.json"),
    )
    candidates.push(@pathx.join(run_workspace, "official-pdf-candidates.json"))
  }
  if local_run_root != "" {
    candidates.push(
      @pathx.join(local_run_root, "outputs/official-pdf-candidates.json"),
    )
    candidates.push(@pathx.join(local_run_root, "official-pdf-candidates.json"))
  }
  if run_id != "" {
    candidates.push(
      @pathx.join(book_root, eb_pdf_candidates_relative_path(run_id)),
    )
  }
  eb_first_existing_path(candidates)
}

///|
fn eb_official_source_screen_json(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
) -> Json {
  {
    "kind": "eb-official-source-screen",
    "status": "official_source_screened",
    "book_id": book_id,
    "run_id": run_id,
    "bond_code": bond_code,
    "bond_short_name": bond_short_name,
    "as_of": as_of,
    "official_domains": json_from_string_array(eb_official_domains()),
    "official_domain_count": eb_official_domains().length(),
    "screened_source_roots": json_from_string_array(eb_official_source_roots()),
    "lifecycle_stages": eb_lifecycle_stage_json(),
    "missing_stage_policy": "If an expected stage has no official PDF evidence, mark 未检索到 with the reason instead of fabricating a row.",
    "quality_checks": json_from_string_array([
      "official-domain URL gate", "no third-party转载 URL gate", "six lifecycle-stage coverage or missing-marker gate",
      "Bookkeeper acceptance before XLSX publication",
    ]),
    "live_fetch_performed": false,
    "note": "This is a deterministic official-source screening artifact. It records allowed source roots and gates, but does not claim PDFs were fetched or extracted live.",
  }
}

///|
fn eb_official_pdf_candidates_json(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
  official_url~ : String,
  sample_run~ : Bool,
) -> Json {
  {
    "kind": "eb-official-pdf-candidates",
    "status": "completed",
    "book_id": book_id,
    "run_id": run_id,
    "bond_code": bond_code,
    "bond_short_name": bond_short_name,
    "as_of": as_of,
    "sample_run": sample_run,
    "candidates": [
      {
        "url": official_url,
        "title": "\{bond_code} \{bond_short_name} official EB PDF candidate",
        "platform": if official_url.contains("sse.com.cn") {
          "上海证券交易所"
        } else {
          "官方披露平台"
        },
        "relevance": "target bond disclosure",
      },
    ],
    "checked_domains": json_from_string_array(["sse.com.cn"]),
    "standing_goal_decision": "update",
  }
}

///|
fn eb_official_source_roots() -> Array[String] {
  [
    "https://www.sse.com.cn/", "https://www.szse.cn/", "https://www.cninfo.com.cn/",
    "https://www.chinabond.com.cn/", "https://www.shclearing.com.cn/", "https://www.csrc.gov.cn/",
  ]
}

///|
fn eb_official_source_screen_markdown(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
) -> String {
  let lines : Array[String] = [
    "# EB Official Source Screen",
    "",
    "- Book: `\{book_id}`",
    "- Run: `\{run_id}`",
    "- Bond: `\{bond_code}` / `\{bond_short_name}`",
    "- As of: `\{as_of}`",
    "- Status: official source roots screened",
    "",
    "## Allowed Official Source Roots",
    "",
  ]
  for source in eb_official_source_roots() {
    lines.push("- \{source}")
  }
  lines.push("")
  lines.push("## Acceptance Rule")
  lines.push("")
  lines.push(
    "Only official-domain PDF evidence may promote accepted EB facts. Missing lifecycle stages must be marked `未检索到` with a reason.",
  )
  lines.push("")
  lines.join("\n")
}

///|
fn eb_official_source_screen_text(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
) -> String {
  [
    "book_id=\{book_id}",
    "run_id=\{run_id}",
    "bond_code=\{bond_code}",
    "bond_short_name=\{bond_short_name}",
    "as_of=\{as_of}",
    "screened_source_roots=\{eb_official_source_roots().join(", ")}",
    "live_fetch_performed=false",
  ].join("\n") +
  "\n"
}

///|
fn eb_sample_book_result_json(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  output_relative~ : String,
) -> Json {
  {
    "id": run_id,
    "kind": "eb-sample-output",
    "status": "accepted",
    "book_id": book_id,
    "run_id": run_id,
    "title": "Accepted EB sample workbook for \{bond_code} \{bond_short_name}",
    "updated_pages": json_from_string_array([
      "wiki/reviews/bookkeeper-eb-sample-run.md",
      eb_output_validation_relative_path(),
    ]),
    "outputs": json_from_string_array([output_relative]),
    "review_queued": false,
    "notify_town": true,
    "evidence_id": "EV-" + run_id,
  }
}

///|
fn eb_sample_watcher_record(
  book_id~ : String,
  run_id~ : String,
  goal_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  output_relative~ : String,
) -> Json {
  {
    "id": "watcher-" + run_id,
    "goal_id": goal_id,
    "book_id": book_id,
    "run_id": run_id,
    "decision": "Update",
    "standing_goal_decision": "update",
    "delta_score": 100,
    "checked_sources_count": 6,
    "new_sources_found": 0,
    "accepted_facts_count": 1,
    "rejected_facts_count": 0,
    "wiki_pages_changed_count": 1,
    "book_changed": true,
    "notification_required": true,
    "output_path": output_relative,
    "summary": "Moondesk validation accepted sample EB workbook for \{bond_code} \{bond_short_name}.",
  }
}

///|
fn eb_sample_run_report_markdown(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
  output_relative~ : String,
) -> String {
  [
    "# EB Sample Execution Run",
    "",
    "- Book: `\{book_id}`",
    "- Run: `\{run_id}`",
    "- Bond: `\{bond_code}` / `\{bond_short_name}`",
    "- As of: `\{as_of}`",
    "- Output: `\{output_relative}`",
    "- Decision: accepted sample output",
    "",
    "This deterministic run proves the durable Moondesk -> MoonBook output packaging path. It does not claim live official-site evidence was collected.",
    "",
  ].join("\n")
}

///|
fn eb_sample_bookkeeper_review_markdown(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
  output_relative~ : String,
) -> String {
  [
    "# Bookkeeper Review: EB Sample Output",
    "",
    "- Book: `\{book_id}`",
    "- Run: `\{run_id}`",
    "- Bond: `\{bond_code}` / `\{bond_short_name}`",
    "- Review date: `\{as_of}`",
    "- Accepted output: `\{output_relative}`",
    "- Decision: `accepted_sample_output`",
    "",
    "This review accepts only the sample packaging contract. Live source-backed EB facts still require MoonClaw official-source discovery, extraction, analysis, and Bookkeeper review before they become accepted knowledge.",
    "",
  ].join("\n")
}

///|
async fn eb_standing_goal_id_for_book(
  root : String,
  book_id : String,
) -> String {
  for goal in read_json_array_file(town_standing_goals_path(root)) {
    if json_string(goal, "target_book_id", default="") == book_id {
      let id = json_string(goal, "id", default="")
      if id != "" {
        return id
      }
    }
  }
  eb_default_goal_id_for_book(book_id)
}
