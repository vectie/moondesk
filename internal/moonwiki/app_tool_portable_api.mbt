///|
async fn app_tool_portable_api_dependency_paths(
  bundle_root : String,
  copied_paths : Array[String],
) -> Array[String] {
  let paths : Array[String] = []
  for relative in copied_paths {
    if !app_tool_scan_text_asset(relative) ||
      relative == "portable-runtime.js" ||
      relative == "portable-api-snapshot.json" {
      continue
    }
    let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
      _ => continue
    }
    if app_tool_has_api_dependency_text(text) {
      app_tool_push_unique(paths, relative)
    }
  }
  paths
}

///|
async fn app_tool_portable_api_reference_routes(
  bundle_root : String,
  copied_paths : Array[String],
) -> Array[String] {
  let routes : Array[String] = []
  for relative in copied_paths {
    if !app_tool_scan_text_asset(relative) ||
      relative == "portable-runtime.js" ||
      relative == "portable-api-snapshot.json" {
      continue
    }
    let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
      _ => continue
    }
    for route in app_tool_api_reference_routes_from_text(text) {
      app_tool_push_unique(routes, route)
    }
  }
  routes
}

///|
fn app_tool_api_reference_routes_from_text(text : String) -> Array[String] {
  let routes : Array[String] = []
  let mut tail = text
  while true {
    match tail.find("/api/") {
      Some(index) => {
        let candidate = tail[index:].to_owned()
        let route = app_tool_take_api_reference_route(candidate)
        if route != "" {
          app_tool_push_unique(routes, route)
        }
        let next_start = index + "/api/".length()
        if next_start >= tail.length() {
          break
        }
        tail = tail[next_start:].to_owned()
      }
      None => break
    }
  }
  routes
}

///|
fn app_tool_take_api_reference_route(text : String) -> String {
  let mut end = text.length()
  for
    delimiter in [
      "\"", "'", "`", " ", "\n", "\r", "\t", "<", ">", ")", "(", ",", ";", "]", "[",
      "{", "}",
    ] {
    match text.find(delimiter) {
      Some(index) if index > 0 && index < end => end = index
      _ => ()
    }
  }
  text[:end].to_owned()
}

///|
fn app_tool_portable_api_unsupported_routes(
  api_reference_routes : Array[String],
  api_snapshot_routes : Array[String],
) -> Array[String] {
  let unsupported : Array[String] = []
  for route in api_reference_routes {
    if !app_tool_api_route_is_supported(route, api_snapshot_routes) {
      app_tool_push_unique(unsupported, route)
    }
  }
  unsupported
}

///|
fn app_tool_api_route_is_supported(
  route : String,
  api_snapshot_routes : Array[String],
) -> Bool {
  for supported in api_snapshot_routes {
    if route == supported ||
      route.has_prefix(supported + "?") ||
      route.has_prefix(supported + "#") {
      return true
    }
  }
  if app_tool_workspace_file_api_route_is_supported(route) {
    return true
  }
  false
}

///|
fn app_tool_workspace_file_api_route_is_supported(route : String) -> Bool {
  if !route.has_prefix("/api/workspaces/") {
    return false
  }
  route.contains("/raw?path=") ||
  route.contains("/preview?path=") ||
  route.contains("/entries?path=") ||
  route.contains("/file/") ||
  route.contains("/site/")
}

///|
fn app_tool_scan_text_asset(relative : String) -> Bool {
  relative.has_suffix(".html") ||
  relative.has_suffix(".js") ||
  relative.has_suffix(".mjs") ||
  relative.has_suffix(".css") ||
  relative.has_suffix(".json")
}

///|
fn app_tool_has_api_dependency_text(text : String) -> Bool {
  text.contains("/api/") ||
  text.contains("http://127.0.0.1") ||
  text.contains("http://localhost") ||
  text.contains("https://localhost")
}

///|
fn app_tool_portable_api_snapshot_routes() -> Array[String] {
  [
    "/api/workspaces", "/api/books/patterns", "/api/books/base-types", "/api/books/template-registry",
  ]
}

///|
async fn app_tool_portable_api_snapshot(
  root : String,
  book_id : String,
) -> Json {
  let responses : Map[String, Json] = {}
  responses["/api/workspaces"] = discover_workspaces(root).to_json()
  responses["/api/books/patterns"] = Json::array(
    book_pattern_records_for_workspace(root),
  )
  responses["/api/books/base-types"] = Json::array(
    book_base_type_records_for_workspace(root),
  )
  responses["/api/books/template-registry"] = book_template_registry_status(
    root,
  )
  {
    "kind": "portable-app-tool-api-snapshot",
    "snapshot_version": "1",
    "book_id": book_id,
    "generated_at": @async.now().to_string(),
    "method": "GET",
    "routes": json_from_string_array(app_tool_portable_api_snapshot_routes()),
    "responses": Json::object(responses),
  }
}

///|
async fn app_tool_write_offline_api_snapshot(
  bundle_root : String,
  copied_paths : Array[String],
  api_dependency_paths : Array[String],
  api_snapshot : Json,
  api_offline_paths : Array[String],
  api_dependency_warnings : Array[String],
  api_unsupported_routes : Array[String],
) -> Unit {
  @fsx.write_to_file(
    @pathx.join(bundle_root, "portable-api-snapshot.json"),
    api_snapshot.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "portable-runtime.js"),
    app_tool_portable_api_runtime_js(api_snapshot),
    create=0o644,
  )
  app_tool_push_unique(copied_paths, "portable-api-snapshot.json")
  app_tool_push_unique(copied_paths, "portable-runtime.js")
  for relative in copied_paths {
    if relative.has_suffix(".html") {
      app_tool_inject_portable_runtime(bundle_root, relative, api_offline_paths)
    }
  }
  if api_dependency_paths.length() > 0 && api_offline_paths.length() == 0 {
    for relative in api_dependency_paths {
      app_tool_push_unique(api_dependency_warnings, relative)
    }
  } else {
    for relative in api_dependency_paths {
      let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
        _ => continue
      }
      if app_tool_has_api_dependency_outside_portable_runtime_text(text) ||
        app_tool_has_unsupported_api_route_text(text, api_unsupported_routes) {
        app_tool_push_unique(api_dependency_warnings, relative)
      }
    }
  }
}

///|
fn app_tool_offline_api_mode(
  api_dependency_paths : Array[String],
  api_offline_paths : Array[String],
  api_dependency_warnings : Array[String],
) -> String {
  if api_dependency_warnings.length() > 0 {
    "unresolved-api-dependencies"
  } else if api_dependency_paths.length() > 0 || api_offline_paths.length() > 0 {
    "offline-snapshot-runtime"
  } else {
    "offline-snapshot"
  }
}

///|
fn app_tool_has_api_dependency_outside_portable_runtime_text(
  text : String,
) -> Bool {
  let lower = text.to_lower()
  lower.contains("href=\"/api") ||
  lower.contains("href='/api") ||
  lower.contains("src=\"/api") ||
  lower.contains("src='/api") ||
  lower.contains("action=\"/api") ||
  lower.contains("action='/api") ||
  lower.contains("url(/api") ||
  lower.contains("url('/api") ||
  lower.contains("url(\"/api")
}

///|
fn app_tool_has_unsupported_api_route_text(
  text : String,
  api_unsupported_routes : Array[String],
) -> Bool {
  for route in api_unsupported_routes {
    if text.contains(route) {
      return true
    }
  }
  false
}

///|
async fn app_tool_inject_portable_runtime(
  bundle_root : String,
  relative : String,
  api_offline_paths : Array[String],
) -> Unit {
  let path = @pathx.join(bundle_root, relative)
  let html = @fs.read_file(path).text() catch { _ => return }
  let injected = app_tool_inject_html_portable_runtime(
    html,
    app_tool_api_runtime_src_for_relative(relative),
  )
  if injected != html {
    @fsx.write_to_file(path, injected, create=0o644) catch {
      _ => return
    }
  }
  app_tool_push_unique(api_offline_paths, relative)
}

///|
fn app_tool_api_runtime_src_for_relative(relative : String) -> String {
  let pieces = relative.split("/").to_array()
  let mut depth = if pieces.length() > 0 { pieces.length() - 1 } else { 0 }
  let prefixes : Array[String] = []
  while depth > 0 {
    prefixes.push("..")
    depth -= 1
  }
  if prefixes.length() == 0 {
    "./portable-runtime.js"
  } else {
    prefixes.join("/") + "/portable-runtime.js"
  }
}

///|
fn app_tool_inject_html_portable_runtime(
  html : String,
  runtime_src : String,
) -> String {
  if html.contains("portable-runtime.js") {
    return html
  }
  let tag = "<script src=\"\{app_tool_html_escape(runtime_src)}\" data-portable-app-runtime></script>\n"
  let lower = html.to_lower()
  match lower.find("<script") {
    Some(index) => html[:index].to_owned() + tag + html[index:].to_owned()
    None =>
      match lower.find("</head>") {
        Some(index) => html[:index].to_owned() + tag + html[index:].to_owned()
        None =>
          match lower.find("<body") {
            Some(index) =>
              html[:index].to_owned() + tag + html[index:].to_owned()
            None => tag + html
          }
      }
  }
}

///|
fn app_tool_portable_api_runtime_js(api_snapshot : Json) -> String {
  [
    "(function () {",
    "  'use strict';",
    "  const snapshot = \{api_snapshot.stringify(indent=2)};",
    "  const responses = snapshot.responses || {};",
    "  const originalFetch = typeof window.fetch === 'function' ? window.fetch.bind(window) : null;",
    "  const runtimeScriptUrl = document.currentScript && document.currentScript.src ? document.currentScript.src : '';",
    "  const bundleBaseUrl = runtimeScriptUrl ? new URL('.', runtimeScriptUrl).href : new URL('.', window.location.href).href;",
    "  function apiKey(input) {",
    "    const raw = typeof input === 'string' ? input : input && input.url;",
    "    if (!raw) return '';",
    "    try {",
    "      const url = new URL(raw, window.location.href);",
    "      if (url.pathname && url.pathname.indexOf('/api/') === 0) return url.pathname + url.search;",
    "    } catch (_) {",
    "      if (raw.indexOf('/api/') === 0) return raw;",
    "    }",
    "    return raw.indexOf('/api/') === 0 ? raw : '';",
    "  }",
    "  function jsonResponse(value, status) {",
    "    return new Response(JSON.stringify(value), {",
    "      status: status || 200,",
    "      headers: { 'content-type': 'application/json; charset=utf-8', 'x-portable-api-snapshot': 'true' }",
    "    });",
    "  }",
    "  function cleanBundlePath(raw) {",
    "    if (!raw) return '';",
    "    let decoded = '';",
    "    try { decoded = decodeURIComponent(String(raw)); } catch (_) { decoded = String(raw); }",
    "    decoded = decoded.replace(/^\\/+/, '');",
    "    const pieces = decoded.split('/');",
    "    const out = [];",
    "    for (const piece of pieces) {",
    "      if (!piece || piece === '.') continue;",
    "      if (piece === '..') return '';",
    "      out.push(piece);",
    "    }",
    "    return out.join('/');",
    "  }",
    "  function staticUrlForPath(path) {",
    "    const clean = cleanBundlePath(path);",
    "    return clean ? new URL(clean, bundleBaseUrl).href : '';",
    "  }",
    "  function staticFetch(path) {",
    "    if (!originalFetch) return Promise.reject(new TypeError('fetch is unavailable for portable bundle assets.'));",
    "    const target = staticUrlForPath(path);",
    "    return target ? originalFetch(target) : Promise.resolve(jsonResponse({ ok: false, status: 'invalid_path', path: path }, 400));",
    "  }",
    "  function contentKind(path) {",
    "    const lower = String(path || '').toLowerCase();",
    "    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return 'markdown';",
    "    if (lower.endsWith('.json')) return 'json';",
    "    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'html';",
    "    if (lower.endsWith('.csv') || lower.endsWith('.tsv')) return 'table';",
    "    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return 'spreadsheet';",
    "    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.svg')) return 'image';",
    "    return 'text';",
    "  }",
    "  function portableWorkspaceResponse(key) {",
    "    let url;",
    "    try { url = new URL(key, window.location.href); } catch (_) { return null; }",
    "    const segments = url.pathname.split('/').filter(Boolean);",
    "    if (segments.length < 4 || segments[0] !== 'api' || segments[1] !== 'workspaces') return null;",
    "    const workspaceId = segments[2];",
    "    const action = segments[3];",
    "    let relative = '';",
    "    if (action === 'raw' || action === 'preview' || action === 'entries') {",
    "      relative = cleanBundlePath(url.searchParams.get('path') || '');",
    "    } else if (action === 'file') {",
    "      relative = cleanBundlePath(segments.slice(4).join('/'));",
    "    } else if (action === 'site') {",
    "      relative = cleanBundlePath(['book', 'site', 'generated'].concat(segments.slice(4)).join('/'));",
    "    } else {",
    "      return null;",
    "    }",
    "    if (!relative) return jsonResponse({ ok: false, status: 'invalid_path', route: key }, 400);",
    "    if (action === 'raw' || action === 'file' || action === 'site') {",
    "      return staticFetch(relative);",
    "    }",
    "    if (action === 'preview') {",
    "      return staticFetch(relative).then(function (response) {",
    "        if (!response.ok) return jsonResponse({ ok: false, status: 'not_found', route: key, path: relative }, response.status || 404);",
    "        const kind = contentKind(relative);",
    "        if (kind === 'image' || kind === 'spreadsheet') {",
    "          return jsonResponse({ workspace_id: workspaceId, entry: { workspace_id: workspaceId, path: relative, kind: kind, writable: false }, body: '/api/workspaces/' + encodeURIComponent(workspaceId) + '/raw?path=' + encodeURIComponent(relative), warnings: [] }, 200);",
    "        }",
    "        return response.text().then(function (body) {",
    "          return jsonResponse({ workspace_id: workspaceId, entry: { workspace_id: workspaceId, path: relative, kind: kind, writable: false }, body: body, warnings: [] }, 200);",
    "        });",
    "      });",
    "    }",
    "    if (action === 'entries') {",
    "      return jsonResponse([{ workspace_id: workspaceId, path: relative, name: relative.split('/').pop() || relative, kind: contentKind(relative), writable: false }], 200);",
    "    }",
    "    return null;",
    "  }",
    "  window.__PORTABLE_APP_API_SNAPSHOT__ = snapshot;",
    "  window.fetch = function (input, init) {",
    "    const method = ((init && init.method) || (input && input.method) || 'GET').toUpperCase();",
    "    const key = apiKey(input);",
    "    const pathKey = key && key.split('?')[0];",
    "    if (method === 'GET' && key && Object.prototype.hasOwnProperty.call(responses, key)) {",
    "      return Promise.resolve(jsonResponse(responses[key], 200));",
    "    }",
    "    if (method === 'GET' && pathKey && Object.prototype.hasOwnProperty.call(responses, pathKey)) {",
    "      return Promise.resolve(jsonResponse(responses[pathKey], 200));",
    "    }",
    "    if (method === 'GET' && key && key.indexOf('/api/workspaces/') === 0) {",
    "      const workspaceResponse = portableWorkspaceResponse(key);",
    "      if (workspaceResponse) return Promise.resolve(workspaceResponse);",
    "    }",
    "    if (method === 'GET' && key && key.indexOf('/api/') === 0) {",
    "      return Promise.resolve(jsonResponse({ ok: false, status: 'offline_snapshot_miss', route: key, message: 'This portable app-tool bundle does not include an offline snapshot for the requested API route.' }, 404));",
    "    }",
    "    if (originalFetch) return originalFetch(input, init);",
    "    return Promise.reject(new TypeError('fetch is unavailable and no portable API snapshot route matched.'));",
    "  };",
    "}());",
    "",
  ].join("\n")
}
