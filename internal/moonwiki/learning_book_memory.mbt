///|
/// Immutable, human-accepted lessons use MoonBook's documented Markdown memory
/// layout. This is not Bookkeeper evaluation or capability activation.
fn learning_book_content(record : Json) -> Result[(String, String), String] {
  let id = json_string(record, "id", default="")
  let kind = json_string(record, "kind", default="")
  if json_string(record, "status", default="") != "accepted" ||
    !learning_proposal_kind_valid(kind) ||
    id == "" ||
    json_string(record, "workspace_id", default="") == "" ||
    json_string(record, "created_at", default="") == "" ||
    json_string(record, "decided_at", default="") == "" ||
    json_string(record, "detail", default="") == "" {
    return Err("invalid_accepted_learning")
  }
  // Fixed field order and only decision fields: adding/changing the persistence
  // receipt must never change the accepted provenance or the portable bytes.
  let provenance : Json = {
    "contract": LearningProposalContract,
    "id": id,
    "workspace_id": json_string(record, "workspace_id", default=""),
    "kind": kind,
    "detail": json_string(record, "detail", default=""),
    "source": json_string(record, "source", default=""),
    "status": "accepted",
    "created_at": json_string(record, "created_at", default=""),
    "decided_at": json_string(record, "decided_at", default=""),
  }
  let label = if kind == "capability" {
    "Capability idea (not activated)"
  } else {
    kind
  }
  let content = StringBuilder()
  content.write_string("---\nstatus: accepted\n")
  for
    (key, value) in [
      ("lesson_kind", kind),
      ("proposal_id", id),
      ("workspace_id", json_string(record, "workspace_id", default="")),
      ("created_at", json_string(record, "created_at", default="")),
      ("decided_at", json_string(record, "decided_at", default="")),
    ] {
    content.write_string(key + ": " + value.to_json().stringify() + "\n")
  }
  content.write_string(
    "---\n\n# Accepted Desk lesson\n\nKind: " + label + "\n\n",
  )
  content.write_string(
    "## Lesson\n\n" + json_string(record, "detail", default="") + "\n\n",
  )
  content.write_string(
    "## Source answer\n\n" + json_string(record, "source", default="") + "\n\n",
  )
  content.write_string(
    "## Acceptance provenance\n\n```json\n" +
    provenance.stringify(indent=2) +
    "\n```\n",
  )
  let tree = if kind == "procedure" { "procedures" } else { "beliefs" }
  let key = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(id)),
  )
  Ok(("memory/" + tree + "/desk-" + key + ".md", content.to_string()))
}

///|
fn learning_book_receipt(
  record : Json,
  status : String,
  error : String,
) -> Json {
  let (path, revision) = match learning_book_content(record) {
    Ok((path, content)) =>
      (
        path,
        "sha256:" +
        @crypto.bytes_to_hex_string(
          @crypto.sha256(@encoding/utf8.encode(content)),
        ),
      )
    Err(_) => ("", "")
  }
  @mooncore.session_with_field(record, "book_learning", {
    "status": status,
    "path": path,
    "revision": revision,
    "error": error,
  })
}

///|
/// Refuse symlinks and non-directory parents. A generated relative path never
/// contains user-chosen components: the filename uses a proposal-ID digest.
async fn learning_book_target(root : String, relative : String) -> String {
  if @fs.kind(root, follow_symlink=false) != Directory {
    fail("learning_book_invalid_root")
  }
  let parts = relative.split("/").to_array()
  let mut current = root
  for index, part in parts {
    current = @pathx.join(current, part.to_owned())
    let kind = @fs.kind(current, follow_symlink=false) catch {
      @os_error.OSError(_) as error if error.is_ENOENT() => {
        if index + 1 == parts.length() {
          return current
        }
        @fs.mkdir(current, permission=0o700)
        Directory
      }
      error => raise error
    }
    if index + 1 < parts.length() {
      if kind != Directory {
        fail("learning_book_invalid_parent")
      }
    } else if kind != Regular {
      fail("learning_book_invalid_target")
    }
  }
  current
}

///|
async fn persist_learning_in_book(
  root : String,
  record : Json,
) -> Result[Unit, String] {
  let (relative, content) = match learning_book_content(record) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let target = learning_book_target(root, relative) catch {
    _ => return Err("learning_book_invalid_target")
  }
  if @fsx.exists(target) {
    return if @fsx.read_file(target) == content {
      Ok(())
    } else {
      Err("learning_book_content_conflict")
    }
  }
  // Keep uncommitted bytes out of the export allowlist, including after a crash.
  let temp = learning_book_target(
    root,
    ".moonbook/desk-learning-tmp/" +
    @desk.stable_id("lesson-write", @async.now().to_string()) +
    ".tmp",
  ) catch {
    _ => return Err("learning_book_write_failed")
  }
  @fs.write_file(
    temp,
    @encoding/utf8.encode(content),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  ) catch {
    _ => return Err("learning_book_write_failed")
  }
  @fs.rename(temp, target, replace=false) catch {
    _ => {
      @fs.remove(temp) catch {
        _ => ()
      }
      // Another identical attempt may have won the no-replace rename.
      let checked = learning_book_target(root, relative) catch {
        _ => return Err("learning_book_write_failed")
      }
      if @fsx.exists(checked) {
        return if @fsx.read_file(checked) == content {
          Ok(())
        } else {
          Err("learning_book_content_conflict")
        }
      }
      return Err("learning_book_write_failed")
    }
  }
  Ok(())
}

///|
async fn read_learning_proposals(
  workspace_root : String,
) -> Result[Array[Json], String] {
  let path = learning_proposals_path(workspace_root)
  if !@fsx.exists(path) {
    return Ok([])
  }
  let text = @fsx.read_file(path) catch {
    _ => return Err("learning_journal_unreadable")
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("learning_journal_invalid")
  }
  match parsed {
    Array(records) => Ok(records)
    _ => Err("learning_journal_invalid")
  }
}

///|
async fn save_learning_record(
  workspace_root : String,
  records : Array[Json],
  record : Json,
) -> Bool {
  let next = upsert_record_by_id(records, record)
  while next.length() > LearningProposalMaxRecords {
    next.pop() |> ignore
  }
  write_learning_proposals(workspace_root, next) catch {
    _ => return false
  }
  true
}
