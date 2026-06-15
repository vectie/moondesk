///|
fn town_daemon_path(workspace_root : String) -> String {
  @pathx.join(@pathx.normalize(workspace_root), ".moontown/daemon.json")
}

///|
fn town_standing_goals_path(workspace_root : String) -> String {
  @pathx.join(@pathx.normalize(workspace_root), ".moontown/standing-goals.json")
}

///|
fn town_moonbooks_path(workspace_root : String) -> String {
  @pathx.join(@pathx.normalize(workspace_root), ".moontown/moonbooks.json")
}

///|
fn town_book_template_config_root(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/book-template-configs",
  )
}

///|
fn town_book_template_request_path(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/book-template-requests.json",
  )
}

///|
fn town_book_template_event_path(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/book-template-request-events.jsonl",
  )
}

///|
fn town_moondesk_requests_root(workspace_root : String) -> String {
  @pathx.join(@pathx.normalize(workspace_root), ".moontown/moondesk-requests")
}

///|
fn pdf_watch_moontown_publish_receipt_relative_path() -> String {
  "raw/analysis-runs/moontown-template-publish.json"
}

///|
fn pdf_watch_moontown_standing_goal_receipt_relative_path() -> String {
  "raw/analysis-runs/moontown-standing-goal-registration.json"
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn standing_goal_record_from_payload(
  payload : Json,
  daemon_tick~ : Int,
) -> Json {
  let title = json_string(payload, "title", default="Moondesk standing watch")
  let id = json_string(payload, "id", default=@desk.stable_id("watch", title))
  let cadence = clamp_int(
    json_int(payload, "cadence_ticks", default=60),
    1,
    525600,
  )
  let quality = clamp_int(
    json_int(payload, "quality_threshold", default=85),
    1,
    100,
  )
  let next_due = json_int(payload, "next_due_tick", default=daemon_tick)
  {
    "id": id,
    "title": title,
    "prompt": json_string(payload, "prompt", default=""),
    "target_book_id": json_string(payload, "target_book_id", default=""),
    "cadence_ticks": cadence,
    "next_due_tick": next_due,
    "last_run_tick": match json_int(payload, "last_run_tick", default=-1) {
      -1 => Json::null()
      tick => tick.to_json()
    },
    "enabled": json_bool(payload, "enabled", default=true),
    "source_policy": json_string(payload, "source_policy", default="web-first"),
    "quality_threshold": quality,
  }
}

///|
fn book_pattern_records() -> Array[Json] {
  [
    {
      "id": "pdf-evidence-watch",
      "title": "PDF Evidence Watch Book",
      "base_type": "research-book",
      "description": "A reusable research-book pattern that watches websites, discovers PDFs, extracts text, analyzes against a method page, and notifies only when accepted knowledge changes.",
      "output": "wiki findings and generated book site",
      "default_topic": "my domain",
      "default_cadence_minutes": 30,
      "default_source_policy": "web-first",
      "default_websites": json_from_string_array([
        "https://example.org/reports", "https://example.com/publications",
      ]),
      "skills": json_from_string_array(["pdf-watch", "pdf-analysis"]),
    },
    {
      "id": "exchangeable-bond-evidence-watch",
      "title": "Exchangeable Bond Evidence Watch",
      "base_type": "research-book",
      "description": "A domain-specific PDF evidence watch book for exchangeable bond lifecycle, credit, and compliance tracking from official disclosures.",
      "output": "reviewed wiki findings plus EB tracking XLSX contract",
      "default_topic": "exchangeable bond credit compliance",
      "default_cadence_minutes": 30,
      "default_source_policy": "web-first",
      "default_websites": json_from_string_array(eb_default_source_websites()),
      "skills": json_from_string_array([
        "pdf-watch", "pdf-analysis", "eb-credit-compliance",
      ]),
    },
  ]
}

///|
async fn book_pattern_records_for_workspace(
  workspace_root : String,
) -> Array[Json] {
  let mut records = book_pattern_records()
  for record in book_pattern_records_from_template_registry(workspace_root) {
    records = upsert_record_by_id(records, record)
  }
  records
}

///|
async fn book_base_type_records_for_workspace(
  workspace_root : String,
) -> Array[Json] {
  book_base_type_records_from_patterns(
    book_pattern_records_for_workspace(workspace_root),
  )
}

///|
fn book_base_type_records_from_patterns(patterns : Array[Json]) -> Array[Json] {
  let base_types : Array[String] = []
  for pattern in patterns {
    let base_type = json_string(pattern, "base_type", default="research-book")
      .trim()
      .to_owned()
    if base_type != "" && !base_types.contains(base_type) {
      base_types.push(base_type)
    }
  }
  if base_types.length() == 0 {
    base_types.push("research-book")
  }
  let records : Array[Json] = []
  for base_type in base_types {
    let supported_patterns : Array[String] = []
    let template_refs : Array[String] = []
    for pattern in patterns {
      if json_string(pattern, "base_type", default="research-book") == base_type {
        let id = json_string(pattern, "id", default="")
        if id != "" && !supported_patterns.contains(id) {
          supported_patterns.push(id)
        }
        for
          template_ref in json_string_array_items(
            pattern, "template_registry_refs",
          ) {
          if template_ref != "" && !template_refs.contains(template_ref) {
            template_refs.push(template_ref)
          }
        }
      }
    }
    if base_type == "research-book" {
      for template_ref in pdf_watch_template_registry_refs() {
        if !template_refs.contains(template_ref) {
          template_refs.push(template_ref)
        }
      }
    }
    records.push(
      book_base_type_record(
        base_type,
        supported_patterns~,
        template_registry_refs=template_refs,
      ),
    )
  }
  records
}

///|
fn book_base_type_record(
  base_type : String,
  supported_patterns~ : Array[String],
  template_registry_refs~ : Array[String],
) -> Json {
  {
    "id": base_type,
    "title": book_base_type_title(base_type),
    "description": book_base_type_description(base_type),
    "owner": "MoonBook",
    "source": "moontown-template-registry + moonbook-layout",
    "creation_palette_source": "../moontown/templates/books/templates.json",
    "moonbook_layout_refs": json_from_string_array(moonbook_layout_refs()),
    "template_registry_refs": json_from_string_array(template_registry_refs),
    "supported_patterns": json_from_string_array(supported_patterns),
    "required_roots": json_from_string_array(
      book_base_type_required_roots(base_type),
    ),
  }
}

///|
fn book_base_type_title(base_type : String) -> String {
  match base_type {
    "research-book" => "Research Book"
    "toolbook" => "ToolBook"
    _ => base_type_to_title(base_type)
  }
}

///|
fn book_base_type_description(base_type : String) -> String {
  match base_type {
    "research-book" =>
      "Durable MoonBook base for source-backed research, wiki memory, source evidence, review queues, generated sites, and standing-watch workflows."
    "toolbook" =>
      "Durable MoonBook base for a generated web tool, analysis reports, review artifacts, app assets, and Moontown-exposed tool surfaces."
    _ =>
      "Durable MoonBook base discovered from the current Moontown template registry."
  }
}

///|
fn book_base_type_required_roots(base_type : String) -> Array[String] {
  match base_type {
    "toolbook" =>
      [
        "book.json", "raw/", "wiki/", "skills/", "schemas/", "app/", "site/generated/",
      ]
    _ =>
      ["book.json", "raw/", "wiki/", "skills/", "schemas/", "site/generated/"]
  }
}

///|
fn base_type_to_title(base_type : String) -> String {
  let words : Array[String] = []
  for part in base_type.split("-") {
    let part = part.trim().to_owned()
    if part == "" {
      continue
    }
    words.push(capitalize_ascii(part))
  }
  if words.length() == 0 {
    base_type
  } else {
    words.join(" ")
  }
}

///|
fn capitalize_ascii(text : String) -> String {
  if text.length() == 0 {
    return text
  }
  let first = text[:1].to_upper().to_owned()
  if text.length() == 1 {
    first
  } else {
    first + text[1:].to_owned()
  }
}

///|
async fn book_pattern_records_from_template_registry(
  workspace_root : String,
) -> Array[Json] {
  let records : Array[Json] = []
  for source in book_template_registry_sources(workspace_root) {
    let path = json_string(source, "path", default="")
    if !json_bool(source, "exists", default=false) {
      continue
    }
    let registry = read_json_file_or_object(path)
    for template in json_array_items(registry, "templates") {
      let id = json_string(template, "template_id", default="")
      if id == "" {
        continue
      }
      records.push(
        book_pattern_record_from_template(
          template,
          registry_root=json_string(source, "root", default=""),
        ),
      )
    }
    if records.length() > 0 {
      return records
    }
  }
  records
}

///|
async fn book_template_registry_status(workspace_root : String) -> Json {
  let sources = book_template_registry_sources(workspace_root)
  let templates : Array[Json] = []
  let missing_paths : Array[String] = []
  let mut selected_path = ""
  let mut selected_root = ""
  for source in sources {
    let path = json_string(source, "path", default="")
    if !json_bool(source, "exists", default=false) || selected_path != "" {
      continue
    }
    let registry = read_json_file_or_object(path)
    for template in json_array_items(registry, "templates") {
      templates.push(template)
      for
        missing in book_template_missing_paths(
          template,
          registry_root=json_string(source, "root", default=""),
        ) {
        missing_paths.push(missing)
      }
    }
    selected_path = path
    selected_root = json_string(source, "root", default="")
  }
  {
    "kind": "moontown-book-template-registry-status",
    "ready": selected_path != "" &&
    templates.length() > 0 &&
    missing_paths.length() == 0,
    "selected_path": selected_path,
    "selected_root": selected_root,
    "sources": Json::array(sources),
    "template_count": templates.length(),
    "missing_count": missing_paths.length(),
    "missing_paths": json_from_string_array(missing_paths),
    "templates": Json::array(templates),
    "base_types": Json::array(
      book_base_type_records_from_patterns(
        book_pattern_records_for_workspace(workspace_root),
      ),
    ),
  }
}

///|
async fn book_template_registry_sources(workspace_root : String) -> Array[Json] {
  let sources : Array[Json] = []
  let roots = [
    @pathx.normalize(workspace_root),
    @pathx.normalize("../moontown"),
  ]
  let seen : Array[String] = []
  for root in roots {
    if root == "" || seen.contains(root) {
      continue
    }
    seen.push(root)
    let path = @pathx.join(root, "templates/books/templates.json")
    sources.push({ "root": root, "path": path, "exists": @fs.exists(path) })
  }
  sources
}

///|
fn moonbook_layout_refs() -> Array[String] {
  [
    "../moonbook/docs/CLI_AND_LAYOUT.md", "../moonbook/docs/SYSTEM_ARCHITECTURE.md",
    "../moonbook/docs/FEATURE_MATRIX.md",
  ]
}

///|
fn pdf_watch_template_registry_refs() -> Array[String] {
  [
    "../moontown/templates/books/templates.json", "../moontown/templates/books/pdf-evidence-watch/book.json",
    "../moontown/docs/DOC_STRUCTURE.md", "../moontown/docs/USAGE.md",
  ]
}

///|
fn pdf_watch_base_type_provenance_json() -> Json {
  {
    "base_type": "research-book",
    "source": "moontown-template-registry + moonbook-layout",
    "creation_palette_source": "../moontown/templates/books/templates.json",
    "moonbook_owner": "MoonBook",
    "moontown_template_id": "pdf-evidence-watch",
    "moondesk_pattern_contract": "research-book + source adapter + extractor + analysis skill + standing watch",
    "moonbook_layout_refs": json_from_string_array(moonbook_layout_refs()),
    "template_registry_refs": json_from_string_array(
      pdf_watch_template_registry_refs(),
    ),
  }
}

///|
async fn book_pattern_record_from_template(
  template : Json,
  registry_root~ : String,
) -> Json {
  let id = json_string(template, "template_id", default="")
  let install_path = resolve_registry_relative_path(
    registry_root,
    json_string(template, "install_example", default=""),
  )
  let install = read_json_file_or_object(install_path)
  let websites = json_string_array_items(install, "websites")
  let cadence = json_int(install, "cadence_ticks", default=30)
  let skills = template_skill_ids(template)
  {
    "id": id,
    "title": json_string(template, "title", default=id),
    "base_type": json_string(template, "book_type", default="research-book"),
    "description": json_string(
      template,
      "purpose",
      default="Reusable MoonBook template.",
    ),
    "output": if id == "pdf-evidence-watch" {
      "wiki findings and generated book site"
    } else {
      "template-defined MoonBook outputs"
    },
    "default_topic": "my domain",
    "default_cadence_minutes": cadence,
    "default_source_policy": "web-first",
    "default_websites": json_from_string_array(websites),
    "skills": json_from_string_array(skills),
    "template_registry_refs": json_from_string_array(
      template_registry_refs_from_template(template, registry_root~),
    ),
  }
}

///|
fn template_registry_refs_from_template(
  template : Json,
  registry_root~ : String,
) -> Array[String] {
  let refs : Array[String] = []
  let registry_ref = registry_ref_from_root(
    registry_root, "templates/books/templates.json",
  )
  if registry_ref != "" {
    refs.push(registry_ref)
  }
  let book_ref = registry_ref_from_root(
    registry_root,
    json_string(template, "root", default="") + "/book.json",
  )
  if book_ref != "" && !refs.contains(book_ref) {
    refs.push(book_ref)
  }
  refs
}

///|
fn registry_ref_from_root(root : String, relative : String) -> String {
  if root == "" || relative == "" {
    return ""
  }
  if root.has_suffix("/moontown") {
    "../moontown/" + relative
  } else {
    @pathx.join(root, relative)
  }
}

///|
async fn book_template_missing_paths(
  template : Json,
  registry_root~ : String,
) -> Array[String] {
  let missing : Array[String] = []
  let template_root = resolve_registry_relative_path(
    registry_root,
    json_string(template, "root", default=""),
  )
  if template_root != "" && !@fs.exists(template_root) {
    missing.push(template_root)
  }
  let install_example = resolve_registry_relative_path(
    registry_root,
    json_string(template, "install_example", default=""),
  )
  if install_example != "" && !@fs.exists(install_example) {
    missing.push(install_example)
  }
  for required in json_string_array_items(template, "required_paths") {
    let path = if required.has_prefix("/") {
      required
    } else {
      @pathx.join(template_root, required)
    }
    if path != "" && !@fs.exists(path) && !missing.contains(path) {
      missing.push(path)
    }
  }
  missing
}

///|
fn resolve_registry_relative_path(root : String, path : String) -> String {
  if path == "" || path.has_prefix("/") {
    path
  } else {
    @pathx.join(root, path)
  }
}

///|
fn template_skill_ids(template : Json) -> Array[String] {
  let skills : Array[String] = []
  collect_template_skill_ids(
    skills,
    json_string_array_items(template, "required_paths"),
  )
  collect_template_skill_ids(
    skills,
    json_string_array_items(template, "editable_files"),
  )
  if skills.length() == 0 &&
    json_string(template, "template_id", default="") == "pdf-evidence-watch" {
    skills.push("pdf-watch")
    skills.push("pdf-analysis")
  }
  skills
}

///|
fn collect_template_skill_ids(
  skills : Array[String],
  paths : Array[String],
) -> Unit {
  for path in paths {
    let id = template_skill_id_from_path(path)
    if id != "" && !skills.contains(id) {
      skills.push(id)
    }
  }
}

///|
fn template_skill_id_from_path(path : String) -> String {
  let prefix = "skills/"
  let suffix = "/SKILL.md"
  if !path.has_prefix(prefix) || !path.has_suffix(suffix) {
    return ""
  }
  path[prefix.length():path.length() - suffix.length()].to_string()
}

///|
fn book_pattern_base_type(pattern_id : String) -> String {
  if pattern_id == "exchangeable-bond-evidence-watch" ||
    pattern_id == "pdf-evidence-watch" {
    "research-book"
  } else {
    "research-book"
  }
}

///|
fn normalize_book_pattern_id(pattern_id : String) -> String {
  match pattern_id.trim().to_owned() {
    "exchangeable-bond-evidence-watch" => "exchangeable-bond-evidence-watch"
    "eb-evidence-watch" => "exchangeable-bond-evidence-watch"
    "pdf-evidence-watch" => "pdf-evidence-watch"
    _ => "pdf-evidence-watch"
  }
}

///|
fn normalize_book_pattern_id_strict(pattern_id : String) -> String {
  match pattern_id.trim().to_owned() {
    "exchangeable-bond-evidence-watch" => "exchangeable-bond-evidence-watch"
    "eb-evidence-watch" => "exchangeable-bond-evidence-watch"
    "pdf-evidence-watch" => "pdf-evidence-watch"
    _ => ""
  }
}

///|
fn pdf_watch_pattern_id_from_book_json(book_json : Json) -> String {
  let pattern = normalize_book_pattern_id_strict(
    json_string(book_json, "pattern", default=""),
  )
  if pattern != "" {
    return pattern
  }
  let specialization = normalize_book_pattern_id_strict(
    json_string(book_json, "specialization", default=""),
  )
  if specialization != "" {
    return specialization
  }
  let legacy_book_type = normalize_book_pattern_id_strict(
    json_string(book_json, "book_type", default=""),
  )
  if legacy_book_type != "" {
    return legacy_book_type
  }
  normalize_book_pattern_id_strict(json_string(book_json, "type", default=""))
}

///|
fn pdf_watch_book_id(
  topic : String,
  pattern_id? : String = "pdf-evidence-watch",
) -> String {
  let suffix = if pattern_id == "exchangeable-bond-evidence-watch" {
    "-eb-watch"
  } else {
    "-pdf-watch"
  }
  let base = @desk.stable_id("research", topic)
  if base.has_suffix(suffix) {
    base
  } else {
    base + suffix
  }
}

///|
fn normalize_pdf_watch_book_id(
  requested : String,
  topic~ : String,
  pattern_id~ : String,
) -> String {
  let cleaned = sanitize_external_id(requested)
  if cleaned != "" {
    cleaned
  } else {
    pdf_watch_book_id(topic, pattern_id~)
  }
}

///|
fn sanitize_external_id(value : String) -> String {
  let mut out = ""
  for ch in value.trim() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out = out + ch.to_string()
    } else if ch >= 'A' && ch <= 'Z' {
      out = out + ch.to_string().to_lower()
    } else if out != "" && !out.has_suffix("-") {
      out = out + "-"
    }
  }
  out.trim(chars=['-']).to_owned()
}

///|
fn host_absolute_path(path : String) -> String {
  if @pathx.is_absolute(path) {
    @pathx.normalize(path)
  } else {
    @pathx.join(@pathx.normalize(@env.current_dir().unwrap_or(".")), path)
  }
}

///|
fn trimmed_payload_text(text : String, default~ : String) -> String {
  let text = text.trim().to_owned()
  if text == "" {
    default
  } else {
    text
  }
}

///|
fn json_string_array_items(json : Json, key : String) -> Array[String] {
  let values : Array[String] = []
  for item in json_array_items(json, key) {
    match item {
      Json::String(value) => {
        let value = value.trim().to_owned()
        if value != "" {
          values.push(value)
        }
      }
      _ => ()
    }
  }
  values
}

///|
fn pdf_watch_notify_on_from_payload(payload : Json) -> Array[String] {
  let values = json_string_array_items(payload, "notify_on")
  if values.length() > 0 {
    values
  } else {
    let analysis = json_object_field_or_empty(payload, "analysis")
    let analysis_values = json_string_array_items(analysis, "notify_on")
    if analysis_values.length() > 0 {
      analysis_values
    } else {
      let watch = json_object_field_or_empty(payload, "watch")
      let watch_values = json_string_array_items(watch, "notify_on")
      if watch_values.length() > 0 {
        watch_values
      } else {
        let notify_rule = json_string(
            payload,
            "notify_rule",
            default="accepted_new_knowledge",
          )
          .trim()
          .to_owned()
        if notify_rule == "" {
          ["accepted_new_knowledge"]
        } else {
          [notify_rule]
        }
      }
    }
  }
}

///|
fn pdf_watch_websites_from_payload(payload : Json) -> Array[String] {
  let direct = json_string_array_items(payload, "websites")
  if direct.length() > 0 {
    direct
  } else {
    json_string_array_items(
      json_object_field_or_empty(payload, "watch"),
      "websites",
    )
  }
}

///|
fn pdf_watch_cadence_from_payload(payload : Json) -> Int {
  let watch = json_object_field_or_empty(payload, "watch")
  let direct = json_int(payload, "cadence_minutes", default=-1)
  if direct > 0 {
    clamp_int(direct, 1, 525600)
  } else {
    let nested_minutes = json_int(watch, "cadence_minutes", default=-1)
    if nested_minutes > 0 {
      clamp_int(nested_minutes, 1, 525600)
    } else {
      clamp_int(
        json_int(
          payload,
          "cadence_ticks",
          default=json_int(watch, "cadence_ticks", default=30),
        ),
        1,
        525600,
      )
    }
  }
}

///|
fn pdf_watch_source_policy_from_payload(payload : Json) -> String {
  let direct = json_string(payload, "source_policy", default="")
    .trim()
    .to_owned()
  if direct != "" {
    direct
  } else {
    let watch = json_object_field_or_empty(payload, "watch")
    let nested = json_string(watch, "source_policy", default="web-first")
      .trim()
      .to_owned()
    if nested == "" {
      "web-first"
    } else {
      nested
    }
  }
}

///|
fn pdf_watch_skill_pack_from_payload(
  payload : Json,
  pattern_id : String,
) -> Array[String] {
  let requested = json_string_array_items(payload, "skill_pack")
  let defaults = default_skill_pack_for_pattern(pattern_id)
  let selected : Array[String] = []
  for skill in requested {
    if skill != "" && !selected.contains(skill) {
      selected.push(skill)
    }
  }
  for skill in defaults {
    if !selected.contains(skill) {
      selected.push(skill)
    }
  }
  selected
}

///|
fn default_skill_pack_for_pattern(pattern_id : String) -> Array[String] {
  if pattern_id == "exchangeable-bond-evidence-watch" {
    ["pdf-watch", "pdf-analysis", "eb-credit-compliance"]
  } else {
    ["pdf-watch", "pdf-analysis"]
  }
}

///|
fn eb_target_fields_from_payload(payload : Json) -> Json {
  let source = match json_object_field(payload, "eb_target_fields") {
    Some(Json::Object(_)) =>
      json_object_field_or_empty(payload, "eb_target_fields")
    _ =>
      match json_object_field(payload, "target_fields") {
        Some(Json::Object(_)) =>
          json_object_field_or_empty(payload, "target_fields")
        _ => payload
      }
  }
  eb_target_fields_from_json(source)
}

///|
fn eb_target_fields_from_json(source : Json) -> Json {
  {
    "bond_full_name_or_short_name": json_first_string(
      source,
      ["bond_short_name", "bond_full_name_or_short_name"],
      default="",
    ),
    "bond_code": json_string(source, "bond_code", default=""),
    "issuer": json_string(source, "issuer", default=""),
    "underlying_listed_company": json_first_string(
      source,
      ["underlying_company", "underlying_listed_company"],
      default="",
    ),
    "exchange": json_string(source, "exchange", default=""),
    "lifecycle_status": json_first_string(
      source,
      ["lifecycle_status", "status", "bond_status"],
      default="",
    ),
    "maturity_date": json_first_string(
      source,
      ["maturity_date", "delisted_date", "redeemed_date"],
      default="",
    ),
  }
}

///|
fn eb_target_bonds_from_payload(payload : Json) -> Array[Json] {
  for key in ["eb_target_bonds", "target_bonds", "bonds"] {
    let bonds : Array[Json] = []
    for item in json_array_items(payload, key) {
      match item {
        Json::Object(_) => {
          let normalized = eb_target_fields_from_json(item)
          if eb_target_has_identity(normalized) {
            bonds.push(normalized)
          }
        }
        _ => ()
      }
    }
    if bonds.length() > 0 {
      return bonds
    }
  }
  let fields = eb_target_fields_from_payload(payload)
  if eb_target_has_identity(fields) {
    [fields]
  } else {
    []
  }
}

///|
fn normalize_eb_target_scope(scope : String) -> String {
  let clean = scope.trim().to_lower()
  match clean {
    "active_universe" | "active-universe" | "universe" | "active" =>
      "active_universe"
    "portfolio" | "multi_bond" | "multi-bond" | "multi" => "portfolio"
    "single_bond" | "single-bond" | "single" => "single_bond"
    _ => ""
  }
}

///|
fn infer_eb_target_scope(
  scope : String,
  target_fields : Json,
  target_bonds : Array[Json],
) -> String {
  let explicit = normalize_eb_target_scope(scope)
  if explicit != "" {
    return explicit
  }
  if target_bonds.length() > 1 {
    return "portfolio"
  }
  if target_bonds.length() == 1 || eb_target_has_identity(target_fields) {
    return "single_bond"
  }
  "active_universe"
}

///|
fn eb_target_scope_from_payload(
  payload : Json,
  target_fields : Json,
  target_bonds : Array[Json],
) -> String {
  infer_eb_target_scope(
    json_first_string(payload, ["eb_target_scope", "target_scope"], default=""),
    target_fields,
    target_bonds,
  )
}

///|
fn eb_effective_target_bonds(
  target_scope : String,
  target_fields : Json,
  target_bonds : Array[Json],
) -> Array[Json] {
  let normalized_bonds : Array[Json] = []
  for target in target_bonds {
    let normalized = eb_target_fields_from_json(target)
    if eb_target_has_identity(normalized) {
      normalized_bonds.push(normalized)
    }
  }
  if normalized_bonds.length() > 0 {
    return normalized_bonds
  }
  if target_scope != "active_universe" && eb_target_has_identity(target_fields) {
    [eb_target_fields_from_json(target_fields)]
  } else {
    []
  }
}

///|
fn effective_eb_target_fields(
  target_fields : Json,
  target_bonds : Array[Json],
) -> Json {
  if eb_target_has_identity(target_fields) {
    return target_fields
  }
  match target_bonds.get(0) {
    Some(first) => first
    None => target_fields
  }
}

///|
fn eb_target_scope_from_config(config : Json) -> String {
  normalize_eb_target_scope(json_string(config, "target_scope", default=""))
}

///|
async fn eb_target_scope_from_book(book_root : String) -> String {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let book_targets = json_object_field_or_empty(book_json, "targets")
  let book_scope = eb_target_scope_from_config(book_targets)
  if book_scope != "" {
    return book_scope
  }
  let request = read_json_file_or_object(
    @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
  )
  let request_scope = normalize_eb_target_scope(
    json_string(request, "target_scope", default=""),
  )
  if request_scope != "" {
    return request_scope
  }
  infer_eb_target_scope(
    "",
    eb_target_fields_from_json(
      json_object_field_or_empty(request, "target_fields"),
    ),
    eb_production_targets_from_book(book_root),
  )
}

///|
fn eb_target_has_identity(target : Json) -> Bool {
  json_string(target, "bond_code", default="") != "" ||
  json_string(target, "bond_full_name_or_short_name", default="") != "" ||
  json_string(target, "issuer", default="") != "" ||
  json_string(target, "underlying_listed_company", default="") != ""
}

///|
async fn eb_production_targets_from_book(book_root : String) -> Array[Json] {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let targets = json_object_field_or_empty(book_json, "targets")
  let bonds : Array[Json] = []
  for item in json_array_items(targets, "bonds") {
    match item {
      Json::Object(_) => {
        let normalized = eb_target_fields_from_json(item)
        if eb_target_has_identity(normalized) {
          bonds.push(normalized)
        }
      }
      _ => ()
    }
  }
  if bonds.length() > 0 {
    return bonds
  }
  let request = read_json_file_or_object(
    @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
  )
  for item in json_array_items(request, "target_bonds") {
    match item {
      Json::Object(_) => {
        let normalized = eb_target_fields_from_json(item)
        if eb_target_has_identity(normalized) {
          bonds.push(normalized)
        }
      }
      _ => ()
    }
  }
  if bonds.length() > 0 {
    bonds
  } else {
    let fallback = eb_target_fields_from_json(
      json_object_field_or_empty(request, "target_fields"),
    )
    if eb_target_has_identity(fallback) {
      [fallback]
    } else {
      []
    }
  }
}

///|
fn eb_target_text_is_placeholder(text : String) -> Bool {
  let clean = text.trim().to_owned()
  clean == "" ||
  clean.contains("示例") ||
  clean.contains("样例") ||
  clean.contains("测试") ||
  clean.contains("请在此处填入") ||
  clean.contains("[") ||
  clean.contains("]") ||
  clean.to_lower().contains("example") ||
  clean.to_lower().contains("placeholder")
}

///|
fn eb_target_code_is_production(code : String) -> Bool {
  let clean = code.trim().to_owned()
  if clean.length() != 6 || !clean.has_prefix("132") || clean == "132001" {
    return false
  }
  for ch in clean {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn eb_target_exchange_is_production(exchange : String) -> Bool {
  let clean = exchange.trim().to_owned()
  clean == "上交所" ||
  clean == "深交所" ||
  clean == "上海证券交易所" ||
  clean == "深圳证券交易所"
}

///|
fn eb_target_production_failed_checks(target : Json) -> Array[String] {
  let failed : Array[String] = []
  let code = json_string(target, "bond_code", default="")
  let short_name = json_string(
    target,
    "bond_full_name_or_short_name",
    default="",
  )
  let issuer = json_string(target, "issuer", default="")
  let underlying = json_string(target, "underlying_listed_company", default="")
  let exchange = json_string(target, "exchange", default="")
  push_failed_unless(
    failed,
    eb_target_code_is_production(code),
    "target bond code is a real 132XXX EB code, not the sample 132001",
  )
  push_failed_unless(
    failed,
    !eb_target_text_is_placeholder(short_name),
    "target bond short/full name is filled and not a placeholder",
  )
  push_failed_unless(
    failed,
    !eb_target_text_is_placeholder(issuer),
    "target issuer is filled and not a placeholder",
  )
  push_failed_unless(
    failed,
    !eb_target_text_is_placeholder(underlying),
    "target underlying listed company is filled and not a placeholder",
  )
  push_failed_unless(
    failed,
    eb_target_exchange_is_production(exchange),
    "target exchange is 上交所 or 深交所",
  )
  failed
}

///|
async fn eb_production_target_readiness(book_root : String) -> Json {
  let target_scope = eb_target_scope_from_book(book_root)
  let targets = eb_production_targets_from_book(book_root)
  let failed : Array[String] = []
  let target_results : Array[Json] = []
  let mut ready_count = 0
  if target_scope == "active_universe" {
    return {
      "kind": "eb-production-target-readiness",
      "ok": true,
      "target_scope": target_scope,
      "active_universe_default": true,
      "target_count": targets.length(),
      "ready_target_count": targets.length(),
      "failed_checks": json_from_string_array([]),
      "targets": Json::array(target_results),
      "message": "Active EB universe watch does not require a preselected single bond target.",
    }
  }
  if targets.length() == 0 {
    failed.push("at least one EB target bond is configured")
  }
  for index, target in targets {
    let target_failed = eb_target_production_failed_checks(target)
    if target_failed.length() == 0 {
      ready_count += 1
    } else {
      failed.push(
        "target " + (index + 1).to_string() + ": " + target_failed.join("; "),
      )
    }
    target_results.push({
      "index": index + 1,
      "ok": target_failed.length() == 0,
      "target": target,
      "failed_checks": json_from_string_array(target_failed),
    })
  }
  {
    "kind": "eb-production-target-readiness",
    "ok": targets.length() > 0 && failed.length() == 0,
    "target_scope": target_scope,
    "active_universe_default": false,
    "target_count": targets.length(),
    "ready_target_count": ready_count,
    "failed_checks": json_from_string_array(failed),
    "targets": Json::array(target_results),
  }
}

///|
fn eb_target_not_ready_payload(
  book_id : String,
  target_readiness : Json,
) -> Json {
  {
    "ok": false,
    "status": "target_not_ready",
    "book_id": book_id,
    "message": "EB target bond configuration must be production-ready before MoonClaw import or execution",
    "target_readiness": target_readiness,
    "failed_checks": json_from_string_array(
      json_string_array_items(target_readiness, "failed_checks"),
    ),
  }
}

///|
async fn eb_moonclaw_target_gate(book_root : String, book_id : String) -> Json {
  let target_readiness = eb_production_target_readiness(book_root)
  if json_bool(target_readiness, "ok", default=false) {
    {
      "ok": true,
      "status": "target_ready",
      "book_id": book_id,
      "target_readiness": target_readiness,
    }
  } else {
    eb_target_not_ready_payload(book_id, target_readiness)
  }
}

///|
fn json_object_field_or_empty(json : Json, key : String) -> Json {
  match json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn json_from_string_array(items : Array[String]) -> Json {
  let values : Array[Json] = []
  for item in items {
    values.push(item.to_json())
  }
  Json::array(values)
}

///|
fn json_from_json_array(items : Array[Json]) -> Json {
  Json::array(items)
}

///|
fn eb_toolbook_manifest_seed_json(book_id : String) -> Json {
  let tool : Json = {
    "id": "eb-evidence-dashboard",
    "title": "EB Evidence Dashboard",
    "entrypoints": json_from_string_array([
      "book/site/generated/tool.html", "app/index.html",
    ]),
  }
  let outputs : Json = { "xlsx": "", "source_screen": "" }
  {
    "kind": "app-tool-book-manifest",
    "template_id": "app-tool-book",
    "book_id": book_id,
    "tool": tool,
    "outputs": outputs,
    "extensible": true,
    "status": "waiting_for_accepted_run",
  }
}

///|
async fn write_bytes_file(
  path : String,
  bytes : Bytes,
  create? : Int = 0o644,
) -> Unit {
  @fs.write_file(path, bytes, create~, truncate=true)
}

///|
fn base64_value(ch : Char) -> Int {
  let code = ch.to_int()
  if ch >= 'A' && ch <= 'Z' {
    code - 'A'.to_int()
  } else if ch >= 'a' && ch <= 'z' {
    code - 'a'.to_int() + 26
  } else if ch >= '0' && ch <= '9' {
    code - '0'.to_int() + 52
  } else if ch == '+' {
    62
  } else if ch == '/' {
    63
  } else {
    -1
  }
}

///|
fn base64_decode_bytes(text : String) -> Bytes {
  let values : Array[Int] = []
  let padding : Array[Bool] = []
  let bytes : Array[Byte] = []
  for ch in text {
    if ch == '=' {
      values.push(0)
      padding.push(true)
    } else {
      let value = base64_value(ch)
      if value >= 0 {
        values.push(value)
        padding.push(false)
      }
    }
    if values.length() == 4 {
      bytes.push((values[0] * 4 + values[1] / 16).to_byte())
      if !padding[2] {
        bytes.push((values[1] % 16 * 16 + values[2] / 4).to_byte())
      }
      if !padding[3] {
        bytes.push((values[2] % 4 * 64 + values[3]).to_byte())
      }
      values.clear()
      padding.clear()
    }
  }
  Bytes::from_array(bytes)
}
