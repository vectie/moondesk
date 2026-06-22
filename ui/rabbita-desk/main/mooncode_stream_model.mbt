///|
struct MoonCodeStreamPoll {
  stream : String
  stream_source : String
  next_since : Int
  emitted_count : Int
  events : Array[MoonCodeEvent]
}

///|
struct MoonCodeStreamState {
  consumer_id : String
  latest_sequence : Int
  next_since : Int
} derive(FromJson)

