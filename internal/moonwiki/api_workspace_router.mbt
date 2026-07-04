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
      let endpoint = @desk.workspaces_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(conn, method_, discover_workspaces(workspace_root).to_json())
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_create(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", "metadata"] => {
      let endpoint = @desk.workspace_metadata_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(conn, method_, workspace_library_metadata(workspace_root))
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", "import"] => {
      let endpoint = @desk.workspace_import_route()
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_moonbook_import(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "entries"] => {
      let endpoint = @desk.workspace_action_route("entries")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_entries(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_create_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "entries", "import"] => {
      let endpoint = @desk.workspace_action_route("entries/import")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_import_files(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "preview"] => {
      let endpoint = @desk.workspace_action_route("preview")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_preview(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "raw"] => {
      let endpoint = @desk.workspace_action_route("raw")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_raw(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "file", .. asset_segments] => {
      let endpoint = @desk.workspace_file_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_file_asset(
          workspace_root,
          workspace_id,
          asset_segments.join("/"),
          method_,
          conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "site"] => {
      let endpoint = @desk.workspace_site_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_site_asset(
          workspace_root, workspace_id, "", method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "site", .. asset_segments] => {
      let endpoint = @desk.workspace_site_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_site_asset(
          workspace_root,
          workspace_id,
          asset_segments.join("/"),
          method_,
          conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "inbox"] => {
      let endpoint = @desk.workspace_action_route("inbox")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_inbox(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "markdown"] => {
      let endpoint = @desk.workspace_action_route("markdown")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_markdown(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "rename"] => {
      let endpoint = @desk.workspace_action_route("rename")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_rename_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "move"] => {
      let endpoint = @desk.workspace_action_route("move")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_move_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "copy"] => {
      let endpoint = @desk.workspace_action_route("copy")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_copy_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "trash"] => {
      let endpoint = @desk.workspace_action_route("trash")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_trash_listing(
          workspace_root, workspace_id, method_, conn,
        )
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_trash_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "restore"] => {
      let endpoint = @desk.workspace_action_route("restore")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_restore_entry(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "import"] => {
      let endpoint = @desk.workspace_action_route("import")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_import(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "reveal"] => {
      let endpoint = @desk.workspace_action_route("reveal")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_workspace_reveal(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "search"] => {
      let endpoint = @desk.search_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_search(workspace_root, request_path, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "workspaces", workspace_id, "review-diff"] => {
      let endpoint = @desk.workspace_action_route("review-diff")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_workspace_review_diff(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
