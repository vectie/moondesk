///|
async fn route_desktop_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "desktop", "moongate-stats"] => {
      if method_ is Get {
        handle_desktop_moongate_stats(method_, conn, html=false)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET"])
      }
      true
    }
    ["api", "desktop", "moongate-stats", "view"] => {
      if method_ is Get {
        handle_desktop_moongate_stats(method_, conn, html=true)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET"])
      }
      true
    }
    ["api", "desktop", "provider-connection"] => {
      if method_ is Post {
        handle_openai_connection_import(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "desktop", "provider-handoff"] => {
      if method_ is Post {
        handle_desktop_provider_handoff(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "desktop", "pack-apps"] => {
      let endpoint = @desk.desktop_api_path(["api", "desktop", "pack-apps"])
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(conn, method_, installed_pack_apps(workspace_root))
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "desktop", "agents"] => {
      let endpoint = @desk.agent_catalog_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(conn, method_, installed_agent_catalog(workspace_root))
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "desktop", "capabilities"] => {
      let endpoint = @desk.desktop_capabilities_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_desktop_api_capabilities(method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}

///|
/// Only aggregate counters leave the user's loopback MoonGate. The public
/// workspace gateway authenticates the caller before this route is reached.
async fn handle_desktop_moongate_stats(
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
  html~ : Bool,
) -> Unit {
  let client = @http.Client::Client("http://127.0.0.1:15721", headers={}) catch {
    _ =>
      return send_status(
        conn, 503, "Service Unavailable", "MoonGate is unavailable\n",
      )
  }
  defer client.close()
  let response = client.get("/stats") catch {
    _ =>
      return send_status(
        conn, 503, "Service Unavailable", "MoonGate is unavailable\n",
      )
  }
  if response.code != 200 {
    return send_status(
      conn, 503, "Service Unavailable", "MoonGate is unavailable\n",
    )
  }
  let body = client.read_all().text() catch {
      _ =>
        return send_status(
          conn, 503, "Service Unavailable", "MoonGate is unavailable\n",
        )
    }
  let stats = @json.parse(body) catch {
    _ =>
      return send_status(conn, 502, "Bad Gateway", "Invalid MoonGate stats\n")
  }
  guard stats
    is {
      "total_requests": Number(_, ..) as total_requests,
      "successful_responses": Number(_, ..) as successful_responses,
      "failed_responses": Number(_, ..) as failed_responses,
      "input_tokens": Number(_, ..) as input_tokens,
      "output_tokens": Number(_, ..) as output_tokens,
      "cache_read_tokens": Number(_, ..) as cache_read_tokens,
      ..
    } else {
    return send_status(conn, 502, "Bad Gateway", "Invalid MoonGate stats\n")
  }
  if html {
    conn.send_response(200, "OK", extra_headers={
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'self'",
    })
    conn.write(
      "<html lang=\"zh-CN\"><meta charset=\"utf-8\"><style>body{font:14px system-ui,sans-serif;margin:0;padding:16px;color:#253244;background:#f8fafc}h2{font-size:16px;margin:0 0 12px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}.metric{background:#fff;border:1px solid #dce3ea;border-radius:8px;padding:12px}.metric strong{display:block;font-size:20px;margin-top:5px}</style><h2>MoonGate · 个人工作区用量</h2><div class=\"grid\"><div class=\"metric\">请求<strong>\{total_requests.stringify()}</strong></div><div class=\"metric\">成功<strong>\{successful_responses.stringify()}</strong></div><div class=\"metric\">失败<strong>\{failed_responses.stringify()}</strong></div><div class=\"metric\">输入 token<strong>\{input_tokens.stringify()}</strong></div><div class=\"metric\">输出 token<strong>\{output_tokens.stringify()}</strong></div><div class=\"metric\">缓存读取 token<strong>\{cache_read_tokens.stringify()}</strong></div></div></html>",
    )
    conn.end_response()
    return
  }
  send_json(conn, method_, {
    "source": "moongate",
    "total_requests": total_requests,
    "successful_responses": successful_responses,
    "failed_responses": failed_responses,
    "input_tokens": input_tokens,
    "output_tokens": output_tokens,
    "cache_read_tokens": cache_read_tokens,
  })
}
