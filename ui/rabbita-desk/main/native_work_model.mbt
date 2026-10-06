///|
/// The saved native-work projection is independent of Requests and runs.
struct NativeWorkStatus {
  id : String
  kind : String
  book_id : String
  criterion_id : String
  state : String
  control_state : String
  blocked_reason : String
  blocker_help : String
  session_id : String
  command_id : String
  engineering_status : String
  output : String
  generation : Int
  observed_at_ms : UInt64
  retry_after_ms : UInt64
} derive(FromJson, ToJson, Eq, Debug)

///|
struct NativeWorkEnvelope {
  schema : String
  revision : Int
  items : Array[NativeWorkStatus]
} derive(FromJson, ToJson)

///|
enum NativeWorkAction {
  RefreshObservation
  CancelRemaining
  SyncResults
} derive(Eq, Debug)

///|
enum NativeWorkOperation {
  ReadSaved
  ControlNative(String, NativeWorkAction)
} derive(Eq, Debug)

///|
struct NativeWorkPending {
  request : Int
  operation : NativeWorkOperation
} derive(Eq, Debug)

///|
struct NativeWorkState {
  active : Bool
  library : String
  book : String
  generation : Int
  request : Int
  revision : Int?
  items : Array[NativeWorkStatus]
  pending : NativeWorkPending?
  loaded : Bool
  error : String
  notice : String
} derive(Eq, Debug)

///|
enum NativeWorkMsg {
  BindNative(Bool, String, String)
  ReloadSavedNative
  ActOnNative(String, NativeWorkAction)
  NativeReceived(Int, Int, Result[Json, String])
  NativeTimedOut(Int, Int)
}

///|
enum NativeWorkEffect {
  NoNativeEffect
  ReadNativeSaved(Int, Int)
  PostNativeControl(Int, Int, String, NativeWorkAction, Int)
} derive(Eq, Debug)

///|
fn init_native_work() -> NativeWorkState {
  {
    active: false,
    library: "",
    book: "",
    generation: 0,
    request: 0,
    revision: None,
    items: [],
    pending: None,
    loaded: false,
    error: "",
    notice: "",
  }
}

///|
fn native_work_id_valid(id : String) -> Bool {
  id.length() == 42 &&
  id.has_prefix("town-work-") &&
  id[10:].to_owned().iter().all(c => c is ('0'..='9' | 'a'..='f'))
}

///|
fn native_work_decode(json : Json) -> NativeWorkEnvelope? {
  guard json is { "revision": revision, "items": Array(raw_items), .. } &&
    native_work_nonnegative_int(revision) is Some(_) else {
    return None
  }
  for item in raw_items {
    guard item is { "generation": generation, .. } &&
      native_work_nonnegative_int(generation) is Some(_) else {
      return None
    }
  }
  let envelope : NativeWorkEnvelope = @json.from_json(json) catch {
    _ => return None
  }
  if envelope.schema != "moontown.native-work.status.v1" ||
    envelope.revision < 0 {
    return None
  }
  let ids : Map[String, Unit] = Map([])
  for item in envelope.items {
    if !native_work_id_valid(item.id) ||
      item.generation < 0 ||
      ids.contains(item.id) {
      return None
    }
    ids[item.id] = ()
  }
  Some(envelope)
}

///|
/// FromJson[Int] permits truncation, so validate raw numbers before decoding.
fn native_work_nonnegative_int(value : Json) -> Int? {
  guard value is Number(number, ..) && number >= 0 && number <= 2147483647.0 else {
    return None
  }
  let integer = number.to_int()
  if integer.to_double() == number {
    Some(integer)
  } else {
    None
  }
}

///|
/// Only the Desk bridge's public error envelope is displayed, never an HTTP
/// exception or a raw native response. The bridge sanitizes owner errors.
fn native_work_public_error(result : Result[Json, String]) -> String {
  match result {
    Ok({ "ok": false, "error": String(message), .. }) if !message
      .trim()
      .is_empty() => message
    _ =>
      "Saved native work is unavailable or invalid. Reload saved status when Town is available; other Requests remain usable."
  }
}

///|
fn native_work_action_path(action : NativeWorkAction) -> String {
  match action {
    RefreshObservation => "refresh"
    CancelRemaining => "cancel"
    SyncResults => "sync"
  }
}

///|
fn native_work_action_label(action : NativeWorkAction) -> String {
  match action {
    RefreshObservation => "Refresh observation"
    CancelRemaining => "Cancel remaining work"
    SyncResults => "Retry / continue and sync"
  }
}

///|
/// The owner remains authoritative for terminal, unreserved and canceled work.
/// Sync stays available for terminal work that still needs result application.
fn native_work_action_disabled(state : NativeWorkState, id : String) -> Bool {
  !state.active ||
  state.pending is Some(_) ||
  state.revision is None ||
  !native_work_id_valid(id) ||
  !state.items.any(item => item.id == id)
}

///|
fn native_work_mutation_body(revision : Int) -> Json {
  { "expected_revision": revision }
}
