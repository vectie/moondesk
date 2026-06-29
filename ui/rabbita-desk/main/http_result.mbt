///|
fn[T] http_result(
  result : Result[T, Error],
  message : String,
) -> Result[T, String] {
  match result {
    Ok(value) => Ok(value)
    Err(_) => Err(message)
  }
}
