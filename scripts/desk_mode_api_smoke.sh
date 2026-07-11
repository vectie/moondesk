#!/usr/bin/env bash
set -euo pipefail

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/moondesk-desk-smoke.XXXXXX")"
NORMALIZED_ROOT="$(python3 -c 'import os, sys; print(os.path.normpath(sys.argv[1]))' "${ROOT}")"
PORT="${PORT:-$((4300 + RANDOM % 1000))}"
SOURCE_PORT="${SOURCE_PORT:-$((6500 + RANDOM % 1000))}"
HOST="127.0.0.1"
BASE="http://${HOST}:${PORT}"
SOURCE_BASE="http://${HOST}:${SOURCE_PORT}"
BOOK_ID="research-desk-smoke"
WORKSPACE_ID="book-research-desk-smoke"
BOOK_ROOT="${ROOT}/books/${BOOK_ID}"
EMPTY_ID="research-empty-desk"
EMPTY_WORKSPACE_ID="book-research-empty-desk"
EMPTY_ROOT="${ROOT}/books/${EMPTY_ID}"
LARGE_ID="research-large-desk"
LARGE_WORKSPACE_ID="book-research-large-desk"
LARGE_ROOT="${ROOT}/books/${LARGE_ID}"
DEEP_ID="research-deep-desk"
DEEP_WORKSPACE_ID="book-research-deep-desk"
DEEP_ROOT="${ROOT}/books/${DEEP_ID}"
PLAIN_ROOT="${ROOT}/plain-folder"
IMPORT_SOURCE="${ROOT}/external-import-source"
ARCHIVE_SOURCE="${ROOT}/external-archive-source"
ARCHIVE_PATH="${ROOT}/external-archive-source.zip"
UPLOAD_ARCHIVE_SOURCE="${ROOT}/external-upload-archive-source"
UPLOAD_ARCHIVE_PATH="${ROOT}/external-upload-archive-source.zip"
SOURCE_ROOT="${ROOT}/source-checkout"
DEDICATED_ROOT="${ROOT}/dedicated-workspace"
NORMALIZED_SOURCE_ROOT="$(python3 -c 'import os, sys; print(os.path.normpath(sys.argv[1]))' "${SOURCE_ROOT}")"
NORMALIZED_DEDICATED_ROOT="$(python3 -c 'import os, sys; print(os.path.normpath(sys.argv[1]))' "${DEDICATED_ROOT}")"
LOG="${ROOT}/server.log"
SOURCE_LOG="${ROOT}/source-root-server.log"
PID=""
SOURCE_PID=""

cleanup() {
  if [[ -n "${SOURCE_PID}" ]] && kill -0 "${SOURCE_PID}" 2>/dev/null; then
    kill "${SOURCE_PID}" 2>/dev/null || true
    wait "${SOURCE_PID}" 2>/dev/null || true
  fi
  if [[ -n "${PID}" ]] && kill -0 "${PID}" 2>/dev/null; then
    kill "${PID}" 2>/dev/null || true
    wait "${PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

mkdir -p \
  "${BOOK_ROOT}/wiki/notes" \
  "${BOOK_ROOT}/raw/nested" \
  "${BOOK_ROOT}/book/site/generated/assets" \
  "${BOOK_ROOT}/images" \
  "${BOOK_ROOT}/docs with spaces" \
  "${BOOK_ROOT}/odd [chars] % dir" \
  "${BOOK_ROOT}/.git" \
  "${EMPTY_ROOT}" \
  "${LARGE_ROOT}/raw/large" \
  "${DEEP_ROOT}/raw/level-01/level-02/level-03/level-04/level-05/level-06/level-07/level-08/level-09/level-10" \
  "${PLAIN_ROOT}/wiki" \
  "${IMPORT_SOURCE}/wiki" \
  "${IMPORT_SOURCE}/raw" \
  "${IMPORT_SOURCE}/.git" \
  "${ARCHIVE_SOURCE}/wiki" \
  "${ARCHIVE_SOURCE}/raw" \
  "${ARCHIVE_SOURCE}/node_modules/cache" \
  "${ARCHIVE_SOURCE}/__MACOSX" \
  "${UPLOAD_ARCHIVE_SOURCE}/wiki" \
  "${UPLOAD_ARCHIVE_SOURCE}/raw" \
  "${SOURCE_ROOT}"

printf '<main>MoonDesk smoke UI</main>\n' >"${ROOT}/index.html"
printf '{"name":"Desk Smoke"}\n' >"${BOOK_ROOT}/book.json"
printf '{"name":"Empty Desk"}\n' >"${EMPTY_ROOT}/book.json"
printf '{"name":"Large Desk"}\n' >"${LARGE_ROOT}/book.json"
printf '{"name":"Deep Desk"}\n' >"${DEEP_ROOT}/book.json"
printf '# Plain\n' >"${PLAIN_ROOT}/wiki/index.md"
printf '{"id":"imported-desk-smoke","name":"Imported Desk Smoke"}\n' >"${IMPORT_SOURCE}/book.json"
printf '# Imported Desk Smoke\n\ncopied into library\n' >"${IMPORT_SOURCE}/wiki/index.md"
printf 'import evidence\n' >"${IMPORT_SOURCE}/raw/evidence.txt"
printf 'skip config\n' >"${IMPORT_SOURCE}/.git/config"
printf '{"id":"archived-desk-smoke","name":"Archived Desk Smoke"}\n' >"${ARCHIVE_SOURCE}/book.json"
printf '# Archived Desk Smoke\n\nimported from zip\n' >"${ARCHIVE_SOURCE}/wiki/index.md"
printf 'archive evidence\n' >"${ARCHIVE_SOURCE}/raw/evidence.txt"
printf 'skip dependency cache\n' >"${ARCHIVE_SOURCE}/node_modules/cache/file.txt"
printf 'skip mac metadata\n' >"${ARCHIVE_SOURCE}/__MACOSX/._book.json"
python3 -c 'import pathlib, sys, zipfile
source = pathlib.Path(sys.argv[1])
archive_path = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(archive_path, "w") as archive:
    for path in sorted(source.rglob("*")):
        archive.write(path, pathlib.Path(source.name) / path.relative_to(source))
' "${ARCHIVE_SOURCE}" "${ARCHIVE_PATH}"
printf '{"id":"uploaded-desk-smoke","name":"Uploaded Desk Smoke"}\n' >"${UPLOAD_ARCHIVE_SOURCE}/book.json"
printf '# Uploaded Desk Smoke\n\nimported from picked archive\n' >"${UPLOAD_ARCHIVE_SOURCE}/wiki/index.md"
printf 'uploaded archive evidence\n' >"${UPLOAD_ARCHIVE_SOURCE}/raw/evidence.txt"
python3 -c 'import pathlib, sys, zipfile
source = pathlib.Path(sys.argv[1])
archive_path = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(archive_path, "w") as archive:
    for path in sorted(source.rglob("*")):
        archive.write(path, pathlib.Path(source.name) / path.relative_to(source))
' "${UPLOAD_ARCHIVE_SOURCE}" "${UPLOAD_ARCHIVE_PATH}"
printf '# Desk Smoke\n\nhello explorer\n' >"${BOOK_ROOT}/wiki/index.md"
printf 'alpha note\n' >"${BOOK_ROOT}/wiki/notes/alpha.md"
printf 'evidence smoke\n' >"${BOOK_ROOT}/raw/nested/evidence.txt"
printf '<html><link rel="stylesheet" href="assets/site.css"><body>generated</body></html>\n' >"${BOOK_ROOT}/book/site/generated/index.html"
printf 'body { color: black; }\n' >"${BOOK_ROOT}/book/site/generated/assets/site.css"
printf 'png-bytes' >"${BOOK_ROOT}/images/logo.png"
printf '# Encoded\n\npath survives\n' >"${BOOK_ROOT}/docs with spaces/encoded # name.md"
printf '# Odd\n\nquery chars survive\n' >"${BOOK_ROOT}/odd [chars] % dir/file ? name %.md"
printf 'hidden config\n' >"${BOOK_ROOT}/.git/config"
printf 'mac noise\n' >"${BOOK_ROOT}/.DS_Store"
printf 'outside secret\n' >"${ROOT}/outside.txt"
printf 'deep final\n' >"${DEEP_ROOT}/raw/level-01/level-02/level-03/level-04/level-05/level-06/level-07/level-08/level-09/level-10/final.txt"
printf 'name = "source/checkout"\n' >"${SOURCE_ROOT}/moon.mod"

for index in $(seq -w 1 300); do
  printf 'large %s\n' "${index}" >"${LARGE_ROOT}/raw/large/item-${index}.txt"
done

MOONDESK_WORKSPACE_ROOT="${DEDICATED_ROOT}" moon run cmd/main -- serve "${SOURCE_ROOT}" --ui ui/rabbita-desk/dist --host "${HOST}" --port "${SOURCE_PORT}" >"${SOURCE_LOG}" 2>&1 &
SOURCE_PID="$!"

for _ in {1..200}; do
  if curl -fsS "${SOURCE_BASE}/__moondesk_health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if ! curl -fsS "${SOURCE_BASE}/__moondesk_health" >/dev/null 2>&1; then
  echo "source-root server did not become healthy; log follows" >&2
  cat "${SOURCE_LOG}" >&2
  exit 1
fi

source_health="$(curl -fsS "${SOURCE_BASE}/__moondesk_health")"
if [[ "${source_health}" != *"${NORMALIZED_DEDICATED_ROOT}"* || "${source_health}" == *"${NORMALIZED_SOURCE_ROOT}"* ]]; then
  echo "source-root launch did not report guarded MoonSuite workspace root" >&2
  echo "${source_health}" >&2
  exit 1
fi
if [[ -e "${SOURCE_ROOT}/.moonsuite" || -e "${SOURCE_ROOT}/books" ]]; then
  echo "source checkout root was polluted by MoonSuite state" >&2
  exit 1
fi
if [[ ! -e "${DEDICATED_ROOT}/.moonsuite" || ! -e "${DEDICATED_ROOT}/books" ]]; then
  echo "dedicated MoonSuite root was not prepared" >&2
  exit 1
fi
source_created_book="$(curl -fsS -H 'content-type: application/json' --data '{"name":"Source Selected Book","book_id":"source-selected-book"}' "${SOURCE_BASE}/api/workspaces")"
if [[ "${source_created_book}" != *'"book_id": "source-selected-book"'* ]]; then
  echo "source-root launch did not create selected-root MoonBook" >&2
  echo "${source_created_book}" >&2
  exit 1
fi
if [[ ! -f "${DEDICATED_ROOT}/books/source-selected-book/wiki/index.md" ]]; then
  echo "source-root launch did not create MoonBook in guarded MoonSuite workspace" >&2
  exit 1
fi
if [[ -e "${SOURCE_ROOT}/books/source-selected-book/wiki/index.md" ]]; then
  echo "source-root launch wrote MoonBook into source checkout" >&2
  exit 1
fi
kill "${SOURCE_PID}" 2>/dev/null || true
wait "${SOURCE_PID}" 2>/dev/null || true
SOURCE_PID=""

moon run cmd/main -- serve "${ROOT}" --ui ui/rabbita-desk/dist --host "${HOST}" --port "${PORT}" >"${LOG}" 2>&1 &
PID="$!"

for _ in {1..200}; do
  if curl -fsS "${BASE}/__moondesk_health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if ! curl -fsS "${BASE}/__moondesk_health" >/dev/null 2>&1; then
  echo "server did not become healthy; log follows" >&2
  cat "${LOG}" >&2
  exit 1
fi

request() {
  local expected="$1"
  local url="$2"
  local body="${ROOT}/response.body"
  local status
  status="$(curl -sS -o "${body}" -w "%{http_code}" "${url}")"
  if [[ "${status}" != "${expected}" ]]; then
    echo "expected HTTP ${expected}, got ${status}: ${url}" >&2
    cat "${body}" >&2
    echo "--- server log ---" >&2
    cat "${LOG}" >&2
    exit 1
  fi
  cat "${body}"
}

post_json() {
  local expected="$1"
  local url="$2"
  local json="$3"
  local body="${ROOT}/response.body"
  local status
  status="$(curl -sS -o "${body}" -w "%{http_code}" \
    -H 'content-type: application/json' \
    --data "${json}" \
    "${url}")"
  if [[ "${status}" != "${expected}" ]]; then
    echo "expected HTTP ${expected}, got ${status}: ${url}" >&2
    cat "${body}" >&2
    echo "--- server log ---" >&2
    cat "${LOG}" >&2
    exit 1
  fi
  cat "${body}"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    echo "expected response to contain: ${needle}" >&2
    echo "${haystack}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    echo "expected response not to contain: ${needle}" >&2
    echo "${haystack}" >&2
    exit 1
  fi
}

workspaces="$(request 200 "${BASE}/api/workspaces")"
assert_contains "${workspaces}" "${WORKSPACE_ID}"
assert_contains "${workspaces}" "${EMPTY_WORKSPACE_ID}"
assert_contains "${workspaces}" "${LARGE_WORKSPACE_ID}"
assert_contains "${workspaces}" "${DEEP_WORKSPACE_ID}"
assert_contains "${workspaces}" "\"name\": \"Desk Smoke\""
assert_contains "${workspaces}" "\"name\": \"Empty Desk\""
assert_contains "${workspaces}" "\"name\": \"Large Desk\""
assert_contains "${workspaces}" "\"name\": \"Deep Desk\""
assert_not_contains "${workspaces}" "plain-folder"

workspace_metadata="$(request 200 "${BASE}/api/workspaces/metadata")"
assert_contains "${workspace_metadata}" "\"root_path\": \"${NORMALIZED_ROOT}\""
assert_contains "${workspace_metadata}" "\"library_path\": \"${NORMALIZED_ROOT}/books\""
assert_not_contains "${workspace_metadata}" "${SOURCE_ROOT}"

created_book="$(post_json 200 "${BASE}/api/workspaces" '{"name":"Created Desk Smoke","book_id":"created-desk-smoke"}')"
assert_contains "${created_book}" '"book_id": "created-desk-smoke"'
assert_contains "${created_book}" '"path": "wiki/index.md"'
if [[ ! -f "${ROOT}/books/created-desk-smoke/wiki/index.md" ]]; then
  echo "created MoonBook was not written inside books" >&2
  exit 1
fi
if [[ -e "${ROOT}/created-desk-smoke" ]]; then
  echo "created MoonBook leaked into workspace root" >&2
  exit 1
fi
workspaces_after_create="$(request 200 "${BASE}/api/workspaces")"
assert_contains "${workspaces_after_create}" "book-created-desk-smoke"

imported_book="$(post_json 200 "${BASE}/api/workspaces/import" "{\"source_path\":\"${IMPORT_SOURCE}\"}")"
assert_contains "${imported_book}" '"book_id": "imported-desk-smoke"'
assert_contains "${imported_book}" '"path": "wiki/index.md"'
if [[ ! -f "${ROOT}/books/imported-desk-smoke/wiki/index.md" ]]; then
  echo "imported MoonBook was not copied inside books" >&2
  exit 1
fi
if [[ -f "${ROOT}/books/imported-desk-smoke/.git/config" ]]; then
  echo "imported MoonBook copied host VCS metadata" >&2
  exit 1
fi
if [[ ! -f "${IMPORT_SOURCE}/wiki/index.md" ]]; then
  echo "import source was moved instead of copied" >&2
  exit 1
fi
workspaces_after_import="$(request 200 "${BASE}/api/workspaces")"
assert_contains "${workspaces_after_import}" "book-imported-desk-smoke"

archived_book="$(post_json 200 "${BASE}/api/workspaces/import" "{\"source_path\":\"${ARCHIVE_PATH}\"}")"
assert_contains "${archived_book}" '"book_id": "archived-desk-smoke"'
assert_contains "${archived_book}" '"path": "wiki/index.md"'
if [[ ! -f "${ROOT}/books/archived-desk-smoke/wiki/index.md" ]]; then
  echo "archived MoonBook was not extracted into books" >&2
  exit 1
fi
if [[ "$(cat "${ROOT}/books/archived-desk-smoke/raw/evidence.txt")" != "archive evidence" ]]; then
  echo "archived MoonBook did not preserve file content" >&2
  exit 1
fi
if [[ -f "${ROOT}/books/archived-desk-smoke/node_modules/cache/file.txt" ]]; then
  echo "archived MoonBook copied dependency metadata" >&2
  exit 1
fi
if [[ -e "${ROOT}/books/archived-desk-smoke/__MACOSX" ]]; then
  echo "archived MoonBook copied macOS archive metadata" >&2
  exit 1
fi
workspaces_after_archive="$(request 200 "${BASE}/api/workspaces")"
assert_contains "${workspaces_after_archive}" "book-archived-desk-smoke"

upload_archive_payload="$(python3 -c 'import base64, json, pathlib, sys
data = base64.b64encode(pathlib.Path(sys.argv[1]).read_bytes()).decode()
print(json.dumps({
    "filename": "uploaded-desk-smoke.zip",
    "content_type": "application/zip",
    "data_url": "data:application/zip;base64," + data,
}))
' "${UPLOAD_ARCHIVE_PATH}")"
uploaded_book="$(post_json 200 "${BASE}/api/workspaces/import" "${upload_archive_payload}")"
assert_contains "${uploaded_book}" '"book_id": "uploaded-desk-smoke"'
assert_contains "${uploaded_book}" '"path": "wiki/index.md"'
if [[ "$(cat "${ROOT}/books/uploaded-desk-smoke/raw/evidence.txt")" != "uploaded archive evidence" ]]; then
  echo "uploaded archive MoonBook did not preserve file content" >&2
  exit 1
fi
workspaces_after_uploaded_archive="$(request 200 "${BASE}/api/workspaces")"
assert_contains "${workspaces_after_uploaded_archive}" "book-uploaded-desk-smoke"

uploaded_folder_payload="$(python3 -c 'import json
print(json.dumps({
    "files": [
        {
            "filename": "book.json",
            "relative_path": "Uploaded Folder Desk/book.json",
            "content": "{\"id\":\"uploaded-folder-desk\",\"name\":\"Uploaded Folder Desk\"}\n",
            "content_type": "application/json",
        },
        {
            "filename": "index.md",
            "relative_path": "Uploaded Folder Desk/wiki/index.md",
            "content": "# Uploaded Folder Desk\n\nimported from folder picker\n",
            "content_type": "text/markdown",
        },
        {
            "filename": "evidence.txt",
            "relative_path": "Uploaded Folder Desk/raw/evidence.txt",
            "content": "uploaded folder evidence\n",
            "content_type": "text/plain",
        },
        {
            "filename": "config",
            "relative_path": "Uploaded Folder Desk/.git/config",
            "content": "skip\n",
            "content_type": "text/plain",
        },
    ]
}))
')"
uploaded_folder_book="$(post_json 200 "${BASE}/api/workspaces/import" "${uploaded_folder_payload}")"
assert_contains "${uploaded_folder_book}" '"book_id": "uploaded-folder-desk"'
if [[ "$(cat "${ROOT}/books/uploaded-folder-desk/raw/evidence.txt")" != "uploaded folder evidence" ]]; then
  echo "uploaded folder MoonBook did not preserve file content" >&2
  exit 1
fi
if [[ -f "${ROOT}/books/uploaded-folder-desk/.git/config" ]]; then
  echo "uploaded folder MoonBook copied VCS metadata" >&2
  exit 1
fi
workspaces_after_uploaded_folder="$(request 200 "${BASE}/api/workspaces")"
assert_contains "${workspaces_after_uploaded_folder}" "book-uploaded-folder-desk"

root_entries="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries?path=")"
assert_contains "${root_entries}" "\"path\": \"wiki\""
assert_contains "${root_entries}" "\"path\": \"raw\""
assert_contains "${root_entries}" "\"path\": \"book/site/generated\""
assert_not_contains "${root_entries}" ".git"
assert_not_contains "${root_entries}" ".DS_Store"

wiki_entries="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries?path=wiki")"
assert_contains "${wiki_entries}" "\"path\": \"wiki/index.md\""
assert_contains "${wiki_entries}" "\"path\": \"wiki/notes\""

created_folder_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries" '{"kind":"folder","directory":"wiki","name":"smoke-created"}')"
assert_contains "${created_folder_entry}" '"path": "wiki/smoke-created"'
if [[ ! -d "${BOOK_ROOT}/wiki/smoke-created" ]]; then
  echo "created Desk folder was not written inside the MoonBook" >&2
  exit 1
fi
created_note_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries" '{"kind":"markdown","directory":"wiki/smoke-created","name":"daily"}')"
assert_contains "${created_note_entry}" '"path": "wiki/smoke-created/daily.md"'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-created/daily.md" ]]; then
  echo "created Desk note was not written inside the MoonBook" >&2
  exit 1
fi
renamed_note_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/rename" '{"path":"wiki/smoke-created/daily.md","name":"renamed-daily"}')"
assert_contains "${renamed_note_entry}" '"path": "wiki/smoke-created/renamed-daily.md"'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-created/renamed-daily.md" ]]; then
  echo "renamed Desk note was not written inside the MoonBook" >&2
  exit 1
fi
if [[ -f "${BOOK_ROOT}/wiki/smoke-created/daily.md" ]]; then
  echo "renamed Desk note left the old path behind" >&2
  exit 1
fi
created_archive_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries" '{"kind":"folder","directory":"wiki","name":"smoke-archive"}')"
assert_contains "${created_archive_entry}" '"path": "wiki/smoke-archive"'
moved_note_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/move" '{"path":"wiki/smoke-created/renamed-daily.md","directory":"wiki/smoke-archive"}')"
assert_contains "${moved_note_entry}" '"path": "wiki/smoke-archive/renamed-daily.md"'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-archive/renamed-daily.md" ]]; then
  echo "moved Desk note was not written inside the target directory" >&2
  exit 1
fi
if [[ -f "${BOOK_ROOT}/wiki/smoke-created/renamed-daily.md" ]]; then
  echo "moved Desk note left the old path behind" >&2
  exit 1
fi
batch_move_a_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries" '{"kind":"markdown","directory":"wiki/smoke-created","name":"move-a"}')"
assert_contains "${batch_move_a_entry}" '"path": "wiki/smoke-created/move-a.md"'
batch_move_b_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries" '{"kind":"markdown","directory":"wiki/smoke-created","name":"move-b"}')"
assert_contains "${batch_move_b_entry}" '"path": "wiki/smoke-created/move-b.md"'
batch_move_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/move" '{"paths":["wiki/smoke-created/move-a.md","wiki/smoke-created/move-b.md"],"directory":"wiki/smoke-archive"}')"
assert_contains "${batch_move_entry}" '"moved_count": 2'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-archive/move-a.md" || ! -f "${BOOK_ROOT}/wiki/smoke-archive/move-b.md" ]]; then
  echo "batch move did not write every item into the target directory" >&2
  exit 1
fi
if [[ -f "${BOOK_ROOT}/wiki/smoke-created/move-a.md" || -f "${BOOK_ROOT}/wiki/smoke-created/move-b.md" ]]; then
  echo "batch move left one or more old paths behind" >&2
  exit 1
fi
copied_note_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/copy" '{"path":"wiki/smoke-archive/renamed-daily.md"}')"
assert_contains "${copied_note_entry}" '"path": "wiki/smoke-archive/renamed-daily copy.md"'
assert_contains "${copied_note_entry}" '"copied_count": 1'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-archive/renamed-daily copy.md" ]]; then
  echo "duplicated Desk note was not written beside the source" >&2
  exit 1
fi
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-archive/renamed-daily.md" ]]; then
  echo "duplicating Desk note removed the source" >&2
  exit 1
fi
batch_copy_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/copy" '{"paths":["wiki/smoke-archive/move-a.md","wiki/smoke-archive/move-b.md"]}')"
assert_contains "${batch_copy_entry}" '"copied_count": 2'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-archive/move-a copy.md" || ! -f "${BOOK_ROOT}/wiki/smoke-archive/move-b copy.md" ]]; then
  echo "batch duplicate did not write every copied item beside its source" >&2
  exit 1
fi
pasted_note_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/copy" '{"path":"wiki/smoke-archive/renamed-daily.md","directory":"wiki/smoke-created"}')"
assert_contains "${pasted_note_entry}" '"path": "wiki/smoke-created/renamed-daily.md"'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-created/renamed-daily.md" ]]; then
  echo "pasted Desk note was not written into the target directory" >&2
  exit 1
fi
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-archive/renamed-daily.md" ]]; then
  echo "pasting Desk note removed the source" >&2
  exit 1
fi
batch_paste_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/copy" '{"paths":["wiki/smoke-archive/move-a.md","wiki/smoke-archive/move-b.md"],"directory":"wiki/smoke-created"}')"
assert_contains "${batch_paste_entry}" '"copied_count": 2'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-created/move-a.md" || ! -f "${BOOK_ROOT}/wiki/smoke-created/move-b.md" ]]; then
  echo "batch paste did not write every copied item into the target directory" >&2
  exit 1
fi
imported_files_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries/import" '{"directory":"wiki/smoke-created","files":[{"filename":"desk-drop.txt","content":"desk drop\n","content_type":"text/plain"},{"filename":"desk-bytes.bin","data_url":"data:application/octet-stream;base64,cG5nLWJ5dGVz","content_type":"application/octet-stream"},{"filename":"evidence.txt","relative_path":"desk-folder/nested/evidence.txt","content":"nested evidence\n","content_type":"text/plain"}]}')"
assert_contains "${imported_files_entry}" '"imported_count": 3'
assert_contains "${imported_files_entry}" '"path": "wiki/smoke-created/desk-drop.txt"'
if [[ "$(cat "${BOOK_ROOT}/wiki/smoke-created/desk-drop.txt")" != "desk drop" ]]; then
  echo "Desk text import did not write expected file content" >&2
  exit 1
fi
if [[ "$(cat "${BOOK_ROOT}/wiki/smoke-created/desk-bytes.bin")" != "png-bytes" ]]; then
  echo "Desk data URL import did not write decoded file bytes" >&2
  exit 1
fi
if [[ "$(cat "${BOOK_ROOT}/wiki/smoke-created/desk-folder/nested/evidence.txt")" != "nested evidence" ]]; then
  echo "Desk folder import did not preserve nested file content" >&2
  exit 1
fi
generated_import_error="$(post_json 400 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries/import" '{"directory":"book/site/generated","files":[{"filename":"bad.txt","content":"bad"}]}')"
assert_contains "${generated_import_error}" "Desk cannot import into generated or system paths"
trashed_note_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/trash" '{"path":"wiki/smoke-archive/renamed-daily.md"}')"
assert_contains "${trashed_note_entry}" '"path": "wiki/smoke-archive/renamed-daily.md"'
trash_path="$(printf '%s' "${trashed_note_entry}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["trash_path"])')"
trash_absolute="${ROOT}/${trash_path}"
nested_book_trash_absolute="${BOOK_ROOT}/${trash_path}"
if [[ ! "${trash_path}" == .moonsuite/products/moondesk/trash/files/* ]]; then
  echo "trashed Desk note did not use MoonDesk product-home trash" >&2
  exit 1
fi
if [[ ! -e "${trash_absolute}" ]]; then
  echo "trashed Desk note was not moved into suite product-home trash" >&2
  exit 1
fi
if [[ -e "${nested_book_trash_absolute}" ]]; then
  echo "trashed Desk note created nested book-local product-home trash" >&2
  exit 1
fi
if [[ -f "${BOOK_ROOT}/wiki/smoke-archive/renamed-daily.md" ]]; then
  echo "trashed Desk note left the old path behind" >&2
  exit 1
fi
trash_listing="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/trash")"
assert_contains "${trash_listing}" '"original_path": "wiki/smoke-archive/renamed-daily.md"'
assert_contains "${trash_listing}" "\"trash_path\": \"${trash_path}\""
restored_note_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/restore" "{\"trash_path\":\"${trash_path}\"}")"
assert_contains "${restored_note_entry}" '"path": "wiki/smoke-archive/renamed-daily.md"'
if [[ ! -f "${BOOK_ROOT}/wiki/smoke-archive/renamed-daily.md" ]]; then
  echo "restored Desk note was not returned to the original path" >&2
  exit 1
fi
if [[ -e "${trash_absolute}" ]]; then
  echo "restored Desk note was left in suite product-home trash" >&2
  exit 1
fi
trash_listing_after_restore="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/trash")"
assert_not_contains "${trash_listing_after_restore}" "wiki/smoke-archive/renamed-daily.md"
batch_a_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries" '{"kind":"markdown","directory":"wiki/smoke-archive","name":"batch-a"}')"
assert_contains "${batch_a_entry}" '"path": "wiki/smoke-archive/batch-a.md"'
batch_b_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries" '{"kind":"markdown","directory":"wiki/smoke-archive","name":"batch-b"}')"
assert_contains "${batch_b_entry}" '"path": "wiki/smoke-archive/batch-b.md"'
batch_trash_entry="$(post_json 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/trash" '{"paths":["wiki/smoke-archive/batch-a.md","wiki/smoke-archive/batch-b.md"]}')"
assert_contains "${batch_trash_entry}" '"trashed_count": 2'
batch_trash_listing="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/trash")"
assert_contains "${batch_trash_listing}" '"original_path": "wiki/smoke-archive/batch-a.md"'
assert_contains "${batch_trash_listing}" '"original_path": "wiki/smoke-archive/batch-b.md"'
if [[ -f "${BOOK_ROOT}/wiki/smoke-archive/batch-a.md" || -f "${BOOK_ROOT}/wiki/smoke-archive/batch-b.md" ]]; then
  echo "batch trash left one or more old paths behind" >&2
  exit 1
fi

preview="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/preview?path=wiki%2Findex.md")"
assert_contains "${preview}" "# Desk Smoke"
assert_contains "${preview}" "\"renderer\": \"Markdown\""

image_preview="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/preview?path=images%2Flogo.png")"
assert_contains "${image_preview}" "/api/workspaces/${WORKSPACE_ID}/raw?path=images/logo.png"
assert_contains "${image_preview}" "\"renderer\": \"Image\""

raw_body="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/raw?path=raw%2Fnested%2Fevidence.txt")"
assert_contains "${raw_body}" "evidence smoke"

file_body="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/file/images/logo.png")"
assert_contains "${file_body}" "png-bytes"

site_body="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/site/assets/site.css")"
assert_contains "${site_body}" "color: black"

encoded_preview="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/preview?path=docs%20with%20spaces%2Fencoded%20%23%20name.md")"
assert_contains "${encoded_preview}" "# Encoded"

odd_preview="$(request 200 "${BASE}/api/workspaces/${WORKSPACE_ID}/preview?path=odd%20%5Bchars%5D%20%25%20dir%2Ffile%20%3F%20name%20%25.md")"
assert_contains "${odd_preview}" "# Odd"

search_hits="$(request 200 "${BASE}/api/search?workspace=${WORKSPACE_ID}&query=alpha")"
assert_contains "${search_hits}" "wiki/notes/alpha.md"
assert_not_contains "${search_hits}" "${EMPTY_WORKSPACE_ID}"

empty_entries="$(request 200 "${BASE}/api/workspaces/${EMPTY_WORKSPACE_ID}/entries?path=")"
assert_contains "${empty_entries}" "\"path\": \"wiki\""
assert_contains "${empty_entries}" "\"path\": \"raw\""
assert_contains "${empty_entries}" "\"path\": \"book/site/generated\""

empty_virtual="$(request 200 "${BASE}/api/workspaces/${EMPTY_WORKSPACE_ID}/entries?path=skills")"
assert_contains "${empty_virtual}" "[]"

large_entries="$(request 200 "${BASE}/api/workspaces/${LARGE_WORKSPACE_ID}/entries?path=raw%2Flarge")"
assert_contains "${large_entries}" "item-001.txt"
assert_contains "${large_entries}" "item-150.txt"
assert_contains "${large_entries}" "item-300.txt"

large_preview="$(request 200 "${BASE}/api/workspaces/${LARGE_WORKSPACE_ID}/preview?path=raw%2Flarge%2Fitem-300.txt")"
assert_contains "${large_preview}" "large 300"

deep_entries="$(request 200 "${BASE}/api/workspaces/${DEEP_WORKSPACE_ID}/entries?path=raw%2Flevel-01%2Flevel-02%2Flevel-03%2Flevel-04%2Flevel-05%2Flevel-06%2Flevel-07%2Flevel-08%2Flevel-09%2Flevel-10")"
assert_contains "${deep_entries}" "final.txt"

deep_preview="$(request 200 "${BASE}/api/workspaces/${DEEP_WORKSPACE_ID}/preview?path=raw%2Flevel-01%2Flevel-02%2Flevel-03%2Flevel-04%2Flevel-05%2Flevel-06%2Flevel-07%2Flevel-08%2Flevel-09%2Flevel-10%2Ffinal.txt")"
assert_contains "${deep_preview}" "deep final"

wrong_workspace="$(request 404 "${BASE}/api/workspaces/${EMPTY_WORKSPACE_ID}/preview?path=wiki%2Findex.md")"
assert_not_contains "${wrong_workspace}" "# Desk Smoke"

missing_path="$(request 404 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries?path=wiki%2Fmissing.md")"
assert_contains "${missing_path}" "Entry path not found"

directory_raw="$(request 404 "${BASE}/api/workspaces/${WORKSPACE_ID}/raw?path=wiki")"
assert_contains "${directory_raw}" "Entry path not found"

escape_body="$(request 400 "${BASE}/api/workspaces/${WORKSPACE_ID}/preview?path=%2e%2e%2Foutside.txt")"
assert_not_contains "${escape_body}" "outside secret"

absolute_body="$(request 400 "${BASE}/api/workspaces/${WORKSPACE_ID}/raw?path=%2Ftmp%2Foutside.txt")"
assert_not_contains "${absolute_body}" "outside secret"

double_escape_body="$(request 400 "${BASE}/api/workspaces/${WORKSPACE_ID}/entries?path=wiki%2F%2e%2e%2F%2e%2e%2Foutside.txt")"
assert_not_contains "${double_escape_body}" "outside secret"

echo "Desk API smoke passed on ${BASE}"
