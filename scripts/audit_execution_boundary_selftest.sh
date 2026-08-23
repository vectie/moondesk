#!/usr/bin/env bash

set -eu

script_dir=$(cd "$(dirname "$0")" && pwd -P)
audit=$script_dir/audit_execution_boundary.sh
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/moondesk-boundary-selftest.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT HUP INT TERM

fail() {
  printf 'execution-boundary self-test: FAIL: %s\n' "$1" >&2
  exit 1
}

new_fixture() {
  fixture=$1
  mkdir -p "$fixture"
  printf 'name = "fixture"\n' >"$fixture/moon.mod"
}

expect_pass() {
  fixture=$1
  output=$fixture_root/output.txt
  "$audit" "$fixture" >"$output" 2>&1 || {
    sed -n '1,160p' "$output" >&2
    fail "expected audit to pass for $fixture"
  }
}

expect_fail_with() {
  fixture=$1
  expected=$2
  output=$fixture_root/output.txt
  if "$audit" "$fixture" >"$output" 2>&1; then
    fail "expected audit to reject $fixture"
  fi
  grep -F "$expected" "$output" >/dev/null || {
    sed -n '1,160p' "$output" >&2
    fail "missing expected diagnostic: $expected"
  }
}

# The only production exception is the closed trusted-host package.
trusted=$fixture_root/trusted
new_fixture "$trusted"
mkdir -p "$trusted/internal/trusted_host_process"
cat >"$trusted/internal/trusted_host_process/moon.pkg" <<'EOF'
import {
  "moonbitlang/async/process",
}
EOF
cat >"$trusted/internal/trusted_host_process/fixed_admin.mbt" <<'EOF'
async fn fixed_admin() -> Int {
  @process.run("/usr/bin/true", [])
}
EOF
expect_pass "$trusted"

# The exception is one package, not a namespace under which arbitrary new
# packages or generic wrappers may be hidden.
nested=$fixture_root/nested-trusted-bypass
new_fixture "$nested"
mkdir -p "$nested/internal/trusted_host_process/agent_runner"
cat >"$nested/internal/trusted_host_process/agent_runner/moon.pkg" <<'EOF'
import {
  "moonbitlang/async/process",
}
EOF
expect_fail_with "$nested" 'internal/trusted_host_process/agent_runner/moon.pkg:2'

trusted_generic=$fixture_root/trusted-generic-helper
new_fixture "$trusted_generic"
mkdir -p "$trusted_generic/internal/trusted_host_process"
cat >"$trusted_generic/internal/trusted_host_process/moon.pkg" <<'EOF'
import {
  "moonbitlang/async/process",
}
EOF
cat >"$trusted_generic/internal/trusted_host_process/process_helpers.mbt" <<'EOF'
async fn run_process_capture(command : String) -> Int {
  @process.run(command, [])
}
EOF
expect_fail_with "$trusted_generic" 'trusted-host-generic-authority'

# A newly introduced package cannot bypass the audit through discovery gaps.
bypass=$fixture_root/new-package-bypass
new_fixture "$bypass"
mkdir -p "$bypass/features/agent_runner"
cat >"$bypass/features/agent_runner/moon.pkg" <<'EOF'
import {
  "moonbitlang/async/process",
}
EOF
cat >"$bypass/features/agent_runner/run.mbt" <<'EOF'
async fn run_agent_payload(command : String) -> Int {
  @process.run(command, [])
}
EOF
expect_fail_with "$bypass" 'features/agent_runner/moon.pkg:2'
expect_fail_with "$bypass" 'features/agent_runner/run.mbt:2'

json_bypass=$fixture_root/new-json-package-bypass
new_fixture "$json_bypass"
mkdir -p "$json_bypass/features/json_agent_runner"
cat >"$json_bypass/features/json_agent_runner/moon.pkg.json" <<'EOF'
{
  "import": [
    "moonbitlang/async/process"
  ]
}
EOF
expect_fail_with "$json_bypass" 'features/json_agent_runner/moon.pkg.json:3'

json_test_only=$fixture_root/json-test-only
new_fixture "$json_test_only"
mkdir -p "$json_test_only/internal/example"
cat >"$json_test_only/internal/example/moon.pkg.json" <<'EOF'
{
  "import": [
    "moonbitlang/core/string"
  ],
  "wbtest-import": [
    "moonbitlang/async/process"
  ]
}
EOF
expect_pass "$json_test_only"

# Preserve a regression fixture for MoonDesk's current package-wide generic
# helper. Hiding @process behind a helper must not make authority disappear.
generic=$fixture_root/generic-process-helper
new_fixture "$generic"
mkdir -p "$generic/internal/moonwiki"
cat >"$generic/internal/moonwiki/moon.pkg" <<'EOF'
import {
  "moonbitlang/async/process",
}
EOF
cat >"$generic/internal/moonwiki/process_helpers.mbt" <<'EOF'
async fn run_process_capture(cmd : String) -> Int {
  @process.run(cmd, [])
}
EOF
expect_fail_with "$generic" 'internal/moonwiki/process_helpers.mbt:1'
expect_fail_with "$generic" 'generic-process-helper'

# Test-only authority does not grant a production package process access.
test_only=$fixture_root/test-only
new_fixture "$test_only"
mkdir -p "$test_only/internal/example"
cat >"$test_only/internal/example/moon.pkg" <<'EOF'
import {
  "moonbitlang/core/string",
}
import {
  "moonbitlang/async/process",
} for "wbtest"
EOF
cat >"$test_only/internal/example/process_wbtest.mbt" <<'EOF'
test "fixture" {
  inspect!(@process.run("/usr/bin/true", []), content="0")
}
EOF
expect_pass "$test_only"

printf 'MoonDesk execution-boundary self-test: PASS\n'
