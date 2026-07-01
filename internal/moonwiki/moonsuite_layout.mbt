///|
pub fn moonsuite_root(root : String) -> String {
  @pathx.normalize(root)
}

///|
pub fn moonsuite_state_dir(root : String) -> String {
  @pathx.join(moonsuite_root(root), ".moonsuite")
}

///|
pub fn moonsuite_books_root(root : String) -> String {
  @pathx.join(moonsuite_root(root), "books")
}

///|
pub fn moonsuite_inbox_root(root : String) -> String {
  @pathx.join(moonsuite_root(root), "inbox")
}

///|
pub fn moonsuite_exports_root(root : String) -> String {
  @pathx.join(moonsuite_root(root), "exports")
}

///|
pub fn moonsuite_tmp_root(root : String) -> String {
  @pathx.join(moonsuite_root(root), ".tmp")
}

///|
pub fn moonsuite_products_root(root : String) -> String {
  @pathx.join(moonsuite_state_dir(root), "products")
}

///|
pub fn moonsuite_product_dir(root : String, product_id : String) -> String {
  @pathx.join(moonsuite_products_root(root), product_id)
}

///|
pub fn moonsuite_services_root(root : String) -> String {
  @pathx.join(moonsuite_state_dir(root), "services")
}

///|
pub fn moonsuite_product_service_path(
  root : String,
  product_id : String,
) -> String {
  @pathx.join(moonsuite_product_dir(root, product_id), "service.json")
}

///|
pub fn moonsuite_suite_json_path(root : String) -> String {
  @pathx.join(moonsuite_state_dir(root), "suite.json")
}

///|
pub fn moonsuite_product_registry_path(root : String) -> String {
  @pathx.join(moonsuite_state_dir(root), "product-registry.json")
}

///|
fn moonsuite_product_ids() -> Array[String] {
  [
    "moondesk", "moonbook", "moonwiki", "mooncode", "moonclaw", "moontown", "moonstat",
    "moonfish", "moonmoon", "moonrobo", "bookkeeper", "lepusa", "rabbita",
  ]
}

///|
fn moonsuite_product_registry(root : String) -> Json {
  let entries : Array[Json] = []
  for product_id in moonsuite_product_ids() {
    entries.push({
      "id": product_id,
      "name": moonsuite_product_display_name(product_id),
      "kind": "moon-suite-product",
      "state_path": moonsuite_product_dir(root, product_id),
      "service_path": moonsuite_product_service_path(root, product_id),
      "repo_path": "",
      "status": "installed",
      "capabilities": Json::array([]),
    })
  }
  { "kind": "moonsuite-product-registry.v1", "products": Json::array(entries) }
}

///|
fn moonsuite_product_display_name(product_id : String) -> String {
  match product_id {
    "moondesk" => "Moondesk"
    "moonbook" => "MoonBook"
    "moonwiki" => "MoonWiki"
    "mooncode" => "MoonCode"
    "moonclaw" => "MoonClaw"
    "moontown" => "Moontown"
    "moonstat" => "MoonStat"
    "moonfish" => "MoonFish"
    "moonmoon" => "MoonMoon"
    "moonrobo" => "MoonRobo"
    "bookkeeper" => "Bookkeeper"
    "lepusa" => "Lepusa"
    "rabbita" => "Rabbita"
    _ => product_id
  }
}

///|
pub async fn prepare_moonsuite_workspace_root(root : String) -> Bool {
  for
    path in [
      moonsuite_books_root(root),
      moonsuite_inbox_root(root),
      moonsuite_exports_root(root),
      moonsuite_tmp_root(root),
      moonsuite_state_dir(root),
      moonsuite_products_root(root),
      moonsuite_services_root(root),
      @pathx.join(moonsuite_state_dir(root), "cache"),
    ] {
    @fsx.make_directory(path, recursive=true, exists_ok=true) catch {
      _ => return false
    }
  }
  for product_id in moonsuite_product_ids() {
    @fsx.make_directory(
      moonsuite_product_dir(root, product_id),
      recursive=true,
      exists_ok=true,
    ) catch {
      _ => return false
    }
  }
  if !@fsx.exists(moonsuite_suite_json_path(root)) {
    let suite : Json = {
      "kind": "moonsuite-root.v1",
      "root_path": moonsuite_root(root),
      "books_path": moonsuite_books_root(root),
      "tmp_path": moonsuite_tmp_root(root),
    }
    @fsx.write_to_file(
      moonsuite_suite_json_path(root),
      suite.stringify(indent=2) + "\n",
      create=0o644,
    ) catch {
      _ => return false
    }
  }
  if !@fsx.exists(moonsuite_product_registry_path(root)) {
    @fsx.write_to_file(
      moonsuite_product_registry_path(root),
      moonsuite_product_registry(root).stringify(indent=2) + "\n",
      create=0o644,
    ) catch {
      _ => return false
    }
  }
  true
}
