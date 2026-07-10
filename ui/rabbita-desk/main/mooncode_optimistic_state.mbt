///|
fn mooncode_append_optimistic_user_prompt(
  rows : Array[MoonCodeOptimisticRow],
  session_id : String,
  content : String,
  client_turn_id? : String = "",
) -> Array[MoonCodeOptimisticRow] {
  let next = mooncode_copy_optimistic_rows(rows)
  let row_key = if client_turn_id == "" {
    "ui-user:\{session_id}:\{next.length()}"
  } else {
    client_turn_id
  }
  mooncode_push_optimistic_row(
    next, session_id, "user", content, "queued", row_key,
  )
  next
}

///|
fn mooncode_optimistic_rows_have_session(
  rows : Array[MoonCodeOptimisticRow],
  session_id : String,
) -> Bool {
  if session_id == "" {
    return false
  }
  for row in rows {
    if row.session_id == session_id &&
      row.role == "user" &&
      (row.status == "queued" || row.status == "running") {
      return true
    }
  }
  false
}

///|
fn mooncode_optimistic_rows_for_session(
  rows : Array[MoonCodeOptimisticRow],
  session_id : String,
) -> Array[MoonCodeOptimisticRow] {
  let next : Array[MoonCodeOptimisticRow] = []
  if session_id == "" {
    return next
  }
  for row in rows {
    if row.session_id == session_id {
      next.push(row)
    }
  }
  next
}

///|
fn mooncode_reassign_optimistic_session(
  rows : Array[MoonCodeOptimisticRow],
  from_session_id : String,
  to_session_id : String,
) -> Array[MoonCodeOptimisticRow] {
  let next : Array[MoonCodeOptimisticRow] = []
  for row in rows {
    if row.session_id == from_session_id {
      next.push({
        ..row,
        session_id: to_session_id,
        key: mooncode_rewrite_local_row_key(
          row.key,
          from_session_id,
          to_session_id,
        ),
      })
    } else {
      next.push(row)
    }
  }
  next
}

///|
fn mooncode_rewrite_local_row_key(
  key : String,
  from_session_id : String,
  to_session_id : String,
) -> String {
  let from_prefix = "ui-user:\{from_session_id}:"
  if key.has_prefix(from_prefix) {
    "ui-user:\{to_session_id}:" + key[from_prefix.length():].to_owned()
  } else {
    key
  }
}

///|
fn mooncode_copy_optimistic_rows(
  rows : Array[MoonCodeOptimisticRow],
) -> Array[MoonCodeOptimisticRow] {
  let next : Array[MoonCodeOptimisticRow] = []
  for row in rows {
    next.push(row)
  }
  next
}

///|
fn mooncode_push_optimistic_row(
  rows : Array[MoonCodeOptimisticRow],
  session_id : String,
  role : String,
  content : String,
  status : String,
  key : String,
) -> Unit {
  let normalized = content.trim().to_owned()
  if session_id == "" || normalized == "" {
    return
  }
  for row in rows {
    if row.session_id == session_id && row.role == role && row.key == key {
      return
    }
  }
  rows.push({ session_id, role, content: normalized, status, key })
}

///|
fn mooncode_fail_pending_optimistic_rows_for_session(
  rows : Array[MoonCodeOptimisticRow],
  session_id : String,
  message : String,
) -> Array[MoonCodeOptimisticRow] {
  let next : Array[MoonCodeOptimisticRow] = []
  let failed_keys : Array[String] = []
  for row in rows {
    if row.session_id == session_id &&
      row.role == "user" &&
      (row.status == "queued" || row.status == "running") {
      next.push({ ..row, status: "failed" })
      if row.key != "" {
        failed_keys.push(row.key)
      }
    } else {
      next.push(row)
    }
  }
  for key in failed_keys {
    mooncode_push_optimistic_row(
      next, session_id, "assistant", message, "failed", key,
    )
  }
  next
}

///|
fn mooncode_drop_acknowledged_optimistic_rows(
  rows : Array[MoonCodeOptimisticRow],
  session : MoonCodeSession,
) -> Array[MoonCodeOptimisticRow] {
  let next : Array[MoonCodeOptimisticRow] = []
  for row in rows {
    if row.session_id == session.id &&
      mooncode_session_acknowledges_optimistic_row(session, row) {
      continue
    }
    next.push(row)
  }
  next
}

///|
fn mooncode_drop_acknowledged_optimistic_rows_for_sessions(
  rows : Array[MoonCodeOptimisticRow],
  sessions : Array[MoonCodeSession],
) -> Array[MoonCodeOptimisticRow] {
  let mut next = rows
  for session in sessions {
    next = mooncode_drop_acknowledged_optimistic_rows(next, session)
  }
  next
}

///|
fn mooncode_session_acknowledges_optimistic_row(
  session : MoonCodeSession,
  row : MoonCodeOptimisticRow,
) -> Bool {
  if row.role != "user" || row.key == "" {
    return false
  }
  match session.mooncode_conversation {
    Some(conversation) => {
      for turn in conversation.turns {
        if turn.client_turn_id == row.key {
          return true
        }
      }
      false
    }
    None => false
  }
}
