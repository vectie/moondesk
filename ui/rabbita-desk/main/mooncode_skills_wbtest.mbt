///|
#warnings("-alert_unstable")
test "Code skill catalog keeps MoonClaw provenance and ignores old workspace replies" {
  let model = { ..init_model(), selected_workspace_id: "book-a", }
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSkills,
    model,
  )
  assert_true(opened.mooncode_skills_visible)
  assert_true(opened.mooncode_skills_loading)
  let catalog : MoonCodeSkillCatalogProjection = {
    kind: "mooncode-skill-catalog",
    owner: "moonclaw",
    book_root: "/tmp/book-a",
    skills: [
      {
        name: "moonbit-agent-guide",
        description: "Guide for MoonBit changes",
        source: "installed",
        location: "/tmp/skills/moonbit-agent-guide/SKILL.md",
        authority: "moonclaw",
      },
    ],
    skill_count: 1,
    content_included: false,
  }
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeSkills("book-b", Ok(catalog)),
    opened,
  )
  assert_true(stale.mooncode_skills_loading)
  let (_, loaded) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeSkills("book-a", Ok(catalog)),
    opened,
  )
  assert_false(loaded.mooncode_skills_loading)
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_skill_catalog(code_mode_test_dispatch, loaded),
    ),
  )
  assert_true(markup.contains("moonbit-agent-guide"))
  assert_true(markup.contains("Installed skill"))
  assert_true(markup.contains("MoonClaw discovers"))
  assert_true(markup.contains("data-i18n=\"code.skills_title\""))
  assert_true(markup.contains("data-i18n=\"code.skills_desc\""))
  assert_true(markup.contains("data-i18n=\"code.skill_installed\""))
  let (_, hidden) = update_mooncode_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSkills,
    loaded,
  )
  assert_false(hidden.mooncode_skills_visible)
  let switched = { ..loaded, selected_workspace_id: "book-b", }
  let switched_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_skill_catalog(code_mode_test_dispatch, switched),
    ),
  )
  assert_false(switched_markup.contains("moonbit-agent-guide"))
}
