#!/usr/bin/env bash

MOONSUITE_PHASE8_PRODUCTS=(
  "moondesk"
  "moonbook"
  "moonwiki"
  "mooncode"
  "moonclaw"
  "moontown"
  "moongate"
  "moonfish"
  "moonmoon"
  "moonchat"
  "moonvis"
  "moonrobo"
  "bookkeeper"
  "lepusa"
  "rabbita"
)

MOONSUITE_PHASE8_SOURCE_REPOS=(
  "moonlib"
  "moondesk"
  "moonrobo"
  "moontown"
  "moonclaw"
  "moongate"
  "moonbook"
  "moonfish"
  "moonmoon"
  "moonchat"
  "moonvis"
  "lepusa"
)

MOONSUITE_PHASE8_MOONLIB_CONSUMER_REPOS=(
  "moondesk"
  "moonrobo"
  "moontown"
  "moonclaw"
  "moongate"
  "moonbook"
  "moonfish"
  "moonmoon"
  "moonchat"
  "lepusa"
)

moonsuite_phase8_repo_root() {
  local workspace_root="$1"
  local repo="$2"
  printf '%s/%s\n' "${workspace_root}" "${repo}"
}

moonsuite_phase8_require_repo() {
  local workspace_root="$1"
  local repo="$2"
  local repo_root
  repo_root="$(moonsuite_phase8_repo_root "${workspace_root}" "${repo}")"
  if [[ ! -d "${repo_root}" ]]; then
    echo "missing repo: ${repo_root}" >&2
    return 1
  fi
}
