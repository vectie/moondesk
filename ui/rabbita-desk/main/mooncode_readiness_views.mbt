///|
fn render_mooncode_readiness(model : Model) -> @rabbita.Html {
  section(class="inspector-section", [
    h3("MoonCode Readiness"),
    match selected_mooncode_session(model) {
      Some(session) => {
        let summary = session.mooncode_summary
        let readiness_audit = match model.mooncode_readiness {
          Some(readiness) =>
            if model.mooncode_readiness_session_id == session.id {
              Some(readiness)
            } else {
              None
            }
          _ => None
        }
        let readiness_json = match readiness_audit {
          Some(readiness) => readiness.readiness
          None => summary.readiness
        }
        let readiness_passed_count = match readiness_audit {
          Some(readiness) => readiness.passed_count
          None => summary.readiness_passed_check_count
        }
        let readiness_check_count = match readiness_audit {
          Some(readiness) => readiness.check_count
          None => summary.readiness_check_count
        }
        let readiness_blocked_count = match readiness_audit {
          Some(readiness) => readiness.blocked_count
          None => summary.readiness_blocked_count
        }
        let readiness_checks = match readiness_audit {
          Some(readiness) => readiness.checks
          None => summary.readiness_checks
        }
        let readiness_state = if readiness_blocked_count == 0 &&
          readiness_check_count > 0 {
          "ready"
        } else {
          "blocked"
        }
        div(class="mooncode-readiness", [
          div(class="daemon-state", [
            info_row("Protocol", summary.protocol),
            info_row("Component", summary.standalone_component),
            info_row("Dispatch", summary.dispatch_mode),
            info_row("Stream", summary.stream_url),
            info_row("Stream Mode", summary.stream_mode),
            info_row("Stream Source", summary.stream_source),
            info_row(
              "Incremental",
              if summary.incremental_stream_ready {
                summary.incremental_stream_url
              } else {
                "not ready"
              },
            ),
            info_row(
              "Live Stream",
              if summary.live_stream_ready {
                summary.live_stream_url
              } else {
                "not ready"
              },
            ),
            info_row("Stream State", summary.stream_state_url),
            info_row(
              "Append Log",
              if summary.append_log_ready {
                "\{summary.append_log_count} event(s)"
              } else {
                "empty"
              },
            ),
            info_row("Log Path", summary.event_log_path),
            info_row(
              "Command Queue",
              if summary.command_log_ready {
                "\{summary.command_log_count} command(s)"
              } else {
                "empty"
              },
            ),
            info_row("Command Path", summary.command_log_path),
            info_row(
              "Runtime Feed",
              if summary.runtime_command_feed_ready {
                "\{summary.runtime_command_count} command(s)"
              } else {
                "empty"
              },
            ),
            info_row("Runtime Path", summary.runtime_command_log_path),
            info_row(
              "Runtime Dispatch",
              if summary.runtime_dispatch_ready {
                "\{summary.runtime_dispatch_count} receipt(s)"
              } else {
                "empty"
              },
            ),
            info_row("Dispatch Path", summary.runtime_dispatch_log_path),
            info_row(
              "Session Snapshot",
              if summary.session_snapshot_ready {
                summary.session_snapshot_path
              } else {
                "missing"
              },
            ),
            info_row(
              "Eval",
              "\{summary.eval_passed_check_count}/\{summary.eval_check_count} passed, \{summary.eval_missing_check_count} missing",
            ),
            info_row(
              "Readiness",
              "\{readiness_state} (\{readiness_passed_count}/\{readiness_check_count}, \{readiness_blocked_count} blocker(s))",
            ),
            info_row(
              "Readiness Audit",
              model.mooncode_readiness_status,
            ),
            info_row(
              "Audit Endpoint",
              match readiness_audit {
                Some(readiness) => readiness.endpoint
                None => "/api/mooncode/sessions/\{session.id}/readiness"
              },
            ),
            info_row(
              "Next Readiness Action",
              json_string_value(
                readiness_json,
                "next_action",
                default="inspect_readiness_check",
              ),
            ),
            info_row(
              "Next Owner",
              json_string_value(
                readiness_json,
                "next_owner",
                default="mooncode",
              ),
            ),
            info_row(
              "First Blocker",
              json_string_value(
                readiness_json,
                "first_blocker_label",
                default="none",
              ),
            ),
            info_row(
              "Blocker Evidence",
              json_string_value(
                readiness_json,
                "first_blocker_evidence",
                default="none",
              ),
            ),
            info_row("Events", summary.event_count.to_string()),
            info_row("Transcript", summary.transcript_count.to_string()),
            info_row("Runtime", summary.runtime_count.to_string()),
            info_row("Tools", summary.tool_count.to_string()),
            info_row("Diffs", summary.diff_count.to_string()),
            info_row("Tests", summary.test_count.to_string()),
            info_row("Verified Tests", summary.verified_test_count.to_string()),
            info_row("Failed Tests", summary.failed_test_count.to_string()),
            info_row("Artifacts", summary.artifact_count.to_string()),
            info_row(
              "Source-bound Packages",
              summary.source_bound_package_count.to_string(),
            ),
            info_row(
              "Package Execution",
              "\{summary.runtime_verified_package_count} verified / \{summary.runtime_package_proof_count} proof event(s)",
            ),
            info_row(
              "Commit Execution",
              "\{summary.runtime_commit_proof_count} proof event(s)",
            ),
            info_row(
              "Steering",
              "\{summary.pending_steer_count} pending / \{summary.deferred_steer_count} deferred / \{summary.steer_settlement_count} settled",
            ),
            info_row("Review", summary.review_count.to_string()),
            info_row("Review State", summary.review_state),
            info_row("Pending Diffs", summary.pending_diff_count.to_string()),
            info_row("Accepted", summary.accepted_review_count.to_string()),
            info_row("Rejected", summary.rejected_review_count.to_string()),
            info_row(
              "Package",
              if summary.has_packaging_candidate {
                "candidate available"
              } else {
                "none yet"
              },
            ),
            info_row(
              "Manifest",
              "\{summary.moonbook_package_manifest_count} package manifest(s)",
            ),
            info_row(
              "Package Index",
              "\{summary.moonbook_package_index_manifest_count} manifest(s)",
            ),
            info_row(
              "Change Set",
              "\{summary.moonbook_change_set_manifest_count} manifest(s)",
            ),
            info_row(
              "Patch Set",
              "\{summary.moonbook_patch_set_manifest_count} manifest(s)",
            ),
            info_row(
              "Patch Execution",
              "\{summary.runtime_patch_execution_proof_count} runtime proof event(s)",
            ),
            info_row(
              "Tool Approvals",
              "\{summary.moonbook_tool_approvals_manifest_count} manifest(s), \{summary.pending_tool_approval_count} pending",
            ),
            info_row(
              "Test Runs",
              "\{summary.moonbook_test_runs_manifest_count} manifest(s)",
            ),
            info_row(
              "Eval Report",
              "\{summary.moonbook_eval_report_manifest_count} manifest(s)",
            ),
            info_row(
              "Runtime Handoff",
              "\{summary.mooncode_runtime_handoff_manifest_count} manifest(s)",
            ),
          ]),
          div(class="mooncode-output-roots", [
            small("Readiness checklist"),
            render_mooncode_eval_checks(readiness_checks),
          ]),
          div(class="mooncode-output-roots", [
            small("Eval-readiness checklist"),
            render_mooncode_eval_checks(summary.eval_checks),
          ]),
        ])
      }
      None =>
        div(class="daemon-state", [
          info_row("Protocol", "mooncode.v1"),
          info_row("Session", "none"),
        ])
    },
  ])
}

///|
fn render_mooncode_eval_checks(
  checks : Array[MoonCodeEvalCheck]
) -> @rabbita.Html {
  if checks.length() == 0 {
    p(class="status-line", "no eval checks")
  } else {
    div(
      class="mooncode-eval-list",
      checks.map(check => {
        div(
          class=if check.ok {
            "mooncode-eval-check ok"
          } else {
            "mooncode-eval-check missing"
          },
          [
            span(
              class=if check.ok { "record-kind good" } else { "record-kind" },
              if check.ok { "ok" } else { "missing" },
            ),
            div([
              strong(check.label),
              small(check.evidence),
            ]),
          ],
        )
      }),
    )
  }
}
