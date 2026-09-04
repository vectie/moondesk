///|
const InboxImportAttachmentMaxBytes : Int = 25 * 1_024 * 1_024

///|
fn inbox_import_attachment_extension(content_type : String) -> String {
  match content_type.trim().to_lower() {
    "image/png" => ".png"
    "image/jpeg" => ".jpg"
    "image/webp" => ".webp"
    "image/gif" => ".gif"
    "audio/mpeg" => ".mp3"
    "audio/mp4" | "audio/x-m4a" => ".m4a"
    "audio/wav" | "audio/x-wav" => ".wav"
    "video/mp4" => ".mp4"
    "application/pdf" => ".pdf"
    _ => ".bin"
  }
}

///|
async fn handle_workspace_inbox(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let title = json_string(payload, "title", default="MoonDesk inbox note")
  let content = json_string(
    payload,
    "content",
    default=json_string(payload, "prompt", default=""),
  )
  match json_string_opt(payload, "path") {
    Some(path) => {
      let relative = decode_query_value(path)
      match resolve_workspace_write_path(workspace.root_path, relative) {
        Some((absolute, clean_relative)) =>
          if !is_writable_entry(clean_relative) {
            send_api_error(
              conn, method_, 400, "Bad Request", "Inbox edits must stay under inbox/",
            )
            return
          } else {
            let parent = @pathx.dirname(absolute).to_owned()
            @fsx.make_directory(parent, recursive=true, exists_ok=true) catch {
              _ => {
                send_api_error(
                  conn, method_, 500, "Internal Server Error", "Could not create inbox directory",
                )
                return
              }
            }
            @fsx.write_to_file(absolute, content, create=0o644) catch {
              _ => {
                send_api_error(
                  conn, method_, 500, "Internal Server Error", "Could not edit inbox note",
                )
                return
              }
            }
            send_json(conn, method_, {
              "ok": true,
              "workspace_id": workspace.id,
              "path": clean_relative,
            })
            return
          }
        None => {
          send_api_error(
            conn, method_, 400, "Bad Request", "Invalid inbox path",
          )
          return
        }
      }
    }
    None => ()
  }
  let inbox_root = @pathx.join(workspace.root_path, "inbox")
  @fsx.make_directory(inbox_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create inbox",
      )
      return
    }
  }
  let filename = @desk.stable_id("note", title) +
    "-" +
    @async.now().to_string() +
    ".md"
  let relative = @pathx.join("inbox", filename)
  let absolute = @pathx.join(workspace.root_path, relative)
  let markdown = "# \{title}\n\n\{content}\n"
  @fsx.write_to_file(absolute, markdown, create=0o644) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write inbox note",
      )
      return
    }
  }
  send_json(conn, method_, {
    "ok": true,
    "workspace_id": workspace.id,
    "path": relative,
  })
}

///|
async fn handle_workspace_import(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let kind = json_string(payload, "kind", default="note")
  let title = json_string(payload, "title", default="MoonDesk import")
  let inbox_root = @pathx.join(workspace.root_path, "inbox/imports")
  @fsx.make_directory(inbox_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create import inbox",
      )
      return
    }
  }
  let id = @desk.stable_id("import", title + "-" + @async.now().to_string())
  let relative = "inbox/imports/" + id + ".md"
  let absolute = @pathx.join(workspace.root_path, relative)
  let data_url = json_string(payload, "data_url", default="")
  let data_path = if data_url == "" {
    ""
  } else {
    let bytes = match decode_data_url_bytes(data_url) {
      Ok(bytes) => bytes
      Err(error) => {
        send_api_error(conn, method_, 400, "Bad Request", error)
        return
      }
    }
    if bytes.length() > InboxImportAttachmentMaxBytes {
      send_api_error(
        conn, method_, 413, "Content Too Large", "Imported attachment is larger than 25 MB",
      )
      return
    }
    let data_relative = "inbox/imports/" +
      id +
      inbox_import_attachment_extension(
        json_string(payload, "content_type", default=""),
      )
    write_bytes_file(
      @pathx.join(workspace.root_path, data_relative),
      bytes,
      create=0o644,
    ) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not write imported attachment",
        )
        return
      }
    }
    data_relative
  }
  @fsx.write_to_file(
    absolute,
    import_markdown(payload, kind, title, attachment_path=data_path),
    create=0o644,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write import note",
      )
      return
    }
  }
  send_json(conn, method_, {
    "ok": true,
    "workspace_id": workspace.id,
    "path": relative,
    "kind": kind,
    "data_path": data_path,
  })
}

///|
fn import_markdown(
  payload : Json,
  kind : String,
  title : String,
  attachment_path? : String = "",
) -> String {
  let url = json_string(payload, "url", default="")
  let filename = json_string(payload, "filename", default="")
  let content_type = json_string(payload, "content_type", default="")
  let browser_import_id = json_string(payload, "browser_import_id", default="")
  let note = json_string(payload, "note", default="")
  let content = json_string(payload, "content", default="")
  let mut body = "# \{title}\n\n"
  body = body + "- Import kind: \{kind}\n"
  if url != "" {
    body = body + "- URL: \{url}\n"
  }
  if filename != "" {
    body = body + "- File: \{filename}\n"
  }
  if content_type != "" {
    body = body + "- Content type: \{content_type}\n"
  }
  if browser_import_id != "" {
    body = body + "- Browser import id: \{browser_import_id}\n"
  }
  if note != "" {
    body = body + "\n## Note\n\n\{note}\n"
  }
  if content != "" {
    body = body + "\n## Content\n\n\{content}\n"
  }
  if attachment_path != "" {
    body = body + "\n## Attachment\n\nWorkspace file: `\{attachment_path}`\n"
  }
  body
}
