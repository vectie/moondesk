///|
pub fn protocol_version() -> String {
  "mooncode.v1"
}

///|
pub fn native_capability_contract_id() -> String {
  "mooncode-native-capability-surface.v1"
}

///|
pub fn native_capability_required_endpoints() -> Array[String] {
  [
    "/v1/code/capabilities", "/v1/code/sessions?book_root=<path>", "/v1/code/sessions?book_root=<path>&format=json",
    "/v1/code/sessions/<id>?book_root=<path>", "/v1/code/sessions/<id>/commands",
    "/v1/code/sessions/<id>/runtime-control?book_root=<path>", "/v1/code/sessions/<id>/runtime-claim?book_root=<path>",
    "/v1/code/sessions/<id>/stream?book_root=<path>&format=jsonl|sse&since=<n>&wait_ms=<ms>&poll_ms=<ms>",
    "/v1/code/sessions/<id>/runtime-turn?book_root=<path>", "/v1/code/sessions/<id>/runtime-loop?book_root=<path>",
    "/v1/code/sessions/<id>/runtime-service?book_root=<path>", "/v1/code/sessions/<id>/runtime-events?book_root=<path>",
    "/v1/code/sessions/<id>/tool-exec?book_root=<path>", "/v1/code/sessions/<id>/eval-report?book_root=<path>",
    "/v1/code/sessions/<id>/package-result?book_root=<path>",
  ]
}

///|
pub fn native_capability_required_tools() -> Array[String] {
  [
    "read", "edit", "write", "apply_patch", "revert_patch", "shell", "moon_ide",
    "moon_cmd", "moon_check", "finish",
  ]
}

///|
pub fn native_command_body_required_fields() -> Array[String] {
  ["protocol", "session_id", "book_root", "packet"]
}

///|
pub fn native_command_body_supported_fields() -> Array[String] {
  [
    "protocol", "command", "text", "model", "session_id", "book_root", "context_path",
    "payload", "packet", "execution_plan", "tool_authorization", "tool_contract",
    "result_contract", "owner", "web_search", "runtime_tool_calls", "deferred_steering",
  ]
}

///|
pub fn native_command_body_field_is_supported(name : String) -> Bool {
  native_command_body_supported_fields().contains(name)
}

///|
pub fn native_capability_runtime_loop_options() -> Json {
  {
    "live_wait_ms": {
      "default": 0,
      "min": 0,
      "max": 30000,
      "purpose": "Opt-in bounded wait for new prompt, steer, or cancel commands before the native runtime loop returns idle.",
    },
    "poll_ms": {
      "default": 250,
      "min": 25,
      "max": 2000,
      "purpose": "Polling interval while live_wait_ms is active.",
    },
    "idle_semantics": "When live_wait_ms is zero, runtime-loop preserves immediate idle behavior; when positive, it polls commands.jsonl until a claimable command appears or the wait budget expires.",
  }
}

///|
pub fn native_capability_stream_options() -> Json {
  {
    "wait_ms": {
      "default": 0,
      "min": 0,
      "max": 30000,
      "purpose": "Opt-in bounded long-poll wait for new durable MoonCode events after the requested stream sequence.",
    },
    "poll_ms": {
      "default": 100,
      "min": 25,
      "max": 2000,
      "purpose": "Polling interval while wait_ms is active.",
    },
    "snapshot_semantics": "When wait_ms is zero, stream preserves immediate replay behavior; when positive, it polls events.jsonl until a sequence newer than since appears or the wait budget expires.",
  }
}

///|
fn native_capability_surface_fingerprint_source() -> String {
  let required_endpoints = native_capability_required_endpoints().join("\n")
  let required_tools = native_capability_required_tools().join("\n")
  let command_body_required_fields = native_command_body_required_fields().join(
    "\n",
  )
  let command_body_supported_fields = native_command_body_supported_fields().join(
    "\n",
  )
  let loop_options = native_capability_runtime_loop_options().stringify()
  let stream_options = native_capability_stream_options().stringify()
  [
    "kind=mooncode-native-capability-surface",
    "component=mooncode",
    "protocol=\{protocol_version()}",
    "capability_contract_id=\{native_capability_contract_id()}",
    "required_endpoints=\{required_endpoints}",
    "required_tools=\{required_tools}",
    "command_body_required_fields=\{command_body_required_fields}",
    "command_body_supported_fields=\{command_body_supported_fields}",
    "runtime_loop_options=\{loop_options}",
    "stream_options=\{stream_options}",
  ].join("\n")
}

///|
pub fn native_capability_surface_fingerprint() -> String {
  @crypto.bytes_to_hex_string(
    @crypto.sha256(
      @encoding/utf8.encode(native_capability_surface_fingerprint_source()).to_fixedarray(),
    ),
  )
}

///|
pub fn native_capability_surface_json() -> Json {
  {
    "kind": "mooncode-native-capability-surface",
    "component": "mooncode",
    "protocol": protocol_version(),
    "capability_contract_id": native_capability_contract_id(),
    "capability_surface_fingerprint": native_capability_surface_fingerprint(),
    "required_endpoints": native_capability_required_endpoints(),
    "required_tools": native_capability_required_tools(),
    "command_body_required_fields": native_command_body_required_fields(),
    "command_body_supported_fields": native_command_body_supported_fields(),
    "runtime_loop_options": native_capability_runtime_loop_options(),
    "stream_options": native_capability_stream_options(),
  }
}

///|
pub fn standalone_boundary_json() -> Json {
  {
    "kind": "mooncode-standalone-boundary",
    "protocol": protocol_version(),
    "core_package": "mooncode/core",
    "projection_component": "mooncode.projection",
    "host_component": "moonwiki.host",
    "runtime_component": "moonclaw.standalone-runtime",
    "runtime_substrate": "moonclaw.shared-runtime",
    "lanes": [
      {
        "id": "mooncode-coding-lane",
        "owner": "mooncode",
        "responsibility": "Executable-book coding turns, diffs, tests, packages, and proof artifacts over the shared MoonClaw runtime substrate.",
      },
      {
        "id": "moonwiki-book-lane",
        "owner": "moonwiki",
        "responsibility": "Human-language book edits and review workflows that may call MoonClaw by protocol without becoming the coding lane.",
      },
      {
        "id": "moonclaw-task-lane",
        "owner": "moonclaw",
        "responsibility": "Generic bounded background jobs kept separate from MoonCode sessions.",
      },
    ],
    "roles": [
      {
        "id": "mooncode-core",
        "owner": "mooncode",
        "responsibility": "Stable protocol ids, native MoonCode capability surface, standalone boundary, and cross-project contracts without host, UI, or runtime implementation dependencies.",
      },
      {
        "id": "mooncode-projection",
        "owner": "host-shell",
        "responsibility": "Book-scoped command, event, stream, review, runtime, test, package, and eval projections used by a host shell.",
      },
      {
        "id": "moonwiki-host",
        "owner": "moonwiki",
        "responsibility": "HTTP or local routes plus MoonBook file persistence for wiki/reviews/mooncode and durable MoonCode session sidecars.",
      },
      {
        "id": "moonclaw-standalone-runtime",
        "owner": "moonclaw",
        "responsibility": "Standalone shared runtime substrate for agent sessions, model calls, tool execution, cancellation, event streams, durable coding sessions, tests/builds, package result production, and generic task jobs.",
      },
    ],
    "rules": [
      "mooncode/core must contain only stable protocol and capability contracts",
      "projection components may import mooncode/core but must remain UI-free", "host components may persist and route MoonCode records but must not own the coding runtime loop",
      "MoonClaw must remain usable as a standalone agent runtime outside Moondesk",
      "MoonCode, MoonWiki, and generic tasks share MoonClaw runtime primitives but keep separate typed protocols",
      "runtime engines must own tool execution and runtime sessions behind the MoonCode contract",
    ],
  }
}
