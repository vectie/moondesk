///|
test "demo decoder is available on every selected target" {
  assert_eq(js_text_decode([65], "utf-8"), "A")
  assert_eq(js_text_decode([65, 233], "windows-1252"), "Aé")
}
