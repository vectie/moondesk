///|
/// A read-only projection. Comparison never changes retained source text.
struct WorkHumanLineChange {
  kind : String
  line : Int
  text : String
} derive(Debug, Eq)

///|
struct WorkHumanComparison {
  rows : Array[WorkHumanLineChange]
  removed : Int
  added : Int
  coarse : Bool
} derive(Debug, Eq)

///|
/// Keep line endings in each token: CRLF, CR, LF and missing final endings
/// are changes, rather than silently normalized text. Empty text has no lines.
fn work_human_revision_lines(value : String) -> Array[String] {
  let lines = []
  let mut start = 0
  let mut index = 0
  while index < value.length() {
    if value[index] == '\r' || value[index] == '\n' {
      let end = if value[index] == '\r' &&
        index + 1 < value.length() &&
        value[index + 1] == '\n' {
        index + 2
      } else {
        index + 1
      }
      lines.push(value[start:end].to_owned())
      start = end
      index = end
    } else {
      index += 1
    }
  }
  if start < value.length() {
    lines.push(value[start:].to_owned())
  }
  lines
}

///|
/// Limits presentation only, on Unicode-safe string boundaries.
fn work_human_revision_line_preview(line : String) -> String {
  let (text, ending) = if line.has_suffix("\r\n") {
    (line[:line.length() - 2], "CRLF")
  } else if line.has_suffix("\n") {
    (line[:line.length() - 1], "LF")
  } else if line.has_suffix("\r") {
    (line[:line.length() - 1], "CR")
  } else {
    (line[:], "no line ending")
  }
  let shown = if text.length() > 300 {
    text[:300].to_owned() + "… [line shortened]"
  } else if text.is_empty() {
    "[empty line]"
  } else {
    text.to_owned()
  }
  shown + " [" + ending + "]"
}

///|
fn work_human_revision_text_preview(value : String) -> String {
  let lines = work_human_revision_lines(value)
  if lines.is_empty() {
    return "[empty file]"
  }
  let shown = lines[:lines.length().min(80)]
    .mapi((index, line) => {
      "\{index + 1} · " + work_human_revision_line_preview(line)
    })
    .join("\n")
  if lines.length() > 80 {
    shown + "\n[… \{lines.length() - 80} more lines not shown]"
  } else {
    shown
  }
}

///|
/// Strip common ends, then compute an exact LCS for at most 200 lines per
/// side. Larger middle blocks use a clearly labelled replacement projection.
/// Work is linear in input size plus at most 40,401 matrix cells. Render at
/// most 80 removed and 80 added rows, each with bounded text.
fn work_human_revision_compare(
  before : String,
  after : String,
) -> WorkHumanComparison {
  let old = work_human_revision_lines(before)
  let new = work_human_revision_lines(after)
  let mut start = 0
  while start < old.length() && start < new.length() && old[start] == new[start] {
    start += 1
  }
  let mut old_end = old.length()
  let mut new_end = new.length()
  while old_end > start &&
        new_end > start &&
        old[old_end - 1] == new[new_end - 1] {
    old_end -= 1
    new_end -= 1
  }
  let old_count = old_end - start
  let new_count = new_end - start
  let rows = []
  if old_count > 200 || new_count > 200 {
    for index in start..<old_end.min(start + 80) {
      rows.push({
        kind: "Removed",
        line: index + 1,
        text: work_human_revision_line_preview(old[index]),
      })
    }
    for index in start..<new_end.min(start + 80) {
      rows.push({
        kind: "Added",
        line: index + 1,
        text: work_human_revision_line_preview(new[index]),
      })
    }
    return { rows, removed: old_count, added: new_count, coarse: true, }
  }
  let width = new_count + 1
  let lengths = Array::make((old_count + 1) * width, 0)
  let mut i = old_count - 1
  while i >= 0 {
    let mut j = new_count - 1
    while j >= 0 {
      lengths[i * width + j] = if old[start + i] == new[start + j] {
        1 + lengths[(i + 1) * width + j + 1]
      } else {
        lengths[(i + 1) * width + j].max(lengths[i * width + j + 1])
      }
      j -= 1
    }
    i -= 1
  }
  let mut old_index = 0
  let mut new_index = 0
  let mut removed = 0
  let mut added = 0
  while old_index < old_count || new_index < new_count {
    if old_index < old_count &&
      new_index < new_count &&
      old[start + old_index] == new[start + new_index] {
      old_index += 1
      new_index += 1
    } else if old_index < old_count &&
      (
        new_index == new_count ||
        lengths[(old_index + 1) * width + new_index] >=
        lengths[old_index * width + new_index + 1]
      ) {
      if removed < 80 {
        rows.push({
          kind: "Removed",
          line: start + old_index + 1,
          text: work_human_revision_line_preview(old[start + old_index]),
        })
      }
      removed += 1
      old_index += 1
    } else {
      if added < 80 {
        rows.push({
          kind: "Added",
          line: start + new_index + 1,
          text: work_human_revision_line_preview(new[start + new_index]),
        })
      }
      added += 1
      new_index += 1
    }
  }
  { rows, removed, added, coarse: false, }
}
