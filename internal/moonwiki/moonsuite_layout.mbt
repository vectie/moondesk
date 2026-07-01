///|
pub fn moonsuite_root(root : String) -> String {
  @moonsuite.suite_root(root)
}

///|
pub fn moonsuite_state_dir(root : String) -> String {
  @moonsuite.state_dir(root)
}

///|
pub fn moonsuite_books_root(root : String) -> String {
  @moonsuite.books_root(root)
}

///|
pub fn moonsuite_inbox_root(root : String) -> String {
  @moonsuite.inbox_root(root)
}

///|
pub fn moonsuite_exports_root(root : String) -> String {
  @moonsuite.exports_root(root)
}

///|
pub fn moonsuite_tmp_root(root : String) -> String {
  @moonsuite.tmp_root(root)
}

///|
pub fn moonsuite_products_root(root : String) -> String {
  @moonsuite.products_root(root)
}

///|
pub fn moonsuite_product_dir(root : String, product_id : String) -> String {
  @moonsuite.product_dir(root, product_id)
}

///|
pub fn moonsuite_services_root(root : String) -> String {
  @moonsuite.services_root(root)
}

///|
pub fn moonsuite_product_service_path(
  root : String,
  product_id : String,
) -> String {
  @moonsuite.product_service_path(root, product_id)
}

///|
pub fn moonsuite_suite_json_path(root : String) -> String {
  @moonsuite.suite_manifest_path(root)
}

///|
pub fn moonsuite_product_registry_path(root : String) -> String {
  @moonsuite.product_registry_path(root)
}

///|
fn moonsuite_product_ids() -> Array[String] {
  @moonsuite.default_product_ids()
}

///|
fn moonsuite_product_registry(root : String) -> Json {
  @moonsuite.product_registry(root)
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
      @moonsuite.cache_root(root),
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
    @fsx.write_to_file(
      moonsuite_suite_json_path(root),
      @moonsuite.suite_manifest(root).stringify(indent=2) + "\n",
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
