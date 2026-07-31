///|
priv struct MoonFlowCapabilityCatalogResolution {
  catalog : Json?
  evidence : Json
}

///|
fn moonflow_capability_catalog_contract() -> String {
  "moonflow.capability-catalog.v1"
}

///|
fn moonflow_capability_catalog_status_contract() -> String {
  "moondesk.moonflow-capability-catalog-status.v1"
}

///|
fn moonflow_capability_catalog_candidate(
  book_root : String,
  override_path : String,
) -> (String, String) {
  let requested = override_path.trim().to_owned()
  if requested == "" {
    (@pathx.join(book_root, "flow/capability-catalog.json"), "book")
  } else if @pathx.is_absolute(requested) {
    (@pathx.normalize(requested), "environment")
  } else {
    (@pathx.join(book_root, requested), "environment")
  }
}

///|
fn moonflow_capability_catalog_evidence(
  path : String,
  source : String,
  evaluated_at : String,
  status : String,
  catalog? : Json,
  digest? : String = "",
) -> Json {
  {
    "contract_id": moonflow_capability_catalog_status_contract(),
    "catalog_contract_id": match catalog {
      Some(value) => json_string(value, "contract_id", default="")
      None => ""
    },
    "catalog_id": match catalog {
      Some(value) => json_string(value, "catalog_id", default="")
      None => ""
    },
    "catalog_status": status,
    "catalog_source": source,
    "catalog_path": path,
    "catalog_digest": digest,
    "catalog_compiled_at": match catalog {
      Some(value) => json_string(value, "compiled_at", default="")
      None => ""
    },
    "catalog_conformant": match catalog {
      Some(value) => json_bool(value, "conformant", default=false)
      None => false
    },
    "evaluated_at": evaluated_at,
  }
}

///|
async fn moonflow_resolve_capability_catalog(
  book_root : String,
  evaluated_at : String,
) -> MoonFlowCapabilityCatalogResolution {
  let override_path = @sys.get_env_var("MOONFLOW_CAPABILITY_CATALOG").unwrap_or(
    "",
  )
  let (path, source) = moonflow_capability_catalog_candidate(
    book_root, override_path,
  )
  if !@fs.exists(path) {
    return {
      catalog: None,
      evidence: moonflow_capability_catalog_evidence(
        path, source, evaluated_at, "missing",
      ),
    }
  }
  if source == "book" {
    let canonical_book = @fs.realpath(book_root) catch { _ => "" }
    let canonical_path = @fs.realpath(path) catch { _ => "" }
    if canonical_book == "" ||
      canonical_path == "" ||
      !canonical_path.has_prefix(canonical_book + "/") {
      return {
        catalog: None,
        evidence: moonflow_capability_catalog_evidence(
          path, source, evaluated_at, "outside_book",
        ),
      }
    }
  }
  let bytes = @fs.read_file(path).binary() catch {
    _ =>
      return {
        catalog: None,
        evidence: moonflow_capability_catalog_evidence(
          path, source, evaluated_at, "unreadable",
        ),
      }
  }
  let digest = "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
  let catalog = @json.parse(@encoding/utf8.decode_lossy(bytes)) catch {
    _ =>
      return {
        catalog: None,
        evidence: moonflow_capability_catalog_evidence(
          path,
          source,
          evaluated_at,
          "invalid_json",
          digest~,
        ),
      }
  }
  if json_string(catalog, "contract_id", default="") !=
    moonflow_capability_catalog_contract() {
    return {
      catalog: None,
      evidence: moonflow_capability_catalog_evidence(
        path,
        source,
        evaluated_at,
        "unsupported_contract",
        catalog~,
        digest~,
      ),
    }
  }
  {
    catalog: Some(catalog),
    evidence: moonflow_capability_catalog_evidence(
      path,
      source,
      evaluated_at,
      "loaded",
      catalog~,
      digest~,
    ),
  }
}

///|
fn moonflow_catalog_operation(catalog : Json, operation_ref : String) -> Json? {
  guard json_object_field(catalog, "operations") is Some(Array(operations)) else {
    return None
  }
  let matches = operations.filter(operation => {
    json_string(operation, "operation_ref", default="") == operation_ref
  })
  match matches {
    [operation] => Some(operation)
    _ => None
  }
}

///|
fn moonflow_catalog_enriched_item(item : Json, catalog : Json?) -> Json {
  let fields : Map[String, Json] = Map([])
  match item {
    Object(values) =>
      for key, value in values {
        fields[key] = value
      }
    _ => return item
  }
  let operation = match catalog {
    Some(value) =>
      moonflow_catalog_operation(
        value,
        json_string(item, "operation", default=""),
      )
    None => None
  }
  fields["adapter_id"] = match operation {
    Some(value) => json_string(value, "adapter_id", default="").to_json()
    None => "".to_json()
  }
  fields["claim_ceiling"] = match operation {
    Some(value) => json_string(value, "claim_ceiling", default="").to_json()
    None => "".to_json()
  }
  fields["review_required"] = match operation {
    Some(value) => json_bool(value, "review_required", default=false).to_json()
    None => false.to_json()
  }
  fields["health_checked_at"] = match operation {
    Some(value) => json_string(value, "health_checked_at", default="").to_json()
    None => "".to_json()
  }
  fields["health_valid_until"] = match operation {
    Some(value) =>
      json_string(value, "health_valid_until", default="").to_json()
    None => "".to_json()
  }
  fields["health_evidence_ref"] = match operation {
    Some(value) =>
      json_string(value, "health_evidence_ref", default="").to_json()
    None => "".to_json()
  }
  fields["health_evidence_digest"] = match operation {
    Some(value) =>
      json_string(value, "health_evidence_digest", default="").to_json()
    None => "".to_json()
  }
  Json::object(fields)
}

///|
fn moonflow_catalog_enriched_items(
  graph : Json,
  catalog : Json?,
) -> Array[Json] {
  moonflow_graph_items(graph).map(item => {
    moonflow_catalog_enriched_item(item, catalog)
  })
}
