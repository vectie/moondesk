///|
pub fn moonsuite_root(root : String) -> String {
  @moonsuite.suite_root_for_workspace_root(root)
}

///|
pub fn moonsuite_state_dir(root : String) -> String {
  @moonsuite.state_dir(moonsuite_root(root))
}

///|
pub fn moonsuite_books_root(root : String) -> String {
  @moonsuite.books_root(moonsuite_root(root))
}

///|
pub fn moonsuite_inbox_root(root : String) -> String {
  @moonsuite.inbox_root(moonsuite_root(root))
}

///|
pub fn moonsuite_exports_root(root : String) -> String {
  @moonsuite.exports_root(moonsuite_root(root))
}

///|
pub fn moonsuite_tmp_root(root : String) -> String {
  @moonsuite.tmp_root(moonsuite_root(root))
}

///|
pub fn moonsuite_products_root(root : String) -> String {
  @moonsuite.products_root(moonsuite_root(root))
}

///|
pub fn moonsuite_product_dir(root : String, product_id : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, product_id).state_path
}

///|
pub fn moonsuite_product_artifact_for_workspace_root(
  root : String,
  product_id : String,
  relative : String,
) -> String {
  @moonsuite.product_artifact_for_workspace_root(root, product_id, relative)
}

///|
fn moonsuite_product_dir_for_workspace_root(
  root : String,
  product_id : String,
) -> String {
  @moonsuite.product_home_for_workspace_root(root, product_id).state_path
}

///|
fn moonsuite_product_display_artifact(
  product_id : String,
  relative : String,
) -> String {
  @desk.moonsuite_product_display_artifact(product_id, relative)
}

///|
pub fn moonsuite_services_root(root : String) -> String {
  @moonsuite.services_root(moonsuite_root(root))
}

///|
pub fn moonsuite_product_service_path(
  root : String,
  product_id : String,
) -> String {
  @moonsuite.product_home_for_workspace_root(root, product_id).service_path
}

///|
pub fn moonsuite_suite_json_path(root : String) -> String {
  @moonsuite.suite_manifest_path(moonsuite_root(root))
}

///|
pub fn moonsuite_product_registry_path(root : String) -> String {
  @moonsuite.product_registry_path(moonsuite_root(root))
}

///|
fn moonsuite_product_ids() -> Array[String] {
  @moonsuite.default_product_ids()
}

///|
fn moonsuite_product_registry(root : String) -> Json {
  @moonsuite.product_registry(moonsuite_root(root))
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
      @moonsuite.cache_root(moonsuite_root(root)),
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
      @moonsuite.suite_manifest(moonsuite_root(root)).stringify(indent=2) + "\n",
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
