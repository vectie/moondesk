///|
using @html {
  aside,
  button,
  code,
  div,
  h1,
  h2,
  h3,
  header,
  input,
  li,
  main_,
  p,
  pre,
  section,
  span,
  textarea,
  ul,
}

///|
using @rabbita {type Dispatch}

///|
enum Activity {
  Explorer
  Search
  Inbox
  Town
  Runs
  Settings
} derive(Eq)

///|
enum TabKey {
  Wiki
  GeneratedSite
  RunReport
} derive(Eq)

///|
struct ActivityButton {
  key : Activity
  icon : String
  label : String
}

///|
struct ExplorerNode {
  path : String
  label : String
  kind : @desk.EntryKind
  layer : @desk.SourceLayer
  depth : Int
}

///|
struct PreviewTab {
  key : TabKey
  title : String
  path : String
  renderer : @desk.PreviewRenderer
}

///|
struct DrawerRecord {
  kind : String
  title : String
  detail : String
  tone : String
}

///|
struct Model {
  activity : Activity
  selected_path : String
  active_tab : TabKey
  command_open : Bool
  request_prompt : String
  submission_status : String
}

///|
enum Msg {
  SelectActivity(Activity)
  SelectPath(String)
  SelectTab(TabKey)
  ToggleCommand
  SetRequestPrompt(String)
  SubmitRequest
}

///|
fn init_model() -> Model {
  {
    activity: Activity::Explorer,
    selected_path: "wiki/index.md",
    active_tab: TabKey::Wiki,
    command_open: false,
    request_prompt: "Analyze the selected OPC evidence and update the book with source-backed deltas.",
    submission_status: "draft",
  }
}

///|
fn activities() -> Array[ActivityButton] {
  [
    { key: Activity::Explorer, icon: "F", label: "Explorer" },
    { key: Activity::Search, icon: "S", label: "Search" },
    { key: Activity::Inbox, icon: "I", label: "Inbox" },
    { key: Activity::Town, icon: "T", label: "Town" },
    { key: Activity::Runs, icon: "R", label: "Runs" },
    { key: Activity::Settings, icon: "G", label: "Settings" },
  ]
}

///|
fn explorer_nodes() -> Array[ExplorerNode] {
  [
    {
      path: "research-opc",
      label: "research-opc",
      kind: @desk.EntryKind::Directory,
      layer: @desk.SourceLayer::Workspace,
      depth: 0,
    },
    {
      path: "wiki/index.md",
      label: "wiki/index.md",
      kind: @desk.EntryKind::Markdown,
      layer: @desk.SourceLayer::Wiki,
      depth: 1,
    },
    {
      path: "raw/bootstrap/deep-report.md",
      label: "raw/bootstrap/deep-report.md",
      kind: @desk.EntryKind::Markdown,
      layer: @desk.SourceLayer::RawEvidence,
      depth: 1,
    },
    {
      path: "inbox/operator-note.md",
      label: "inbox/operator-note.md",
      kind: @desk.EntryKind::Markdown,
      layer: @desk.SourceLayer::Inbox,
      depth: 1,
    },
    {
      path: "book/site/generated/index.html",
      label: "book/site/generated/index.html",
      kind: @desk.EntryKind::Html,
      layer: @desk.SourceLayer::GeneratedSite,
      depth: 1,
    },
    {
      path: "moonclaw-jobs/run-20260420/report.md",
      label: "moonclaw-jobs/run-20260420/report.md",
      kind: @desk.EntryKind::Artifact,
      layer: @desk.SourceLayer::RunArtifact,
      depth: 1,
    },
  ]
}

///|
fn preview_tabs() -> Array[PreviewTab] {
  [
    {
      key: TabKey::Wiki,
      title: "wiki/index.md",
      path: "wiki/index.md",
      renderer: @desk.PreviewRenderer::Markdown,
    },
    {
      key: TabKey::GeneratedSite,
      title: "generated site",
      path: "book/site/generated/index.html",
      renderer: @desk.PreviewRenderer::Html,
    },
    {
      key: TabKey::RunReport,
      title: "run report",
      path: "moonclaw-jobs/run-20260420/report.md",
      renderer: @desk.PreviewRenderer::ArtifactSummary,
    },
  ]
}

///|
fn drawer_records() -> Array[DrawerRecord] {
  [
    {
      kind: "request",
      title: "operator-20260522-opc-update",
      detail: "Accepted by Moontown queue; awaiting watcher cadence.",
      tone: "accepted",
    },
    {
      kind: "town",
      title: "standing goal",
      detail: "Watch OPC news every 8 ticks with web-first source policy.",
      tone: "running",
    },
    {
      kind: "run",
      title: "moonclaw run",
      detail: "3 artifacts, report.md ready, no blocking failures.",
      tone: "ready",
    },
  ]
}

///|
fn update(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  ignore(dispatch)
  match msg {
    SelectActivity(activity) => (@rabbita.none, { ..model, activity, })
    SelectPath(path) => (@rabbita.none, { ..model, selected_path: path })
    SelectTab(tab) => (@rabbita.none, { ..model, active_tab: tab })
    ToggleCommand =>
      (@rabbita.none, { ..model, command_open: !model.command_open })
    SetRequestPrompt(prompt) =>
      (
        @rabbita.none,
        { ..model, request_prompt: prompt, submission_status: "draft" },
      )
    SubmitRequest =>
      (
        @rabbita.none,
        { ..model, submission_status: "ready for Moontown submission" },
      )
  }
}

///|
fn render_activity_rail(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="activity-rail", [
    div(class="rail-mark", "MD"),
    div(
      class="rail-buttons",
      activities().map(item => {
        let class_name = if item.key == model.activity {
          "rail-button active"
        } else {
          "rail-button"
        }
        button(
          class=class_name,
          title=item.label,
          on_click=dispatch(SelectActivity(item.key)),
          [
            span(class="rail-icon", item.icon),
            span(class="sr-only", item.label),
          ],
        )
      }),
    ),
  ])
}

///|
fn layer_label(layer : @desk.SourceLayer) -> String {
  match layer {
    @desk.SourceLayer::Wiki => "wiki"
    @desk.SourceLayer::RawEvidence => "raw"
    @desk.SourceLayer::GeneratedSite => "site"
    @desk.SourceLayer::BookOutput => "book"
    @desk.SourceLayer::Review => "review"
    @desk.SourceLayer::History => "history"
    @desk.SourceLayer::RunArtifact => "run"
    @desk.SourceLayer::Inbox => "inbox"
    @desk.SourceLayer::Config => "config"
    @desk.SourceLayer::Workspace => "root"
  }
}

///|
fn render_explorer(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "workspace"), h2("All Books")]),
      button(
        class="icon-button",
        title="Open Book",
        on_click=dispatch(ToggleCommand),
        "+",
      ),
    ]),
    div(class="workspace-card", [
      span(class="status-dot live", ""),
      div([
        h3("research-opc"),
        p("/Users/kq/Workspace/moontown/.moontown/books/research-opc"),
      ]),
    ]),
    div(class="explorer-section-tabs", [
      span(class="section-pill active", "Books"),
      span(class="section-pill", "Inbox"),
      span(class="section-pill", "Outputs"),
    ]),
    ul(
      class="tree-list",
      explorer_nodes().map(node => {
        let selected = node.path == model.selected_path
        let class_name = if selected { "tree-row selected" } else { "tree-row" }
        li(class=class_name, on_click=dispatch(SelectPath(node.path)), [
          span(class="tree-indent depth-\{node.depth}", ""),
          span(class="tree-icon", icon_for_kind(node.kind)),
          span(class="tree-label", node.label),
          span(class="tree-layer", layer_label(node.layer)),
        ])
      }),
    ),
  ])
}

///|
fn icon_for_kind(kind : @desk.EntryKind) -> String {
  match kind {
    @desk.EntryKind::Directory => "D"
    @desk.EntryKind::Markdown => "M"
    @desk.EntryKind::Html => "H"
    @desk.EntryKind::Json => "J"
    @desk.EntryKind::Image => "P"
    @desk.EntryKind::Artifact => "A"
    @desk.EntryKind::Text => "T"
    @desk.EntryKind::Unknown => "?"
  }
}

///|
fn renderer_label(renderer : @desk.PreviewRenderer) -> String {
  match renderer {
    @desk.PreviewRenderer::Markdown => "markdown"
    @desk.PreviewRenderer::Html => "html"
    @desk.PreviewRenderer::Json => "json"
    @desk.PreviewRenderer::Image => "image"
    @desk.PreviewRenderer::Text => "text"
    @desk.PreviewRenderer::ArtifactSummary => "artifact"
    @desk.PreviewRenderer::DirectoryListing => "directory"
    @desk.PreviewRenderer::Unsupported => "unsupported"
  }
}

///|
fn render_tabs(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(
    class="tab-strip",
    preview_tabs().map(tab => {
      let class_name = if tab.key == model.active_tab {
        "preview-tab active"
      } else {
        "preview-tab"
      }
      button(
        class=class_name,
        title=tab.path,
        on_click=dispatch(SelectTab(tab.key)),
        [
          span(class="tab-title", tab.title),
          span(class="tab-renderer", renderer_label(tab.renderer)),
        ],
      )
    }),
  )
}

///|
fn render_preview_body(model : Model) -> @rabbita.Html {
  match model.active_tab {
    TabKey::Wiki =>
      div(class="markdown-preview", [
        h1("One Person Company Research"),
        p(
          class="lead",
          "Current synthesis tracks source-backed changes across wiki pages, raw evidence, generated reports, and active MoonClaw runs.",
        ),
        h2("Open Loops"),
        ul([
          li("Screen fresh operator notes before wiki promotion."),
          li("Compare latest watcher messages against generated site output."),
          li("Attach MoonClaw artifacts to the next Moontown request."),
        ]),
        pre(
          class="source-block",
          code("wiki/index.md -> book/site/generated/index.html"),
        ),
      ])
    TabKey::GeneratedSite =>
      div(class="site-preview", [
        div(class="site-toolbar", [
          span("book/site/generated/index.html"),
          button(class="secondary-button", "Open"),
        ]),
        div(class="site-frame", [
          h2("Generated OPC Site"),
          p(
            "Static site preview is reserved for the MoonBook generated output. The host API will serve the real file path once M1 browsing is wired.",
          ),
        ]),
      ])
    TabKey::RunReport =>
      div(class="artifact-preview", [
        h2("MoonClaw Run Report"),
        p("Run workspace: moonclaw-jobs/run-20260420"),
        div(class="artifact-grid", [
          artifact_chip("events.jsonl", "log stream"),
          artifact_chip("result.json", "structured result"),
          artifact_chip("report.md", "reader ready"),
        ]),
        pre(
          class="source-block",
          code("phase=review-ready\nstatus=completed\nartifacts=3"),
        ),
      ])
  }
}

///|
fn artifact_chip(title : String, detail : String) -> @rabbita.Html {
  div(class="artifact-chip", [
    span(class="artifact-icon", "A"),
    div([
      span(class="artifact-title", title),
      span(class="artifact-detail", detail),
    ]),
  ])
}

///|
fn render_preview_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  main_(class="preview-center", [
    render_tabs(dispatch, model),
    div(class="preview-toolbar", [
      span(class="path-pill", model.selected_path),
      div(class="toolbar-actions", [
        button(class="secondary-button", "Split"),
        button(class="secondary-button", "Diff"),
        button(
          class="primary-button",
          on_click=dispatch(ToggleCommand),
          "Command",
        ),
      ]),
    ]),
    section(class="preview-surface", [render_preview_body(model)]),
  ])
}

///|
fn render_inspector(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="inspector-pane", [
    div(class="pane-heading compact", [
      div([p(class="eyebrow", "inspector"), h2("Context")]),
    ]),
    section(class="inspector-section", [
      h3("Selection"),
      info_row("Path", model.selected_path),
      info_row("Book", "research-opc"),
      info_row("Layer", "wiki/raw/generated/run"),
      info_row("Writable", "inbox only"),
    ]),
    section(class="inspector-section", [
      h3("Town Link"),
      info_row("Standing goal", "watch-opc-news"),
      info_row("Cadence", "8 ticks"),
      info_row("Quality", "85"),
    ]),
    section(class="composer", [
      h3("Request"),
      textarea(
        class="composer-input",
        rows=8,
        value=model.request_prompt,
        on_input=fn(value) { dispatch(SetRequestPrompt(value)) },
        "",
      ),
      div(class="composer-options", [
        span(class="option-chip active", "one-shot"),
        span(class="option-chip", "standing-watch"),
      ]),
      button(
        class="primary-button full",
        on_click=dispatch(SubmitRequest),
        "Submit to Town",
      ),
      p(class="status-line", model.submission_status),
    ]),
  ])
}

///|
fn info_row(label : String, value : String) -> @rabbita.Html {
  div(class="info-row", [span(label), code(value)])
}

///|
fn render_bottom_drawer() -> @rabbita.Html {
  section(class="bottom-drawer", [
    div(class="drawer-tabs", [
      span(class="drawer-tab active", "Requests"),
      span(class="drawer-tab", "Town Messages"),
      span(class="drawer-tab", "Run Events"),
      span(class="drawer-tab", "Build Output"),
    ]),
    div(
      class="drawer-records",
      drawer_records().map(record => {
        div(class="drawer-record \{record.tone}", [
          span(class="record-kind", record.kind),
          div([h3(record.title), p(record.detail)]),
        ])
      }),
    ),
  ])
}

///|
fn render_command_palette(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !model.command_open {
    @html.nothing
  } else {
    div(class="palette-backdrop", [
      div(class="command-palette", [
        div(class="palette-head", [
          input(
            class="palette-input",
            value="",
            placeholder="Open Book, Import Files, Build Book Site...",
            "",
          ),
          button(
            class="icon-button palette-close",
            title="Close command palette",
            attrs=@html.Attrs::build().aria_label("Close command palette"),
            on_click=dispatch(ToggleCommand),
            "X",
          ),
        ]),
        div(class="palette-list", [
          palette_command("Open Book", "Browse known MoonBook roots"),
          palette_command(
            "Create Book Inbox Note", "Stage a safe draft in inbox",
          ),
          palette_command("Submit to Town", "Send selected context to Moontown"),
          palette_command("Show Run Artifacts", "Open MoonClaw run projection"),
          palette_command("Toggle Inspector", "Hide or show context panel"),
        ]),
      ]),
    ])
  }
}

///|
fn palette_command(title : String, detail : String) -> @rabbita.Html {
  div(class="palette-command", [
    span(class="command-icon", ">"),
    div([h3(title), p(detail)]),
  ])
}

///|
fn render_title_bar(dispatch : Dispatch[Msg]) -> @rabbita.Html {
  header(class="title-bar", [
    div(class="title-copy", [
      span(class="app-dot", ""),
      h1("Moondesk"),
      span(class="workspace-switcher", "research-opc"),
    ]),
    button(
      class="command-button",
      on_click=dispatch(ToggleCommand),
      "Command Palette",
    ),
    div(class="sync-status", [
      span(class="status-dot live", ""),
      span("local host ready"),
    ]),
  ])
}

///|
fn render_app(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(class="desk-shell", [
    render_title_bar(dispatch),
    div(class="desk-main", [
      render_activity_rail(dispatch, model),
      render_explorer(dispatch, model),
      render_preview_center(dispatch, model),
      render_inspector(dispatch, model),
    ]),
    render_bottom_drawer(),
    render_command_palette(dispatch, model),
  ])
}

///|
fn main {
  let (_, cell) = @rabbita.cell_with_dispatch(model=init_model(), update~, view=(
    dispatch,
    model,
  ) => render_app(dispatch, model))
  @rabbita.new(cell).mount("app")
}
