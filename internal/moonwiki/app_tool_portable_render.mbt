///|
fn app_tool_portable_index_html(
  book_id : String,
  title : String,
  entrypoint : String,
  entrypoints : Array[String],
  api_warnings : Array[String],
  api_offline_paths : Array[String],
) -> String {
  let links : Array[String] = []
  for item in entrypoints {
    links.push(
      "<a class=\"entry-link\" href=\"\{app_tool_html_escape(item)}\">\{app_tool_html_escape(item)}</a>",
    )
  }
  let warning = if api_warnings.length() == 0 {
    if api_offline_paths.length() == 0 {
      "<p class=\"status good\">Standalone-ready: run <code>run-local.command</code> or serve this folder from a static HTTP host.</p>"
    } else {
      "<p class=\"status good\">Standalone-ready: run <code>run-local.command</code>; copied app assets include a portable offline API snapshot runtime.</p>"
    }
  } else {
    "<p class=\"status warn\">Standalone warning: copied assets still reference APIs that are not covered by the portable runtime in \{app_tool_html_escape(api_warnings.join(", "))}.</p>"
  }
  [
    "<!doctype html>",
    "<html>",
    "<head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>\{app_tool_html_escape(title)}</title>",
    "<style>",
    "body{margin:0;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;background:#f6f7f9;color:#17202a}",
    "header{display:flex;gap:16px;align-items:center;justify-content:space-between;padding:14px 18px;border-bottom:1px solid #d7dde5;background:#fff}",
    "h1{font-size:18px;line-height:1.25;margin:0}.meta{font-size:12px;color:#53606f;margin-top:4px}",
    ".actions{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end}.entry-link{border:1px solid #b8c2ce;background:#fff;border-radius:6px;padding:7px 10px;color:#0f4c81;text-decoration:none;font-size:13px}",
    "code{background:#edf1f5;border:1px solid #d7dde5;border-radius:4px;padding:1px 4px}",
    ".status{margin:0;padding:9px 18px;font-size:13px;border-bottom:1px solid #d7dde5}.good{background:#e9f7ef;color:#176137}.warn{background:#fff7dd;color:#7a4a00}",
    "iframe{display:block;width:100%;height:calc(100vh - 102px);border:0;background:#fff}",
    "</style>",
    "</head>",
    "<body>",
    "<header><div><h1>\{app_tool_html_escape(title)}</h1><div class=\"meta\">Portable app-tool bundle for \{app_tool_html_escape(book_id)}</div></div><nav class=\"actions\">\{links.join("")}</nav></header>",
    warning,
    "<iframe src=\"\{app_tool_html_escape(entrypoint)}\" title=\"\{app_tool_html_escape(title)}\"></iframe>",
    "</body>",
    "</html>",
    "",
  ].join("\n")
}

///|
fn app_tool_portable_readme(
  book_id : String,
  entrypoint : String,
  api_warnings : Array[String],
  api_offline_paths : Array[String],
) -> String {
  let status = if api_warnings.length() == 0 {
    if api_offline_paths.length() == 0 {
      "Copied app assets are bundled for static hosting."
    } else {
      "Copied app assets include `portable-api-snapshot.json` and `portable-runtime.js`, which serve supported read-only API calls from the bundle."
    }
  } else {
    "Copied text assets still reference APIs not covered by the portable runtime: " +
    api_warnings.join(", ") +
    ". A standalone host should provide those APIs or the tool should avoid resource links that bypass the bundled runtime."
  }
  [
    "# Portable App Tool Bundle",
    "",
    "- Book: `\{book_id}`",
    "- Entrypoint: `\{entrypoint}`",
    "- Runtime: served static bundle",
    "- Status: \{status}",
    "- Local launcher: `run-local.command`",
    "- Static server: `python3 serve.py`",
    "- Portable runtime: `portable-runtime.js`",
    "- API snapshot: `portable-api-snapshot.json`",
    "",
    "Run `./run-local.command` from this folder, or run `python3 serve.py`, then open the printed `http://127.0.0.1:<port>/index.html` URL. A raw `file://` open is not a supported runtime because generated JavaScript modules, fetch calls, and relative assets need one served origin.",
    "",
  ].join("\n")
}

///|
fn app_tool_html_escape(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
  .to_string()
}
