///|
pub type Session

///|
pub suberror TerminalError {
  TerminalError(String)
}

///|
#borrow(directory)
extern "c" fn open_pty(
  directory : Bytes,
  columns : Int32,
  rows : Int32,
) -> Session = "moondesk_pty_open"

///|
#borrow(session)
extern "c" fn pty_status(session : Session) -> Int32 = "moondesk_pty_status"

///|
#borrow(session, cursor)
extern "c" fn read_pty(session : Session, cursor : FixedArray[Int64]) -> Bytes = "moondesk_pty_read"

///|
#borrow(session, data)
extern "c" fn write_pty(session : Session, data : Bytes) -> Int32 = "moondesk_pty_write"

///|
#borrow(session)
extern "c" fn resize_pty(
  session : Session,
  columns : Int32,
  rows : Int32,
) -> Int32 = "moondesk_pty_resize"

///|
#borrow(session)
extern "c" fn close_pty(session : Session) -> Unit = "moondesk_pty_close"

///|
pub fn Session::open(
  directory : String,
  columns~ : Int32 = 100,
  rows~ : Int32 = 30,
) -> Session raise TerminalError {
  let session = open_pty(@utf8.encode(directory), columns, rows)
  if pty_status(session) == -2 {
    raise TerminalError("The terminal could not start in this folder")
  }
  session
}

///|
/// Returns retained output and its byte positions. A later start indicates
/// that older scrollback was discarded while the client was disconnected.
pub fn Session::read(self : Session, after : Int64) -> (Bytes, Int64, Int64) {
  let cursor : FixedArray[Int64] = FixedArray::make(2, 0)
  cursor[0] = after
  let output = read_pty(self, cursor)
  (output, cursor[0], cursor[1])
}

///|
/// Returns the number of bytes accepted; retry remaining bytes on a later tick.
pub fn Session::write(self : Session, data : Bytes) -> Int32 {
  write_pty(self, data)
}

///|
pub fn Session::resize(self : Session, columns : Int32, rows : Int32) -> Bool {
  resize_pty(self, columns, rows) == 0
}

///|
/// -1 while running, otherwise the shell exit code.
pub fn Session::status(self : Session) -> Int32 {
  pty_status(self)
}

///|
pub fn Session::close(self : Session) -> Unit {
  close_pty(self)
}
