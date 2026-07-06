#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/runtime_tools.mbt"
IMPLEMENTATION_FILES=(
  "${ROOT}/internal/mooncode/protocol_commands.mbt"
  "${ROOT}/internal/mooncode/tool_contracts.mbt"
  "${ROOT}/internal/mooncode/capabilities.mbt"
  "${ROOT}/internal/mooncode/native_command_action_metadata.mbt"
  "${ROOT}/internal/mooncode/command_tool_authorization_snapshot.mbt"
  "${ROOT}/internal/mooncode/commands.mbt"
  "${ROOT}/internal/mooncode/command_protocol.mbt"
  "${ROOT}/internal/mooncode/moonclaw_mappings.mbt"
)

required_core_symbols=(
  "runtime_tool_contract_id"
  "runtime_tool_contract_kind"
  "runtime_tool_call_contract_kind"
  "runtime_tool_read"
  "runtime_tool_edit"
  "runtime_tool_write"
  "runtime_tool_apply_patch"
  "runtime_tool_revert_patch"
  "runtime_tool_shell"
  "runtime_tool_moon_ide"
  "runtime_tool_moon_cmd"
  "runtime_tool_moon_check"
  "runtime_tool_finish"
  "runtime_tool_package_app_tool"
  "runtime_tool_glob"
  "runtime_tool_grep"
  "runtime_tool_todo_write"
  "runtime_tool_web_fetch"
  "runtime_tool_web_search"
  "runtime_tool_eval_harness"
  "runtime_tool_names"
  "runtime_tool_capability_names"
  "runtime_tool_native_required_tools"
  "runtime_tool_alias_rows"
  "runtime_tool_moonclaw_mapping_rows"
  "runtime_tool_from_moonclaw_tool"
  "runtime_tool_canonical_name"
  "runtime_tool_is_supported"
  "runtime_tool_mutates_files"
  "runtime_tool_requires_review"
  "runtime_tool_requires_authorization_snapshot"
  "runtime_tool_call_contract_json"
  "runtime_tool_contract_json"
  "runtime_tool_contract_tool_ids"
  "runtime_tool_capability_specs"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-runtime-tools-stale.$$"
if rg -n \
  '"shell", "read", "edit", "write"|"read", "edit", "write", "apply_patch"|"Bash", "shell"|"FileRead", "read"|tool_contract_entry\(|tool_field\(|tool_alias_row\(|tools\.push\("eval_harness"\)|moonclaw_tool_mapping_row\(|"Bash" => "shell"|"FileRead" \| "Read" => "read"' \
  "${IMPLEMENTATION_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode runtime tool registry ownership must come from mooncode/core, not duplicated implementation lists." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n '@mooncode_core\.runtime_tool_names\(\)' "${ROOT}/internal/mooncode/protocol_commands.mbt" >/dev/null; then
  echo "runtime_tool_names() must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_alias_rows\(\)' "${ROOT}/internal/mooncode/protocol_commands.mbt" >/dev/null; then
  echo "runtime_tool_alias_rows() must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_call_contract_json\(\)' "${ROOT}/internal/mooncode/protocol_commands.mbt" >/dev/null; then
  echo "tool_call_contract_json() must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_canonical_name\(' "${ROOT}/internal/mooncode/protocol_commands.mbt" >/dev/null; then
  echo "tool-call decoding must canonicalize tool names through mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_contract_json\(\)' "${ROOT}/internal/mooncode/tool_contracts.mbt" >/dev/null; then
  echo "tool_contract_json() must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_capability_names\(\)' "${ROOT}/internal/mooncode/capabilities.mbt" >/dev/null; then
  echo "MoonCode capability tool names must come from mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_capability_specs\(\)' "${ROOT}/internal/mooncode/capabilities.mbt" >/dev/null; then
  echo "MoonCode capability tool specs must come from mooncode/core." >&2
  exit 1
fi

if ! rg -n 'runtime_tool_native_required_tools\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability required tools must come from the core runtime tool contract." >&2
  exit 1
fi

if ! rg -n '"runtime_tool_contract": runtime_tool_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed runtime_tool_contract_json()." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_requires_authorization_snapshot\(' "${ROOT}/internal/mooncode/command_tool_authorization_snapshot.mbt" >/dev/null; then
  echo "tool authorization snapshot policy must consume mooncode/core runtime tool predicates." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_tool_sequence\(' "${ROOT}/internal/mooncode/native_command_action_metadata.mbt" >/dev/null; then
  echo "native command tool sequences must delegate to the core-owned native command contract." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_web_search\(\)' "${ROOT}/internal/mooncode/commands.mbt" >/dev/null; then
  echo "command packet web-search hints must use mooncode/core runtime tool constants." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_moonclaw_mapping_rows\(\)' "${ROOT}/internal/mooncode/moonclaw_mappings.mbt" >/dev/null; then
  echo "MoonClaw tool mapping rows must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_tool_from_moonclaw_tool\(' "${ROOT}/internal/mooncode/moonclaw_mappings.mbt" >/dev/null; then
  echo "MoonClaw tool-name normalization must delegate to mooncode/core." >&2
  exit 1
fi

echo "MoonCode runtime tool contract validation passed"
