///|
#cfg(target="js")
struct Mouse(@dom.MouseEvent)

///|
#cfg(not(target="js"))
struct Mouse(Unit)

///|
pub(all) struct Pos {
  x : Int
  y : Int
} derive(Show, Debug)

///|
#cfg(target="js")
pub fn Mouse::screen_pos(self : Mouse) -> Pos {
  { x: self.0.get_screen_x(), y: self.0.get_screen_y() }
}

///|
#cfg(target="js")
pub fn Mouse::offset_pos(self : Mouse) -> Pos {
  { x: self.0.get_offset_x(), y: self.0.get_offset_y() }
}

///|
#cfg(target="js")
pub fn Mouse::client_pos(self : Mouse) -> Pos {
  { x: self.0.get_client_x(), y: self.0.get_client_y() }
}

///|
#cfg(target="js")
struct Keyboard(@dom.KeyboardEvent)

///|
#cfg(not(target="js"))
struct Keyboard(Unit)

///|
#cfg(target="js")
pub fn Keyboard::key(self : Keyboard) -> String {
  self.0.key()
}

///|
#cfg(target="js")
pub fn Keyboard::code(self : Keyboard) -> String {
  self.0.code()
}

///|
#cfg(target="js")
pub fn Keyboard::alt_key(self : Keyboard) -> Bool {
  self.0.alt_key()
}

///|
#cfg(target="js")
pub fn Keyboard::ctrl_key(self : Keyboard) -> Bool {
  self.0.ctrl_key()
}

///|
#cfg(target="js")
pub fn Keyboard::shift_key(self : Keyboard) -> Bool {
  self.0.shift_key()
}

///|
#cfg(target="js")
pub fn Keyboard::meta_key(self : Keyboard) -> Bool {
  self.0.meta_key()
}

///|
#cfg(target="js")
pub fn Keyboard::is_composing(self : Keyboard) -> Bool {
  self.0.is_composing()
}

///|
#cfg(target="js")
pub fn Keyboard::repeat(self : Keyboard) -> Bool {
  self.0.repeat()
}

///|
#cfg(target="js")
pub fn Keyboard::location(self : Keyboard) -> Int {
  self.0.location()
}

///|
#cfg(target="js")
struct Scroll(@dom.Element)

///|
#cfg(not(target="js"))
struct Scroll(Unit)

///|
#cfg(target="js")
pub fn Scroll::offset_pos(self : Self) -> Pos {
  { x: self.0.get_scroll_left().to_int(), y: self.0.get_scroll_top().to_int() }
}

///|
#cfg(target="js")
pub fn Scroll::width(self : Self) -> Int {
  self.0.get_scroll_width().to_int()
}

///|
#cfg(target="js")
pub fn Scroll::height(self : Self) -> Int {
  self.0.get_scroll_height().to_int()
}
