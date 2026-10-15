///|
async test "interactive terminal is a PTY, preserves bytes, resizes, and interrupts" {
  let session = @terminal.Session::open("/tmp", columns=91, rows=27)
  defer session.close()
  let command = b"printf '__PTY__'; test -t 0 && printf 'yes'; printf '__SIZE__'; stty size; printf '__UTF8__\\342\\230\\203__END__\\n'\n"
  assert_eq(session.write(command), command.length())
  let mut position : Int64 = 0
  let mut output = ""
  for _ in 0..<500 {
    @async.sleep(20)
    let (bytes, _, next) = session.read(position)
    position = next
    output += @utf8.decode_lossy(bytes)
    if output.contains("__UTF8__☃__END__") {
      break
    }
  }
  assert_true(output.contains("__PTY__yes"), msg=output)
  assert_true(output.contains("27 91"))
  assert_true(output.contains("__UTF8__☃__END__"))
  assert_true(session.resize(103, 31))
  ignore(session.write(b"stty size; sleep 30\n"))
  @async.sleep(100)
  ignore(session.write(b"\x03"))
  @async.sleep(100)
  ignore(session.write(b"printf '__AFTER_INTERRUPT__\\n'\n"))
  let mut after = ""
  for _ in 0..<100 {
    @async.sleep(20)
    let (bytes, _, next) = session.read(position)
    position = next
    after += @utf8.decode_lossy(bytes)
    if after.contains("__AFTER_INTERRUPT__\r\n") {
      break
    }
  }
  assert_true(after.contains("31 103"))
  assert_true(after.contains("__AFTER_INTERRUPT__\r\n"))
  let (replayed, start, _) = session.read(0)
  assert_eq(start, 0)
  assert_true(@utf8.decode_lossy(replayed).contains("__PTY__yes"))
  ignore(session.write(b"exit 7\n"))
  for _ in 0..<100 {
    if session.status() != -1 {
      break
    }
    @async.sleep(20)
  }
  assert_eq(session.status(), 7)
  session.close()
}
