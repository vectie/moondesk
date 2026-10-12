///|
fn render_work_human_revision_comparison(
  before : String,
  after : String,
  title : String,
  before_label : String,
  after_label : String,
) -> @rabbita.Html {
  let comparison = work_human_revision_compare(before, after)
  details(class="work-human-comparison", [
    summary(title),
    p(
      if before == after {
        "No changes. Before and after text are identical."
      } else {
        "\{comparison.removed} removed · \{comparison.added} added" +
        (if comparison.coarse {
          " lines in the changed block"
        } else {
          " lines"
        })
      },
    ),
    p("Before: " + before_label + ". After: " + after_label + "."),
    p(
      "Read-only comparison. Line numbers refer to each version. LF, CRLF, CR and no line ending are shown explicitly; no text is normalized.",
    ),
    if comparison.coarse {
      p(
        "Large change block: shown as a replacement, not a minimal diff. Unchanged lines inside this block may be included in the counts.",
      )
    } else {
      @html.nothing
    },
    if comparison.removed + comparison.added > comparison.rows.length() {
      p(
        "Showing \{comparison.rows.length()} of \{comparison.removed + comparison.added} change rows. This is a partial view; retained text is not shortened.",
      )
    } else {
      @html.nothing
    },
    if !comparison.rows.is_empty() {
      pre(
        attrs=@html.Attrs::build()
          .tabindex(0)
          .aria_label("Line changes: removed from before, added to after"),
        comparison.rows
        .map(row => row.kind + " · line \{row.line} · " + row.text)
        .join("\n"),
      )
    } else {
      @html.nothing
    },
    details([
      summary("Before and after text"),
      p(
        "Preview limit: first 80 lines per version, up to 300 characters per line. Shortened content is labelled.",
      ),
      div(class="work-human-comparison-panes", [
        div([
          @html.h4("Before · " + before_label),
          pre(
            attrs=@html.Attrs::build()
              .tabindex(0)
              .aria_label("Before: " + before_label),
            work_human_revision_text_preview(before),
          ),
        ]),
        div([
          @html.h4("After · " + after_label),
          pre(
            attrs=@html.Attrs::build()
              .tabindex(0)
              .aria_label("After: " + after_label),
            work_human_revision_text_preview(after),
          ),
        ]),
      ]),
      a(
        href=work_human_revision_download_url(before),
        download="human-revision-before.txt",
        "Download full before text",
      ),
      a(
        href=work_human_revision_download_url(after),
        download="human-revision-after.txt",
        "Download full after text",
      ),
    ]),
  ])
}
