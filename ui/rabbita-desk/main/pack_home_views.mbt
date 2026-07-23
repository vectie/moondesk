///|
fn pack_status_label(status : String) -> String {
  match status {
    "configured" => "Ready"
    "workflow_only" => "Workflow only"
    "configuration_required" => "Setup required"
    "configuration_invalid" => "Configuration issue"
    _ => "Unavailable"
  }
}

///|
fn pack_status_class(status : String) -> String {
  match status {
    "configured" => "ready"
    "workflow_only" => "workflow"
    "configuration_required" => "setup"
    "configuration_invalid" => "blocked"
    _ => "blocked"
  }
}

///|
fn pack_default_description(pack : PackAppRecord) -> String {
  if pack.description.trim() != "" {
    pack.description
  } else {
    "An installed \{pack.kind} with \{pack.workflow_count} workflow(s), \{pack.tool_count} tool(s), and \{pack.entrypoint_count} app surface(s)."
  }
}

///|
fn pack_area_value(value : String?) -> String {
  match value {
    Some(value) => value.trim().to_owned()
    None => ""
  }
}

///|
fn pack_has_declared_area(pack : PackAppRecord) -> Bool {
  pack_area_value(pack.area_id) != "" &&
  pack_area_value(pack.area_category) != "" &&
  pack_area_value(pack.area_label) != ""
}

///|
fn render_pack_area(pack : PackAppRecord) -> @rabbita.Html {
  if pack_has_declared_area(pack) {
    span(
      class="pack-area-label",
      attrs=@html.Attrs::build()
        .data_set("testid", "pack-area")
        .data_set("area-id", pack_area_value(pack.area_id))
        .data_set("area-category", pack_area_value(pack.area_category)),
      pack_area_value(pack.area_label),
    )
  } else {
    @html.nothing
  }
}

///|
fn render_pack_primary_action(pack : PackAppRecord) -> @rabbita.Html {
  if pack.status == "configured" && pack.launch_url != "" {
    a(
      class="primary-button link-button pack-open-action",
      href=pack.launch_url,
      attrs=@html.Attrs::build()
        .data_set("testid", "pack-open")
        .data_set("pack-id", pack.pack_id)
        .aria_label("Open " + pack.display_name),
      "Open pack",
    )
  } else {
    button(
      class="primary-button pack-open-action",
      attrs=@html.Attrs::build()
        .data_set("testid", "pack-open-disabled")
        .data_set("pack-id", pack.pack_id),
      disabled=true,
      if pack.status == "workflow_only" {
        "No standalone app"
      } else {
        "Open unavailable"
      },
    )
  }
}

///|
fn render_pack_card(
  dispatch : Dispatch[Msg],
  model : Model,
  pack : PackAppRecord,
) -> @rabbita.Html {
  article(
    class="pack-product-card " + pack_status_class(pack.status),
    attrs=@html.Attrs::build()
      .data_set("testid", "pack-product-card")
      .data_set("pack-id", pack.pack_id)
      .data_set("pack-status", pack.status)
      .data_set("area-id", pack_area_value(pack.area_id))
      .data_set("area-category", pack_area_value(pack.area_category)),
    [
      header(class="pack-card-header", [
        div(class="pack-card-identity", [
          span(class="pack-mark", pack.pack_id),
          div([
            h2(pack.display_name),
            render_pack_area(pack),
            small("v" + pack.version + " · " + pack.kind),
          ]),
        ]),
        span(
          class="pack-state-label " + pack_status_class(pack.status),
          pack_status_label(pack.status),
        ),
      ]),
      p(class="pack-description", pack_default_description(pack)),
      ul(class="pack-capability-counts", [
        li([strong(pack.workflow_count.to_string()), span("workflows")]),
        li([strong(pack.tool_count.to_string()), span("tools")]),
        li([strong(pack.entrypoint_count.to_string()), span("app surfaces")]),
      ]),
      p(
        class="pack-configuration-message",
        attrs=@html.Attrs::build().role("status"),
        pack.configuration_message,
      ),
      div(class="pack-card-actions", [
        render_pack_primary_action(pack),
        details(class="pack-advanced-actions", [
          summary("Advanced controls"),
          div(class="pack-advanced-body", [
            button(
              class="secondary-button",
              disabled=model.selected_workspace_id == "",
              on_click=dispatch(SelectWorkspaceMode(MoonFlow)),
              "Inspect current composition",
            ),
            small(
              if model.selected_workspace_id == "" {
                "Select a MoonBook before inspecting an executable composition."
              } else {
                "Composition belongs to the selected MoonBook; this pack keeps its domain contracts."
              },
            ),
          ]),
        ]),
      ]),
    ],
  )
}

///|
fn render_pack_home(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  main_(
    class="pack-home-main",
    attrs=@html.Attrs::build().data_set("testid", "pack-home"),
    [
      section(class="pack-home-hero", [
        div([
          p(class="eyebrow", "MoonSuite applications"),
          h1("What do you want to run?"),
          p(
            class="lead",
            "Packs are applications: open one for domain work, or inspect its composition in Flow.",
          ),
        ]),
        div(class="pack-home-summary", [
          strong("\{model.pack_apps.length()} installed"),
          span(model.pack_apps_status),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "pack-home-refresh"),
            on_click=dispatch(RefreshAll),
            "Refresh",
          ),
        ]),
      ]),
      if model.pack_apps.is_empty() {
        section(class="pack-home-empty", [
          strong("No domain packs are installed"),
          p(
            "Install a pack into this MoonSuite workspace. MoonDesk will discover its manifest without importing domain code.",
          ),
          button(
            class="secondary-button",
            on_click=dispatch(SelectWorkspaceMode(Desk)),
            "Browse MoonBooks",
          ),
        ])
      } else {
        section(
          class="pack-product-grid",
          attrs=@html.Attrs::build().aria_label("Installed MoonSuite packs"),
          model.pack_apps.map(pack => render_pack_card(dispatch, model, pack)),
        )
      },
      details(class="pack-runtime-details", [
        summary("How packs run"),
        div(class="pack-runtime-strip", [
          div([strong("Pack"), small("domain UI + contracts")]),
          span("→"),
          div([strong("MoonDesk"), small("operator control")]),
          span("→"),
          div([strong("MoonFlow"), small("durable execution")]),
          span("→"),
          div([strong("MoonClaw"), small("single agent runtime")]),
        ]),
        p(
          "Each pack owns its domain screens, schemas, policies, providers, and workflows. MoonDesk supplies generic launch, authority, evidence, review, and composition controls.",
        ),
      ]),
    ],
  )
}
