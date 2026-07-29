///|
priv struct PagesSearchState {
  query : String
  status : String
  surface : SurfaceState?
  error : String
  evidence_query : String
  hits : Array[SearchHit]
}

///|
fn pages_search_initial_state() -> PagesSearchState {
  {
    query: "",
    status: "enter a query",
    surface: Some(FirstUseEmpty),
    error: "",
    evidence_query: "",
    hits: [],
  }
}

///|
fn PagesSearchState::with_query(
  self : PagesSearchState,
  query : String,
) -> PagesSearchState {
  {
    query,
    status: "draft",
    surface: Some(FirstUseEmpty),
    error: "",
    evidence_query: "",
    hits: [],
  }
}

///|
fn PagesSearchState::begin_search(self : PagesSearchState) -> PagesSearchState {
  let query = self.query.trim().to_owned()
  if query == "" {
    {
      query: self.query,
      status: "enter a query",
      surface: Some(FirstUseEmpty),
      error: "",
      evidence_query: "",
      hits: [],
    }
  } else {
    let keep_prior_hits = pages_search_can_keep_prior_hits(self, query)
    {
      query: self.query,
      status: "searching",
      surface: Some(Loading),
      error: "",
      evidence_query: self.evidence_query,
      hits: if keep_prior_hits {
        self.hits
      } else {
        []
      },
    }
  }
}

///|
fn PagesSearchState::typed_success(
  self : PagesSearchState,
  response : PagesSearchResponse,
) -> PagesSearchState {
  let can_keep_prior_hits = pages_search_can_keep_prior_hits(
    self,
    response.query,
  )
  let surface = pages_search_response_state(response, can_keep_prior_hits)
  let keep_prior_hits = surface is Some(Stale)
  {
    query: self.query,
    status: match surface {
      None => "\{response.hits.length()} results"
      Some(LegitimateZero) => "0 results"
      Some(state) => pages_search_failure_status(state)
    },
    surface,
    error: if response.ok {
      ""
    } else {
      response.message
    },
    evidence_query: if response.ok || keep_prior_hits {
      response.query
    } else {
      ""
    },
    hits: if response.ok {
      response.hits
    } else if keep_prior_hits {
      self.hits
    } else {
      []
    },
  }
}

///|
fn PagesSearchState::fail(
  self : PagesSearchState,
  error : String,
) -> PagesSearchState {
  let query = self.query.trim().to_owned()
  let can_keep_prior_hits = pages_search_can_keep_prior_hits(self, query)
  let surface = if can_keep_prior_hits { Stale } else { RecoverableError }
  {
    query: self.query,
    status: pages_search_failure_status(surface),
    surface: Some(surface),
    error,
    evidence_query: if can_keep_prior_hits {
      query
    } else {
      ""
    },
    hits: if can_keep_prior_hits {
      self.hits
    } else {
      []
    },
  }
}

///|
fn PagesSearchState::clear_hits(self : PagesSearchState) -> PagesSearchState {
  {
    query: self.query,
    status: self.status,
    surface: self.surface,
    error: self.error,
    evidence_query: self.evidence_query,
    hits: [],
  }
}
