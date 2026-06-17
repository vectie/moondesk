///|
/// Optional moonstat client plugin for moondesk.
///
/// Provides usage stats and provider management via moonstat.

pub const DEFAULT_PORT : Int = 15721
pub const DEFAULT_HOST : String = "127.0.0.1"

pub struct Client {
  base_url : String
}

pub fn discover() -> Client {
  Client::{ base_url: "http://\{DEFAULT_HOST}:\{DEFAULT_PORT}" }
}

pub async fn Client::health(self : Client) -> Result[Json, String] {
  self.get("/health")
}

pub async fn Client::get_usage_summary(self : Client) -> Result[Json, String] {
  self.get("/usage/summary")
}

pub async fn Client::get_usage_trends(self : Client) -> Result[Json, String] {
  self.get("/usage/trends")
}

pub async fn Client::get(self : Client, path : String) -> Result[Json, String] {
  let url = self.base_url + path
  let client = try @http.Client::new(url, headers={}) catch {
    err => return Err("client error: \{err}")
  }
  defer client.close()
  let response = try client.get("") catch {
    err => return Err("request error: \{err}")
  }
  if response.code == 200 {
    let body = try client.read_all().text() catch {
      err => return Err("read error: \{err}")
    }
    let parsed = try @json.parse(body) catch {
      _ => return Err("parse error")
    }
    Ok(parsed)
  } else {
    Err("HTTP \{response.code}")
  }
}
