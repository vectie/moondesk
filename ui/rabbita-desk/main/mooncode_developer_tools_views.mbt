///|
fn mooncode_developer_browser_url(model : Model) -> String {
  match model.preview {
    Some({ renderer: Html, .. }) if model.selected_workspace_id != "" &&
      model.selected_path != "" => html_preview_url(model, model.selected_path)
    _ => "about:blank"
  }
}

///|
fn mooncode_developer_tool_tab(
  tool : String,
  label : String,
  active : Bool,
) -> @rabbita.Html {
  button(
    class=if active {
      "mooncode-developer-tool-tab active"
    } else {
      "mooncode-developer-tool-tab"
    },
    attrs=@html.Attrs::build()
      .role("tab")
      .aria_selected(if active { "true" } else { "false" })
      .data_set("developer-tool-tab", tool),
    label,
  )
}

///|
fn mooncode_developer_browser_diagnostic(
  label : String,
  testid : String,
  content : String,
) -> @rabbita.Html {
  section([
    strong(label),
    pre(attrs=@html.Attrs::build().data_set("testid", testid), content),
  ])
}

///|
fn render_mooncode_developer_tools_body(initial_url : String) -> @rabbita.Html {
  div(class="mooncode-developer-tools-body", [
    div(
      class="mooncode-developer-tool-tabs",
      attrs=@html.Attrs::build()
        .role("tablist")
        .aria_label("MoonCode developer tools"),
      [
        mooncode_developer_tool_tab("terminal", "Terminal", false),
        mooncode_developer_tool_tab(
          "browser",
          "Browser",
          initial_url != "about:blank",
        ),
        mooncode_developer_tool_tab("compare", "Compare", false),
      ],
    ),
    section(
      class=if initial_url == "about:blank" {
        "mooncode-developer-tool-panel terminal active"
      } else {
        "mooncode-developer-tool-panel terminal"
      },
      attrs=@html.Attrs::build()
        .data_set("developer-tool-panel", "terminal")
        .data_set("testid", "mooncode-developer-terminal"),
      [
        div(class="mooncode-developer-tool-heading", [
          div([
            h3("Command evidence"),
            p("Recorded commands and output from the selected MoonCode chat."),
          ]),
          span(class="mooncode-developer-tool-badge", "MoonCode routed"),
        ]),
        div(
          class="mooncode-developer-terminal-output",
          attrs=@html.Attrs::build()
            .data_set("testid", "mooncode-developer-terminal-output")
            .aria_live("polite"),
          ([] : Array[@rabbita.Html]),
        ),
        @html.form(
          class="mooncode-developer-terminal-request",
          attrs=@html.Attrs::build().data_set("developer-terminal-form", "true"),
          [
            span(class="mooncode-developer-terminal-prompt", "$"),
            input(
              class="mooncode-developer-terminal-input",
              attrs=@html.Attrs::build()
                .data_set("testid", "mooncode-developer-terminal-input")
                .aria_label("Request a command through MoonCode")
                .spellcheck(false),
              placeholder="Request a command through MoonCode",
            ),
            button(
              class="mooncode-developer-terminal-submit",
              attrs=@html.Attrs::build().data_set(
                "testid", "mooncode-developer-terminal-submit",
              ),
              "Ask MoonCode",
            ),
          ],
        ),
        p(
          class="mooncode-developer-tool-footnote",
          attrs=@html.Attrs::build()
            .data_set("testid", "mooncode-developer-terminal-status")
            .role("status")
            .aria_live("polite"),
          "Commands are reviewed and executed by MoonCode; this is not a direct shell.",
        ),
      ],
    ),
    section(
      class=if initial_url == "about:blank" {
        "mooncode-developer-tool-panel browser"
      } else {
        "mooncode-developer-tool-panel browser active"
      },
      attrs=@html.Attrs::build()
        .data_set("developer-tool-panel", "browser")
        .data_set("testid", "mooncode-developer-browser"),
      [
        div(class="mooncode-developer-browser-toolbar", [
          div(class="mooncode-developer-browser-navigation", [
            button(
              class="mooncode-developer-browser-button",
              attrs=@html.Attrs::build()
                .data_set("developer-browser-action", "back")
                .aria_label("Back")
                .disabled(true),
              "←",
            ),
            button(
              class="mooncode-developer-browser-button",
              attrs=@html.Attrs::build()
                .data_set("developer-browser-action", "forward")
                .aria_label("Forward")
                .disabled(true),
              "→",
            ),
            button(
              class="mooncode-developer-browser-button",
              attrs=@html.Attrs::build()
                .data_set("developer-browser-action", "reload")
                .aria_label("Reload preview"),
              "↻",
            ),
          ]),
          @html.form(
            class="mooncode-developer-browser-address-form",
            attrs=@html.Attrs::build().data_set(
              "developer-browser-address-form", "true",
            ),
            [
              span(class="mooncode-developer-browser-isolation", "Isolated"),
              input(
                class="mooncode-developer-browser-address",
                attrs=@html.Attrs::build()
                  .data_set("testid", "mooncode-developer-browser-address")
                  .aria_label("Preview address")
                  .spellcheck(false),
                placeholder="http://127.0.0.1:3000",
              ),
              button(class="mooncode-developer-browser-go", "Go"),
            ],
          ),
          button(
            class="mooncode-developer-browser-external",
            attrs=@html.Attrs::build()
              .data_set("developer-browser-action", "open-external")
              .aria_label("Open current address externally"),
            "Open external",
          ),
        ]),
        div(class="mooncode-developer-browser-stage", [
          iframe(
            class="mooncode-developer-browser-frame",
            src=initial_url,
            title="MoonCode isolated browser preview",
            sandbox="allow-scripts allow-forms",
            attrs=@html.Attrs::build().data_set(
              "testid", "mooncode-developer-browser-frame",
            ),
          ),
        ]),
        div(class="mooncode-developer-browser-statusbar", [
          span(
            attrs=@html.Attrs::build()
              .data_set("testid", "mooncode-developer-browser-status")
              .role("status")
              .aria_live("polite"),
            if initial_url == "about:blank" {
              "Enter a local preview address"
            } else {
              "Loading isolated preview"
            },
          ),
          span(
            "Scripts and forms allowed · origin and top navigation isolated",
          ),
          button(
            class="mooncode-developer-browser-button",
            attrs=@html.Attrs::build()
              .data_set("testid", "mooncode-developer-browser-prepare-evidence")
              .data_set("developer-browser-evidence", "prepare")
              .disabled(true),
            "Prepare evidence",
          ),
        ]),
        div(
          class="mooncode-developer-browser-evidence",
          attrs=@html.Attrs::build().data_set("evidence-state", "not-persisted"),
          [
            span(
              attrs=@html.Attrs::build()
                .data_set(
                  "testid", "mooncode-developer-browser-evidence-status",
                )
                .role("status")
                .aria_live("polite"),
              "Evidence not prepared",
            ),
            details(
              attrs=@html.Attrs::build().data_set(
                "testid", "mooncode-developer-browser-diagnostics",
              ),
              [
                summary("Diagnostics"),
                div(class="mooncode-developer-browser-diagnostics-grid", [
                  mooncode_developer_browser_diagnostic(
                    "Console", "mooncode-developer-browser-console", "No console output observed",
                  ),
                  mooncode_developer_browser_diagnostic(
                    "Runtime", "mooncode-developer-browser-runtime", "No runtime errors observed",
                  ),
                  mooncode_developer_browser_diagnostic(
                    "Network", "mooncode-developer-browser-network", "No resources recorded",
                  ),
                  mooncode_developer_browser_diagnostic(
                    "Accessibility", "mooncode-developer-browser-accessibility",
                    "Prepare evidence to inspect semantics",
                  ),
                ]),
              ],
            ),
          ],
        ),
      ],
    ),
    section(
      class="mooncode-developer-tool-panel compare",
      attrs=@html.Attrs::build()
        .data_set("developer-tool-panel", "compare")
        .data_set("testid", "mooncode-developer-compare"),
      [
        div(class="mooncode-developer-tool-heading", [
          div([
            h3("Fork & compare"),
            p(
              "Trial two approaches from one workspace baseline, then promote only the winner.",
            ),
          ]),
          span(class="mooncode-developer-tool-badge", "MoonFort isolated"),
        ]),
        @html.form(
          class="mooncode-compare-form",
          attrs=@html.Attrs::build().data_set("developer-compare-form", "true"),
          [
            div(class="mooncode-compare-field", [
              span("Goal"),
              textarea(
                attrs=@html.Attrs::build()
                  .data_set("developer-compare-goal", "true")
                  .aria_label("Comparison goal"),
                placeholder="What should both approaches accomplish?",
                "",
              ),
            ]),
            div(class="mooncode-compare-branches", [
              div(class="mooncode-compare-field", [
                span("Approach A"),
                textarea(
                  attrs=@html.Attrs::build()
                    .data_set("developer-compare-a", "true")
                    .aria_label("Comparison approach A"),
                  placeholder="Direct implementation, library choice, or route A",
                  "",
                ),
              ]),
              div(class="mooncode-compare-field", [
                span("Approach B"),
                textarea(
                  attrs=@html.Attrs::build()
                    .data_set("developer-compare-b", "true")
                    .aria_label("Comparison approach B"),
                  placeholder="Alternative implementation, library choice, or route B",
                  "",
                ),
              ]),
            ]),
            button(
              class="mooncode-developer-terminal-submit",
              attrs=@html.Attrs::build()
                .data_set("testid", "mooncode-developer-compare-submit")
                .disabled(true),
              "Run isolated comparison",
            ),
            p(
              class="mooncode-developer-tool-footnote",
              attrs=@html.Attrs::build()
                .data_set("testid", "mooncode-developer-compare-status")
                .role("status")
                .aria_live("polite"),
              "Results, diffs, checks, latency, tokens, and cost stay in the MoonCode transcript.",
            ),
          ],
        ),
        div(
          class="mooncode-compare-results-host",
          attrs=@html.Attrs::build().data_set(
            "developer-compare-results-host", "true",
          ),
          ([] : Array[@rabbita.Html]),
        ),
      ],
    ),
  ])
}

///|
/// MoonCode-only advanced tools. The eager MoonBit tree owns just the
/// progressive-disclosure boundary; the lazy developer-tools runtime builds
/// the terminal and isolated browser after this route renders.
fn render_mooncode_developer_tools(model : Model) -> @rabbita.Html {
  let initial_url = mooncode_developer_browser_url(model)
  details(
    class="mooncode-developer-tools",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-developer-tools")
      .data_set("runtime", "mooncode-developer-tools-v1")
      .data_set("initial-url", initial_url)
      .data_set("source-path", model.selected_path)
      .data_set(
        "preferred-tool",
        if initial_url == "about:blank" {
          "terminal"
        } else {
          "browser"
        },
      )
      .data_set("workspace-id", model.selected_workspace_id)
      .data_set("context-path", mooncode_context_path(model))
      .open(initial_url != "about:blank"),
    [
      summary(class="mooncode-developer-tools-summary", [
        span("Developer tools"),
        span(
          class="mooncode-developer-tools-summary-note",
          "Terminal · Browser · Compare",
        ),
      ]),
      render_mooncode_developer_tools_body(initial_url),
    ],
  )
}
