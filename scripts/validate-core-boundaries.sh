#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
moondesk_root="$(cd "${script_dir}/.." && pwd)"
moon_bin="${MOON:-/Users/kq/.moon/bin/moon}"
moonclaw_root="${MOONCLAW_ROOT:-${moondesk_root}/../moonclaw}"
moonbook_root="${MOONBOOK_ROOT:-${moondesk_root}/../moonbook}"
moontown_root="${MOONTOWN_ROOT:-${moondesk_root}/../moontown}"

run_moon() {
  local root="$1"
  shift
  echo "+ (cd ${root} && ${moon_bin} $*)"
  (cd "${root}" && "${moon_bin}" "$@")
}

run_if_package_exists() {
  local root="$1"
  local package="$2"
  shift 2
  if [[ -f "${root}/${package}/moon.pkg" ]]; then
    run_moon "${root}" "$@" "${package}" --target native --warn-list +73 --diagnostic-limit 80
  else
    echo "skip: ${root}/${package}/moon.pkg not found"
  fi
}

validate_no_builtin_domain_pack() {
  local root="$1"
  local pattern='(^|/)[[:alnum:]]+_(contract_verification|generated_scripts|lifecycle_contracts|moonclaw_contracts|moonclaw_flow|output_contracts|output_validation|prompt_contracts|reconciliation|result_records|run_health|runtime_refresh|workbook_artifacts)(_wbtest)?\.mbt$|(^|/)[[:alnum:]-]+-domain-pack'
  local stale_example_pattern='(^|[^[:alnum:]_])EB([^[:alnum:]_]|$)|exchangeable|可交换|1320[0-9]{2}|1172[0-9]{2}|G三峡|江铜'
  local scan_paths=(
    README.md
    README.mbt.md
    docs
    adapters
    cmd
    core
    host
    internal
    mooncode
    plugin
    ui/rabbita-desk/main
  )

  echo "+ validate no built-in domain pack residue"
  while IFS= read -r candidate; do
    [[ -n "${candidate}" ]] || continue
    if [[ "${candidate}" =~ ${pattern} ]]; then
      echo "${candidate}" >&2
      echo "Domain experiment residue found in Moondesk core." >&2
      echo "Move domain-specific workflows into standalone MoonBook/MoonClaw packs." >&2
      exit 1
    fi
  done < <(
    cd "${root}" &&
      {
        git ls-files "${scan_paths[@]}"
        git ls-files --others --exclude-standard "${scan_paths[@]}"
      }
  )

  if (cd "${root}" && rg -n --hidden --glob '!**/dist/**' --glob '!**/.moon/**' --glob '!**/.git/**' "${stale_example_pattern}" "${scan_paths[@]}"); then
    echo "Stale market-specific example data found in Moondesk core." >&2
    echo "Keep generated discovery examples in standalone app-tool packs, not in Moondesk." >&2
    exit 1
  fi
}

validate_moonbook_moonwiki_boundary() {
  local root="$1"
  local pattern='internal/httpserve|@httpserve|package "vectie/moonbook/internal/httpserve"'
  local scan_paths=(
    README.md
    README.mbt.md
    cmd
    docs
    internal
    wiki
  )

  echo "+ validate MoonBook MoonWiki package boundary"
  if (cd "${root}" && rg -n --hidden --glob '!**/_build/**' --glob '!**/.mooncakes/**' --glob '!**/.git/**' "${pattern}" "${scan_paths[@]}"); then
    echo "Old MoonBook httpserve package references found." >&2
    echo "Use internal/moonwiki for the human-language book surface." >&2
    exit 1
  fi
}

validate_provider_runtime_boundary() {
  local moonbook="$1"
  local moontown="$2"
  local pattern='provider-task bridge|provider-task target name|provider-task target named|MoonBook provider-task'

  echo "+ validate provider runtime boundary wording"
  if rg -n --hidden --glob '!**/_build/**' --glob '!**/.mooncakes/**' --glob '!**/.git/**' "${pattern}" \
    "${moonbook}/README.md" \
    "${moonbook}/README.mbt.md" \
    "${moonbook}/docs" \
    "${moonbook}/wiki" \
    "${moonbook}/seed/wiki/skills" \
    "${moontown}/src/adapters/moonbook"; then
    echo "MoonBook/Moontown provider boundary still uses provider-task bridge wording." >&2
    echo "Use provider runtime wording outside MoonClaw's internal provider-task engine." >&2
    exit 1
  fi
}

validate_moonclaw_code_boundary() {
  local root="$1"
  local forbidden='OpenSeek|openseek|wire compatibility|/v1/mooncode|serve-scheduler|serve_scheduler|MoonCode-style|runtime-dispatch|runtime_dispatch|RuntimeDispatch|mooncode\.runtime-dispatch|mooncode-runtime-dispatch|bridge_mode|runtime_dispatch_endpoint|dispatch_mode|mooncode_dispatch_mode|native_dispatch_mode|native_runtime_mode|task_runtime_receipt_mode|previous_dispatch_status|previous_dispatch_failed|previous_dispatch_receipt|failed_dispatch_count|dispatched_count|native-dispatched|not-dispatched|unsupported-dispatch-mode|runtime/serve|native MoonCode dispatch|mooncode_command_dispatch|command_dispatch|command-dispatch|dispatch_source|hunk_dispatch_scope|dispatch_or_replay_runtime_commands'
  local scan_paths=(
    docs
    cmd/daemon
    job
    cmd/daemon/README.md
  )
  local boundary_doc="${root}/docs/executable_book_runtime_boundary.md"

  echo "+ validate MoonClaw MoonCode boundary wording"
  if (cd "${root}" && rg -n --hidden --glob '!**/_build/**' --glob '!**/.git/**' "${forbidden}" "${scan_paths[@]}"); then
    echo "MoonClaw docs still reference external coding-agent compatibility vocabulary or old MoonCode routes." >&2
    echo "Use standalone MoonCode runtime wording and the /v1/code/* route family." >&2
    exit 1
  fi
  if ! rg -q 'MoonCode should not be implemented as generic task chat' "${boundary_doc}"; then
    echo "MoonClaw executable-book boundary must state that MoonCode is not generic task chat." >&2
    exit 1
  fi
  if ! rg -q '/v1/code/\*' "${boundary_doc}"; then
    echo "MoonClaw executable-book boundary must name /v1/code/* as the coding route family." >&2
    exit 1
  fi
  if ! rg -q 'MoonClaw standalone agent runtime' "${boundary_doc}"; then
    echo "MoonClaw executable-book boundary must name MoonClaw as a standalone agent runtime." >&2
    exit 1
  fi
  if ! rg -q 'shared runtime substrate' "${boundary_doc}"; then
    echo "MoonClaw executable-book boundary must define the shared runtime substrate." >&2
    exit 1
  fi
}

validate_moondesk_code_runtime_boundary() {
  local root="$1"
  local forbidden='moonclaw_adapter|adapter_status|mooncode-moonclaw-adapter|native_gap|wire compatibility|/v1/mooncode|serve-scheduler|serve_scheduler|serve-jsonl|serve_command|MoonCode-style|runtime-dispatch|runtime_dispatch|RuntimeDispatch|mooncode\.runtime-dispatch|mooncode-runtime-dispatch|OpenSeek|openseek|runtime_dispatch_endpoint|dispatch_mode|mooncode_dispatch_mode|native_dispatch_mode|native_runtime_mode|task_runtime_receipt_mode|previous_dispatch_status|previous_dispatch_failed|previous_dispatch_receipt|failed_dispatch_count|dispatched_count|native-dispatched|not-dispatched|unsupported-dispatch-mode|runtime/serve|native MoonCode dispatch|mooncode_command_dispatch|command_dispatch|command-dispatch|dispatch_source|hunk_dispatch_scope|dispatch_or_replay_runtime_commands'
  local scan_paths=(
    docs
    internal/mooncode
    internal/moonwiki
    mooncode/core
    ui/rabbita-desk/main
  )

  echo "+ validate Moondesk MoonCode runtime wording"
  if (cd "${root}" && rg -n --hidden --glob '!**/dist/**' --glob '!**/_build/**' --glob '!**/.git/**' "${forbidden}" "${scan_paths[@]}"); then
    echo "Moondesk still exposes compatibility or adapter-era MoonCode vocabulary." >&2
    echo "Use native MoonClaw runtime wording and the /v1/code/* route family." >&2
    exit 1
  fi
  if ! rg -q 'Shared Runtime, Separate Lanes' "${root}/docs/MOONCODE.md"; then
    echo "Moondesk MoonCode docs must describe the shared runtime and separate lane boundary." >&2
    exit 1
  fi
  if ! rg -q 'MoonClaw must remain a standalone agent runtime' "${root}/docs/MOONCODE.md"; then
    echo "Moondesk MoonCode docs must keep MoonClaw standalone, not desktop-private." >&2
    exit 1
  fi
}

validate_mooncode_core_contract_neutral() {
  local root="$1"
  local pattern='vectie/moondesk|internal/mooncode|internal/moonwiki|\.\./moonclaw'
  local scan_paths=(
    mooncode/core/protocol.mbt
    mooncode/core/moon.pkg
  )

  echo "+ validate MoonCode core contract neutrality"
  if (cd "${root}" && rg -n --hidden --glob '!**/_build/**' --glob '!**/.git/**' "${pattern}" "${scan_paths[@]}"); then
    echo "MoonCode core still names host/runtime source paths." >&2
    echo "Keep mooncode/core extractable; host-specific package paths belong in host projections." >&2
    exit 1
  fi
}

validate_moontown_moonclaw_runtime_boundary() {
  local root="$1"
  local forbidden='moonclaw_adapter'
  local scan_paths=(
    src/adapters/moonclaw
    src/moonclaw_runtime
    docs
  )

  echo "+ validate Moontown MoonClaw runtime wording"
  if (cd "${root}" && rg -n --hidden --glob '!**/_build/**' --glob '!**/.git/**' "${forbidden}" "${scan_paths[@]}"); then
    echo "Moontown still exposes MoonClaw adapter-era helper names." >&2
    echo "Use MoonClaw runtime wording for scheduler/execution integration." >&2
    exit 1
  fi
}

require_repo() {
  local root="$1"
  local name="$2"
  if [[ ! -f "${root}/moon.mod" && ! -f "${root}/moon.mod.json" ]]; then
    echo "${name} checkout not found at ${root}" >&2
    echo "Set the corresponding *_ROOT variable to the checkout path or place it next to Moondesk." >&2
    exit 2
  fi
}

require_repo "${moondesk_root}" "moondesk"
require_repo "${moonclaw_root}" "moonclaw"
require_repo "${moonbook_root}" "moonbook"
require_repo "${moontown_root}" "moontown"

validate_no_builtin_domain_pack "${moondesk_root}"
validate_moonbook_moonwiki_boundary "${moonbook_root}"
validate_provider_runtime_boundary "${moonbook_root}" "${moontown_root}"
validate_moonclaw_code_boundary "${moonclaw_root}"
validate_moondesk_code_runtime_boundary "${moondesk_root}"
validate_mooncode_core_contract_neutral "${moondesk_root}"
validate_mooncode_core_contract_neutral "${moonclaw_root}"
validate_moontown_moonclaw_runtime_boundary "${moontown_root}"
"${script_dir}/verify-mooncode-core-sync.sh"

run_if_package_exists "${moondesk_root}" "mooncode/core" test
run_if_package_exists "${moondesk_root}" "internal/mooncode" test
run_if_package_exists "${moondesk_root}" "internal/moonwiki" test

run_if_package_exists "${moonclaw_root}" "mooncode/core" test
run_if_package_exists "${moonclaw_root}" "cmd/daemon" test

run_if_package_exists "${moonbook_root}" "core" check
run_if_package_exists "${moonbook_root}" "cmd/main" check
run_if_package_exists "${moonbook_root}" "internal/moonwiki" check
run_if_package_exists "${moonbook_root}" "wiki" check
run_if_package_exists "${moonbook_root}" "summary" check

run_if_package_exists "${moontown_root}" "src/core" check
run_if_package_exists "${moontown_root}" "src/adapters/moonbook" test
run_if_package_exists "${moontown_root}" "src/moonbook_contracts" check
run_if_package_exists "${moontown_root}" "src/standing_watch_contracts" check
run_if_package_exists "${moontown_root}" "src/pdf_evidence_watch" check
run_if_package_exists "${moontown_root}" "src/moonclaw_runtime" check

echo "Core boundary validation passed."
