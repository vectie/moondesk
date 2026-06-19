///|
pub let sep : Char = '/'

///|
pub fn dirname(path : StringView) -> StringView {
  let dir = @xpath.Path::dirname(path.to_owned()).to_string()
  if dir.is_empty() {
    "."
  } else {
    dir
  }
}

///|
pub fn ext(path : StringView) -> StringView {
  @xpath.Path::extname(path.to_owned())
}

///|
pub fn normalize(view : StringView) -> String {
  @xpath.Path::normalize(view.to_owned()).0
}

///|
pub fn join(p : StringView, q : StringView) -> String {
  @xpath.Path::join(p.to_owned(), q.to_owned()).normalize().0
}

///|
pub fn is_absolute(path : StringView) -> Bool {
  @xpath.Path::is_absolute(path.to_owned())
}
