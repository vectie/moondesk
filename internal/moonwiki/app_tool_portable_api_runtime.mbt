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
