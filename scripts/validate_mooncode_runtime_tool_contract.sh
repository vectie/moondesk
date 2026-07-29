#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/runtime_tools.mbt"
CORE_INTERFACE="${ROOT}/mooncode/core/pkg.generated.mbti"
CONSUMER_FILES=(
  "${ROOT}/internal/mooncode/adapter_capabilities.mbt"
  "${ROOT}/internal/mooncode/adapter_commands.mbt"
  "${ROOT}/internal/mooncode/adapter_json.mbt"
  "${ROOT}/internal/mooncode/adapter_protocol.mbt"
  "${ROOT}/internal/mooncode/adapter_sessions.mbt"
)
BEHAVIOR_FILES=(
  "${ROOT}/internal/mooncode/adapter_capabilities_wbtest.mbt"
  "${ROOT}/internal/mooncode/adapter_wbtest.mbt"
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
  "runtime_tool_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then echo "mooncode/core must own ${symbol}()." >&2; exit 1; fi
  if rg -n "\\b${symbol}\\b" "${CORE_INTERFACE}" >/dev/null; then echo "mooncode/core public interface must exclude raw/helper ${symbol}()." >&2; exit 1; fi
  if rg -n "@mooncode_core\\.${symbol}\\b" "${CONSUMER_FILES[@]}" >/dev/null; then echo "MoonCode adapters must not call private raw/helper ${symbol}()." >&2; exit 1; fi
done

if rg -n \
  '"checkpoint", "apply_patch", "shell", "moon_check", "finish"|"Bash", "shell"|"FileRead", "read"|tool_contract_entry\(|tool_field\(|tool_alias_row\(|tools\.push\("eval_harness"\)|moonclaw_tool_mapping_row\(|"Bash" => "shell"|"FileRead" \| "Read" => "read"' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode runtime tool ownership must come from mooncode/core, not duplicated adapter tables." >&2
  exit 1
fi

for file in "${BEHAVIOR_FILES[@]}"; do [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }; done

if ! rg -n '"runtime_tool_contract": runtime_tool_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed runtime_tool_contract_json()." >&2
  exit 1
fi

echo "MoonCode runtime tool contract validation passed"
