///|
fn render_mooncode_skill_catalog(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !model.mooncode_skills_visible ||
    model.selected_workspace_id == "" ||
    model.mooncode_skills_workspace_id != model.selected_workspace_id {
    return @html.nothing
  }
  section(
    class="mooncode-skill-catalog",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-skill-catalog")
      .aria_label("Available MoonCode skills")
      .data_set("i18n-aria-label", "code.skills_aria"),
    [
      div(class="mooncode-skill-catalog-heading", [
        div([
          strong(
            attrs=@html.Attrs::build().data_set("i18n", "code.skills_title"),
            "Available skills",
          ),
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.skills_desc"),
            "MoonClaw discovers these for this MoonBook. A skill applies when MoonCode loads it for a turn.",
          ),
        ]),
        button(
          class="mooncode-git-open",
          attrs=@html.Attrs::build().data_set("i18n", "common.refresh"),
          on_click=dispatch(RefreshMoonCodeSkills),
          disabled=model.mooncode_skills_loading,
          "Refresh",
        ),
      ]),
      div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        if model.mooncode_skills_loading {
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.skills_loading"),
            "Loading MoonClaw skills…",
          )
        } else if model.mooncode_skills_error != "" {
          p(model.mooncode_skills_error)
        } else {
          @html.nothing
        },
      ]),
      match model.mooncode_skill_catalog {
        Some(catalog) if catalog.skills.is_empty() =>
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.skills_empty"),
            "No skills are available for this MoonBook.",
          )
        Some(catalog) =>
          div(
            class="mooncode-skill-catalog-list",
            catalog.skills.map(skill => {
              div(class="mooncode-skill-catalog-item", [
                div(class="mooncode-skill-catalog-title", [
                  strong(skill.name),
                  span(
                    attrs=@html.Attrs::build().data_set(
                      "i18n",
                      if skill.source == "moonbook" {
                        "code.skill_moonbook"
                      } else {
                        "code.skill_installed"
                      },
                    ),
                    if skill.source == "moonbook" {
                      "MoonBook skill"
                    } else {
                      "Installed skill"
                    },
                  ),
                ]),
                p(skill.description),
                code(skill.location),
              ])
            }),
          )
        None => @html.nothing
      },
    ],
  )
}
