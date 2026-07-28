///|
async fn write_bytes_file(path : String, bytes : Bytes, create~ : Int) -> Unit {
  let file = @fs.create(path, permission=create)
  defer file.close()
  file.write(bytes)
}
