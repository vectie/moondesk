///|
test "MoonDesk accepts only MoonClaw-owned metadata skill catalogs" {
  let good : Json = {
    "kind": "mooncode-skill-catalog",
    "owner": "moonclaw",
    "book_root": "/tmp/book",
    "skills": [
      {
        "name": "moonbit-agent-guide",
        "description": "MoonBit guide",
        "source": "installed",
        "location": "/tmp/skills/moonbit-agent-guide/SKILL.md",
        "authority": "moonclaw",
      },
    ],
    "content_included": false,
  }
  assert_true(mooncode_skill_catalog_valid(good, "/tmp/book"))
  assert_false(mooncode_skill_catalog_valid(good, "/tmp/other"))
  assert_false(
    mooncode_skill_catalog_valid(
      {
        "kind": "mooncode-skill-catalog",
        "owner": "moondesk",
        "book_root": "/tmp/book",
        "skills": [],
        "content_included": false,
      },
      "/tmp/book",
    ),
  )
  assert_false(
    mooncode_skill_catalog_valid(
      {
        "kind": "mooncode-skill-catalog",
        "owner": "moonclaw",
        "book_root": "/tmp/book",
        "skills": [],
        "content_included": true,
      },
      "/tmp/book",
    ),
  )
}
