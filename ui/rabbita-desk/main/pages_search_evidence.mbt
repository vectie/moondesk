///| Pages search accepts only the explicit versioned host contract as evidence

///| for limitation and terminal states. Unknown or malformed responses remain

///|
/// retryable and never become a legitimate empty result.
fn pages_search_response_state(
  response : PagesSearchResponse,
  can_keep_prior_hits : Bool,
) -> SurfaceState? {
  if response.contract != "pages-search.v1" {
    return if can_keep_prior_hits {
      Some(Stale)
    } else {
      Some(RecoverableError)
    }
  }
  if response.ok && response.workspace_id != "" {
    for hit in response.hits {
      if hit.workspace_id != response.workspace_id {
        return if can_keep_prior_hits {
          Some(Stale)
        } else {
          Some(RecoverableError)
        }
      }
    }
  }
  if response.ok {
    return if response.hits.is_empty() { Some(LegitimateZero) } else { None }
  }
  match response.status {
    "scope-unavailable" => Some(CapabilityLimited)
    "workspace-not-found" => Some(TerminalError)
    _ => if can_keep_prior_hits { Some(Stale) } else { Some(RecoverableError) }
  }
}

///|
fn pages_search_can_keep_prior_hits(model : Model, query : String) -> Bool {
  !model.search_hits.is_empty() &&
  model.search_evidence_query != "" &&
  model.search_evidence_query == query
}

///|
fn pages_search_failure_status(state : SurfaceState) -> String {
  match state {
    Stale => "Showing earlier search results"
    CapabilityLimited => "Search is unavailable for this book"
    TerminalError => "The selected book is no longer available"
    _ => "Search couldn’t be completed"
  }
}
