///|
fn moondesk_access_env(name : String) -> String {
  @env.get_env_var(name).unwrap_or("").trim().to_owned()
}

///|
fn moondesk_valid_authority(value : String) -> Bool {
  !value.is_empty() &&
  value
  .to_array()
  .all(c => {
    (c >= 'a' && c <= 'z') ||
    (c >= '0' && c <= '9') ||
    c == '.' ||
    c == '-' ||
    c == ':' ||
    c == '[' ||
    c == ']'
  })
}

///|
fn moondesk_loopback_authority(value : String) -> Bool {
  for name in ["localhost", "127.0.0.1", "[::1]"] {
    if value == name {
      return true
    }
    if value.has_prefix(name + ":") {
      let port = value[name.length() + 1:].to_owned()
      if port.is_empty() || !port.to_array().all(c => c >= '0' && c <= '9') {
        return false
      }
      let number = @string.parse_int(port) catch { _ => return false }
      return number > 0 && number <= 65535
    }
  }
  false
}

///|
fn moondesk_host_matches(host : String, configured : String) -> Bool {
  let value = host.to_lower()
  if !moondesk_valid_authority(value) {
    return false
  }
  if moondesk_loopback_authority(value) {
    return true
  }
  configured
  .split(",")
  .any(entry => {
    let expected = entry.trim().to_owned().to_lower()
    moondesk_valid_authority(expected) && value == expected
  })
}

///|
fn moondesk_active_operator(value : Json) -> Bool {
  value is { "state": String("Active"), "roles": Array(roles), .. } &&
  roles.any(role => role == Json::string("PlatformOperator"))
}

///|
fn moondesk_identity_authority_matches(endpoint : String, host : String) -> Bool {
  moondesk_valid_authority(host) &&
  (endpoint == "http://" + host || endpoint == "https://" + host)
}

///|
async fn moondesk_bounded_identity_text(
  reader : &@io.Reader,
  limit : Int,
) -> String? {
  let bytes = FixedArray::make(limit + 1, b'\x00')
  let mut length = 0
  while length <= limit {
    let count = reader.read(bytes, offset=length, max_len=limit + 1 - length)
    if count == 0 {
      return Some(
        @encoding/utf8.decode(bytes.unsafe_reinterpret_as_bytes()[:length]),
      )
    }
    length += count
  }
  None
}

///|
// Reuse LunaNexa's cookie session and authoritative role lookup. A claimed
// client role, forwarded header or public Host is never authentication.
async fn moondesk_operator_authorized(cookie : String) -> Bool {
  let endpoint = moondesk_access_env("MOONDESK_IDENTITY_ENDPOINT")
  let host = moondesk_access_env("MOONDESK_IDENTITY_HOST")
  guard !cookie.is_empty() &&
    cookie.length() <= 16384 &&
    !endpoint.is_empty() &&
    moondesk_identity_authority_matches(endpoint, host) else {
    return false
  }
  let client = @http.Client(endpoint, headers={
    "Cookie": cookie,
    "Origin": endpoint,
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Dest": "empty",
    "Accept": "application/json",
  })
  defer client.close()
  let response = client.get("/auth/session")
  guard response.code == 200 else { return false }
  guard moondesk_bounded_identity_text(client, 16384) is Some(text) else {
    return false
  }
  guard @json.parse(text) is { "session_token": String(bearer), .. } &&
    bearer.has_prefix("lnxs_") else {
    return false
  }
  let response = client.get("/v1/auth/self", extra_headers={
    "Authorization": "Bearer " + bearer,
  })
  guard response.code == 200 else { return false }
  guard moondesk_bounded_identity_text(client, 65536) is Some(text) else {
    return false
  }
  moondesk_active_operator(@json.parse(text))
}

///|
async fn moondesk_password_login(
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  guard request.meth is Post else {
    return send_status(conn, 405, "Method Not Allowed", "POST required\n")
  }
  guard moondesk_bounded_identity_text(body, 4096) is Some(text) else {
    return send_status(conn, 413, "Content Too Large", "Login body too large\n")
  }
  guard (@json.parse(text) catch { _ => Json::null() })
    is { "username": String(username), "password": String(password), .. } else {
    return send_status(conn, 400, "Bad Request", "Invalid login\n")
  }
  let endpoint = moondesk_access_env("MOONDESK_IDENTITY_ENDPOINT")
  let host = moondesk_access_env("MOONDESK_IDENTITY_HOST")
  guard moondesk_identity_authority_matches(endpoint, host) else {
    return send_status(
      conn, 503, "Service Unavailable", "Identity unavailable\n",
    )
  }
  let client = @http.Client(endpoint, headers={
    "Origin": endpoint,
    "Content-Type": "application/json",
  })
  defer client.close()
  let payload : Json = {
    "username": username,
    "password": password,
    "audience": "operator",
  }
  let response = client.post(
    "/auth/password",
    @encoding/utf8.encode(payload.stringify()),
  )
  guard moondesk_bounded_identity_text(client, 16384) is Some(_) else {
    return send_status(
      conn, 503, "Service Unavailable", "Invalid identity response\n",
    )
  }
  guard response.code == 200 || response.code == 201 else {
    return if response.code == 401 {
      send_status(conn, 401, "Unauthorized", "Login rejected\n")
    } else {
      send_status(conn, 503, "Service Unavailable", "Identity unavailable\n")
    }
  }
  let cookie = response.cookies.map(c => c.name + "=" + c.value).join("; ")
  guard moondesk_operator_authorized(cookie) else {
    return send_status(
      conn, 403, "Forbidden", "Active PlatformOperator required\n",
    )
  }
  // Only HttpOnly cookies are issued. Never forward the bearer response body.
  let cookies = response.cookies.filter(c => c.http_only)
  guard !cookies.is_empty() else {
    return send_status(
      conn, 503, "Service Unavailable", "Missing session cookie\n",
    )
  }
  conn.send_response(200, "OK", cookies~, extra_headers={
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  })
  conn.write(b"{\"ok\":true}")
  conn.end_response()
}

///|
async fn moondesk_public_access_gate(
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  // Public mode covers ALL requests, including spoofed loopback Host values.
  if moondesk_access_env("MOONDESK_ALLOWED_HOSTS").is_empty() {
    return false
  }
  if strip_query(request.path) == "/auth/password" {
    @async.with_timeout(15000, () => {
      moondesk_password_login(request, body, conn)
    }) catch {
      _ =>
        send_status(conn, 503, "Service Unavailable", "Identity unavailable\n")
    }
    return true
  }
  let authorized = @async.with_timeout(5000, () => {
    moondesk_operator_authorized(request.headers.get("cookie").unwrap_or(""))
  }) catch {
    _ => false
  }
  if authorized {
    return false
  }
  if request.meth is Get && strip_query(request.path) == "/" {
    conn.send_response(401, "Unauthorized", extra_headers={
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": "no-referrer",
    })
    conn.write(moondesk_operator_login_page())
    conn.end_response()
  } else {
    send_status(
      conn, 401, "Unauthorized", "Active PlatformOperator login required\n",
    )
  }
  true
}

///|
fn moondesk_operator_login_page() -> String {
  (
    #|<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>登录 MoonDesk</title>
    #|<style>body{font:17px system-ui;background:#f4f6f8;color:#172330;margin:0}main{max-width:420px;margin:10vh auto;padding:24px}label{display:block;margin-top:18px}input,button{font:inherit;box-sizing:border-box;width:100%;min-height:48px;margin-top:8px;padding:10px;border:1px solid #8795a5;border-radius:8px}button{background:#173c65;color:white}#status{min-height:3em}</style>
    #|<main><h1>登录 MoonDesk</h1><p>使用现有 LunaNexa 管理员账号进入共享工作空间。</p><form id="login"><label for="username">用户名</label><input id="username" autocomplete="username" required><label for="password">密码</label><input id="password" type="password" autocomplete="current-password" required><button id="submit">登录并进入</button></form><p id="status" role="status" aria-live="polite"></p><p>仅向有效的平台管理员开放。密码由平台身份服务验证，不在 MoonDesk 保存。</p></main>
    #|<script>document.querySelector('#login').addEventListener('submit',async e=>{e.preventDefault();const b=document.querySelector('#submit'),s=document.querySelector('#status');b.disabled=true;s.textContent='正在登录…';try{const r=await fetch('/auth/password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:document.querySelector('#username').value,password:document.querySelector('#password').value})});document.querySelector('#password').value='';if(r.ok){location.replace('/')}else{s.textContent=r.status===403?'账号没有有效的平台管理员权限。':r.status===401?'用户名或密码不正确。':'身份服务暂时不可用。'}}catch{s.textContent='身份服务暂时不可用。'}finally{b.disabled=false}});</script></html>
  )
}
