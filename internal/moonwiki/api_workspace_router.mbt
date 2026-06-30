///|
async fn route_workspace_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "workspaces"] => {
      if is_read_method(method_) {
        send_json(conn, method_, discover_workspaces(workspace_root).to_json())
      } else if method_ is Post {
        handle_workspace_create(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", "metadata"] => {
      if is_read_method(method_) {
        send_json(conn, method_, workspace_library_metadata(workspace_root))
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", "import"] => {
      if method_ is Post {
        handle_moonbook_import(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "entries"] => {
      if is_read_method(method_) {
        handle_workspace_entries(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else if method_ is Post {
        handle_workspace_create_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "entries", "import"] => {
      if method_ is Post {
        handle_workspace_import_files(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "preview"] => {
      if is_read_method(method_) {
        handle_workspace_preview(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "raw"] => {
      if is_read_method(method_) {
        handle_workspace_raw(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "file", .. asset_segments] => {
      if is_read_method(method_) {
        handle_workspace_file_asset(
          workspace_root,
          workspace_id,
          asset_segments.join("/"),
          method_,
          conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "site"] => {
      if is_read_method(method_) {
        handle_workspace_site_asset(
          workspace_root, workspace_id, "", method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "site", .. asset_segments] => {
      if is_read_method(method_) {
        handle_workspace_site_asset(
          workspace_root,
          workspace_id,
          asset_segments.join("/"),
          method_,
          conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "inbox"] => {
      if method_ is Post {
        handle_workspace_inbox(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "markdown"] => {
      if method_ is Post {
        handle_workspace_markdown(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "rename"] => {
      if method_ is Post {
        handle_workspace_rename_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "move"] => {
      if method_ is Post {
        handle_workspace_move_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "copy"] => {
      if method_ is Post {
        handle_workspace_copy_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "trash"] => {
      if method_ is Get {
        handle_workspace_trash_listing(
          workspace_root, workspace_id, method_, conn,
        )
      } else if method_ is Post {
        handle_workspace_trash_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "restore"] => {
      if method_ is Post {
        handle_workspace_restore_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "import"] => {
      if method_ is Post {
        handle_workspace_import(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "reveal"] => {
      if method_ is Post {
        handle_workspace_reveal(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "search"] => {
      if is_read_method(method_) {
        handle_search(workspace_root, request_path, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "workspaces", workspace_id, "review-diff"] => {
      if is_read_method(method_) {
        handle_workspace_review_diff(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    _ => false
  }
}
