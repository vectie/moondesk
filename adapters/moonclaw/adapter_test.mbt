///|
test "known run roots use MoonSuite product home" {
  assert_true(
    known_run_roots("/suite") == ["/suite/.moonsuite/products/moonclaw/jobs"],
  )
}
