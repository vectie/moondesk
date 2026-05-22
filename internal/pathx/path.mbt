///|
using @xpath {type Path}

///|
pub let sep : Char = '/'

///|
pub fn dirname(path : StringView) -> StringView {
  let dir = @xpath.Path::dirname(path.to_string()).to_string()
  if dir.is_empty() {
    "."
  } else {
    dir
  }
}

///|
pub fn ext(path : StringView) -> StringView {
  Path::extname(path.to_string())
}

///|
pub fn normalize(view : StringView) -> String {
  Path::normalize(view.to_string()).0
}

///|
pub fn join(p : StringView, q : StringView) -> String {
  Path::join(p.to_string(), q.to_string()).normalize().0
}

///|
pub fn is_absolute(path : StringView) -> Bool {
  Path::is_absolute(path.to_string())
}
