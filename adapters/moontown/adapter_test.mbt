///|
test "snapshot paths use MoonSuite product home" {
  let paths = snapshot_paths("/suite")
  assert_eq(
    paths.town_json_path,
    "/suite/.moonsuite/products/moontown/town.json",
  )
  assert_eq(
    paths.daemon_json_path,
    "/suite/.moonsuite/products/moontown/daemon.json",
  )
  assert_eq(
    paths.standing_goals_path,
    "/suite/.moonsuite/products/moontown/standing-goals.json",
  )
  assert_eq(paths.watcher_dir, "/suite/.moonsuite/products/moontown/watchers")
}

///|
test "snapshot paths infer suite product home from book root" {
  let paths = snapshot_paths("/suite/books/research-town")
  assert_eq(
    paths.town_json_path,
    "/suite/.moonsuite/products/moontown/town.json",
  )
  assert_eq(
    paths.daemon_json_path,
    "/suite/.moonsuite/products/moontown/daemon.json",
  )
  assert_eq(
    paths.standing_goals_path,
    "/suite/.moonsuite/products/moontown/standing-goals.json",
  )
  assert_eq(paths.watcher_dir, "/suite/.moonsuite/products/moontown/watchers")
  assert_false(paths.watcher_dir.contains("/books/research-town/.moonsuite"))
}
