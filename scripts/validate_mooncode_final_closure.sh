#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH_DOC="${ROOT}/docs/MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md"
MOONCODE_DOC="${ROOT}/docs/MOONCODE.md"
TEST_PLAN="${ROOT}/docs/CODE_MODE_TEST_PLAN.md"
GATE="${ROOT}/scripts/phase8_migration_gates.sh"

fail() {
  echo "$1" >&2
  exit 1
}

require_text() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if ! rg -n "${pattern}" "${file}" >/dev/null; then
    fail "missing ${description} in ${file}"
  fi
}

if rg -n '^## Phase (59|[6-9][0-9]|[1-9][0-9]{2,})([[:space:]]|$)' "${ARCH_DOC}" >/tmp/moondesk-mooncode-post58-phase.$$; then
  cat /tmp/moondesk-mooncode-post58-phase.$$ >&2
  rm -f /tmp/moondesk-mooncode-post58-phase.$$
  fail "MoonCode architecture closure must not add numbered phases after Phase 58; update the finite closure checklist instead."
fi
rm -f /tmp/moondesk-mooncode-post58-phase.$$

require_text "${ARCH_DOC}" '^## Final Architecture Closure Gate$' "final architecture closure gate"
require_text "${ARCH_DOC}" 'Native command execution/result contract' "native command closure item"
require_text "${ARCH_DOC}" 'Runtime proof/evidence contract' "runtime evidence closure item"
require_text "${ARCH_DOC}" 'Closure wall' "closure wall item"
require_text "${ARCH_DOC}" 'Do-not-migrate classification' "do-not-migrate classification"
require_text "${ARCH_DOC}" 'No Phase 59 by default' "no-Phase-59 closure rule"
require_text "${ARCH_DOC}" 'No regex-only cleanup as architecture work' "regex-only cleanup guardrail"

require_text "${MOONCODE_DOC}" 'Final closure rule' "MoonCode final closure rule"
require_text "${MOONCODE_DOC}" 'native command execution/result contract' "MoonCode native command closure reference"
require_text "${MOONCODE_DOC}" 'runtime proof/evidence contract' "MoonCode runtime evidence closure reference"

require_text "${TEST_PLAN}" 'Final architecture closure gate' "code-mode final closure gate"
require_text "${TEST_PLAN}" 'validate_mooncode_final_closure.sh' "code-mode closure validator command"
require_text "${TEST_PLAN}" 'validate_mooncode_native_command_execution_contract.sh' "code-mode native command closure validator command"
require_text "${TEST_PLAN}" 'validate_mooncode_runtime_evidence_contract.sh' "code-mode runtime evidence closure validator command"

require_text "${GATE}" 'validate_mooncode_final_closure.sh' "migration-wall final closure validator"
require_text "${GATE}" 'validate_mooncode_native_command_execution_contract.sh' "migration-wall native command closure validator"
require_text "${GATE}" 'validate_mooncode_runtime_evidence_contract.sh' "migration-wall runtime evidence closure validator"

echo "MoonCode final architecture closure validation passed"
