///|
async fn write_bytes_file(path : String, bytes : Bytes, create~ : Int) -> Unit {
  @fs.write_file(path, bytes, create_mode=CreateOrTruncate, permission=create)
}
