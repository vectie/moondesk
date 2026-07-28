///|
pub struct ReviewDiffSummary {
  added : Int
  removed : Int
  changed : Bool
  body : String
}

///|
pub fn ReviewDiffSummary::added(self : ReviewDiffSummary) -> Int {
  self.added
}

///|
pub fn ReviewDiffSummary::removed(self : ReviewDiffSummary) -> Int {
  self.removed
}

///|
pub fn ReviewDiffSummary::changed(self : ReviewDiffSummary) -> Bool {
  self.changed
}

///|
pub fn ReviewDiffSummary::body(self : ReviewDiffSummary) -> String {
  self.body
}

///|
pub fn line_diff_summary(
  base_text : String,
  current_text : String,
) -> ReviewDiffSummary {
  let base_lines = review_diff_lines(base_text)
  let current_lines = review_diff_lines(current_text)
  let mut added = 0
  let mut removed = 0
  let body_lines : Array[String] = []
  for line in current_lines {
    if !has_line(base_lines, line) {
      added += 1
      if body_lines.length() < 80 {
        body_lines.push(diff_body_line("+ ", line))
      }
    }
  }
  for line in base_lines {
    if !has_line(current_lines, line) {
      removed += 1
      if body_lines.length() < 80 {
        body_lines.push(diff_body_line("- ", line))
      }
    }
  }
  {
    added,
    removed,
    changed: added > 0 || removed > 0,
    body: if body_lines.length() == 0 {
      "No line-level difference against the nearest review base."
    } else {
      body_lines.join("\n")
    },
  }
}

///|
fn review_diff_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    let line = line.to_owned()
    if line.trim().to_owned() != "" {
      lines.push(line)
    }
  }
  lines
}

///|
fn diff_body_line(prefix : String, line : String) -> String {
  let compact = line.trim().to_owned()
  if compact.length() > 240 {
    prefix + compact[:240].to_owned() + "..."
  } else {
    prefix + compact
  }
}

///|
fn has_line(lines : Array[String], line : String) -> Bool {
  for item in lines {
    if item == line {
      return true
    }
  }
  false
}
