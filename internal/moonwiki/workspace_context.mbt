///|
struct WorkspaceContext {
  requested_root : String
  suite_root : String
  books_root : String
  state_dir : String
  tmp_root : String
  product_registry_path : String
} derive(Debug, Eq)

///|
fn workspace_context(workspace_root : String) -> WorkspaceContext {
  let requested_root = @pathx.normalize(workspace_root)
  let suite_root = moonsuite_root(requested_root)
  {
    requested_root,
    suite_root,
    books_root: moonsuite_books_root(suite_root),
    state_dir: moonsuite_state_dir(suite_root),
    tmp_root: moonsuite_tmp_root(suite_root),
    product_registry_path: moonsuite_product_registry_path(suite_root),
  }
}

///|
fn workspace_context_json(context : WorkspaceContext) -> Json {
  {
    "requested_root": context.requested_root,
    "suite_root": context.suite_root,
    "books_root": context.books_root,
    "state_dir": context.state_dir,
    "tmp_root": context.tmp_root,
    "product_registry_path": context.product_registry_path,
  }
}
