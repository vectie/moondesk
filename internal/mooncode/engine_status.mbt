///|
pub fn engine_check_json(
  id : String,
  label : String,
  status : String,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "status": status, "evidence": evidence }
}

///|
pub fn engine_status_projection_json(
  daemon~ : Json,
  moonclaw_root~ : String,
  checkout_ready~ : Bool,
  running~ : Bool,
  models_ready~ : Bool,
  runtime_contract_ready~ : Bool,
  model_evidence~ : String,
  runtime_evidence~ : String,
) -> Json {
  let ready = running && runtime_contract_ready
  let runtime_readiness = moonclaw_runtime_readiness(
    running, runtime_contract_ready,
  )
  let runtime_status = json_string(
    runtime_readiness,
    "status",
    default="missing-runtime",
  )
  let status = if ready {
    "native-ready"
  } else if running {
    "native-runtime-missing"
  } else if checkout_ready {
    "daemon-not-running"
  } else {
    "moonclaw-service-missing"
  }
  {
    "ok": ready,
    "status": status,
    "ready": ready,
    "runtime_mode": if runtime_contract_ready {
      "native-mooncode-runtime"
    } else {
      "runtime-unavailable"
    },
    "native_runtime_ready": runtime_contract_ready,
    "runtime_status": runtime_status,
    "moonclaw_runtime": runtime_readiness,
    "moonclaw_root": moonclaw_root,
    "message": json_string(daemon, "message", default=""),
    "daemon": daemon,
    "supported_endpoints": string_array_json(supported_engine_endpoints()),
    "checks": [
      engine_check_json(
        "moonclaw_service",
        "MoonClaw service",
        if checkout_ready {
          "ready"
        } else {
          "missing"
        },
        if checkout_ready {
          moonclaw_root
        } else {
          "no MoonClaw service descriptor found; configure .moonsuite/products/moonclaw/service.json"
        },
      ),
      engine_check_json(
        "daemon_running",
        "MoonClaw daemon",
        if running {
          "ready"
        } else {
          "missing"
        },
        json_string(daemon, "message", default="MoonClaw daemon is not running"),
      ),
      engine_check_json(
        "model_api",
        "Model API",
        if models_ready {
          "ready"
        } else if running {
          "missing"
        } else {
          "blocked"
        },
        model_evidence,
      ),
      engine_check_json(
        "prompt_message_cancel",
        "Prompt/steer/cancel runtime",
        if runtime_contract_ready {
          "ready"
        } else {
          "missing"
        },
        if runtime_contract_ready {
          "Moondesk sends prompt/steer/cancel/test/package/review commands through /v1/code/sessions/<id>/commands"
        } else {
          "Native /v1/code command ingestion is required before MoonCode can run coding work."
        },
      ),
      engine_check_json(
        "append_only_session_log", "Append-only session log", "ready", "MoonClaw owns book-local .moonclaw/mooncode/sessions/<session-id>/events.jsonl sidecars and exposes /v1/code/sessions?book_root=<path> for cold discovery; Moondesk stores only desktop projection records",
      ),
      engine_check_json(
        "append_only_command_queue", "Append-only command queue", "ready", "MoonClaw owns book-local .moonclaw/mooncode/sessions/<session-id>/commands.jsonl sidecars and reports command counts from the native session show endpoint; Moondesk stores only desktop projection records",
      ),
      engine_check_json(
        "typed_runtime_contract",
        "Typed MoonCode runtime contract",
        if runtime_contract_ready {
          "ready"
        } else {
          "missing"
        },
        runtime_evidence,
      ),
      engine_check_json(
        "moonclaw_runtime",
        "MoonClaw runtime",
        if runtime_status == "native-ready" {
          "ready"
        } else {
          "missing"
        },
        "runtime=\{runtime_status}; consumes native MoonClaw MoonCode runtime events",
      ),
      engine_check_json(
        "eval_harness_evidence", "MoonCode eval evidence", "partial", "MoonClaw native eval readiness now requires tool_harness, file_edit, patch_review, command_execution, and package_output proof. Shippable behavior still needs broader model-backed coding eval cases for live steering, diff-review decisions, and long-running resume/cancel workflows.",
      ),
    ],
  }
}

///|
fn supported_engine_endpoints() -> Array[String] {
  engine_supported_endpoints()
}
