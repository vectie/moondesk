///|
/// The gate renders login only for the app root. Preserve that requested query,
/// never a caller-provided redirect destination. Return a script-safe JS string.
fn moondesk_operator_login_target(request_path : String) -> String {
  let target = if (request_path == "/" || request_path.has_prefix("/?")) &&
    !request_path.contains("\\") &&
    !request_path.contains("\u0000") &&
    !request_path.contains("\r") &&
    !request_path.contains("\n") &&
    !request_path.contains("#") {
    request_path
  } else {
    "/"
  }
  ToJson::to_json(target)
  .stringify()
  .replace_all(old="<", new="\\u003c")
  .replace_all(old=">", new="\\u003e")
  .replace_all(old="&", new="\\u0026")
}

///|
fn moondesk_operator_login_page(return_path~ : String = "/") -> String {
  let return_target = moondesk_operator_login_target(return_path)
  (
    $|<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>登录 MoonDesk</title>
    $|<style>body{font:17px system-ui;background:#f4f6f8;color:#172330;margin:0}main{max-width:420px;margin:10vh auto;padding:24px}label{display:block;margin-top:18px}input,button{font:inherit;box-sizing:border-box;width:100%;min-height:48px;margin-top:8px;padding:10px;border:1px solid #8795a5;border-radius:8px}button{background:#173c65;color:white}#status{min-height:3em}</style>
    $|<main><h1>登录 MoonDesk</h1><p>使用现有 LunaNexa 管理员账号进入共享工作空间。</p><form id="login"><label for="username">用户名</label><input id="username" autocomplete="username" required><label for="password">密码</label><input id="password" type="password" autocomplete="current-password" required><button id="submit">登录并进入</button></form><p id="status" role="status" aria-live="polite"></p><p>仅向有效的平台管理员开放。密码由平台身份服务验证，不在 MoonDesk 保存。</p></main>
    $|<script>document.querySelector('#login').addEventListener('submit',async e=>{e.preventDefault();const b=document.querySelector('#submit'),s=document.querySelector('#status');b.disabled=true;s.textContent='正在登录…';try{const r=await fetch('/auth/password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:document.querySelector('#username').value,password:document.querySelector('#password').value})});document.querySelector('#password').value='';if(r.ok){location.replace(\{return_target}+location.hash)}else{s.textContent=r.status===403?'账号没有有效的平台管理员权限。':r.status===401?'用户名或密码不正确。':'身份服务暂时不可用。'}}catch{s.textContent='身份服务暂时不可用。'}finally{b.disabled=false}});</script></html>
  )
}
