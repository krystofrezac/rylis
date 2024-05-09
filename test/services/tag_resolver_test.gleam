import gleam/order
import gleeunit/should
import rylis/external
import rylis/services/tag_resolver

pub fn get_merge_requests_min_tags_for_tickets_test() {
  tag_resolver.get_merge_requests_min_tags_for_tickets(
    ticket_urls: ["https://jira.com/browse/AAA-111"],
    get_sub_tickets: fn(_ticket) {
      [external.TicketWithId(base_url: "", id: "", key: "")]
      |> Ok
    },
    get_ticket_merge_requests: fn(_ticket) {
      [external.MergeRequest(base_url: "", project: "", id: "")]
      |> Ok
    },
    get_tags_where_merge_request: fn(_merge_request) {
      external.MergeRequestMerged(["1.2.3", "1.2.4"])
      |> Ok
    },
  )
  |> should.equal(
    [
      tag_resolver.MergeRequestWithTicketData(
        merge_request: external.MergeRequest(base_url: "", project: "", id: ""),
        ticket: external.TicketWithId(base_url: "", key: "", id: ""),
        data: external.MergeRequestMerged(
          Ok(tag_resolver.SemanticVersion(1, 2, 3)),
        ),
      ),
    ]
    |> Ok,
  )
}

pub fn get_min_tags_by_repository() {
  let unique_repositories_input = [
    // project a
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "a", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestMerged(
        Ok(tag_resolver.SemanticVersion(1, 2, 0)),
      ),
    ),
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "a", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestMerged(
        Ok(tag_resolver.SemanticVersion(2, 3, 2)),
      ),
    ),
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "a", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestMerged(
        Ok(tag_resolver.SemanticVersion(1, 1, 9210)),
      ),
    ),
    // project b
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestMerged(
        Ok(tag_resolver.SemanticVersion(5, 5, 5)),
      ),
    ),
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestMerged(
        Ok(tag_resolver.SemanticVersion(123, 345, 234)),
      ),
    ),
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestMerged(
        Ok(tag_resolver.SemanticVersion(234, 123, 345)),
      ),
    ),
    // project c
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestOpened(Nil),
    ),
    tag_resolver.MergeRequestWithTicketData(
      merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
      ticket: external.TicketWithId(base_url: "", key: "", id: ""),
      data: external.MergeRequestMerged(Error(Nil)),
    ),
  ]

  unique_repositories_input
  |> tag_resolver.get_min_tags_by_repository
  |> should.equal([
    tag_resolver.RepositoryData(
      base_url: "base",
      project: "a",
      data: tag_resolver.SemanticVersion(1, 1, 9210),
    ),
    tag_resolver.RepositoryData(
      base_url: "base",
      project: "b",
      data: tag_resolver.SemanticVersion(5, 5, 5),
    ),
  ])
}

pub fn ticket_url_to_get_params_test() {
  "https://projektpb.atlassian.net/browse/KLS-1392"
  |> tag_resolver.ticket_url_to_ticket
  |> should.equal(
    external.Ticket(
      base_url: "https://projektpb.atlassian.net",
      key: "KLS-1392",
    )
    |> Ok,
  )

  "https://projektpb.atlassian.net/KLS-1392"
  |> tag_resolver.ticket_url_to_ticket
  |> should.equal(Error(Nil))
}

pub fn get_lowest_semantic_version_test() {
  [
    tag_resolver.SemanticVersion(1, 1, 1),
    tag_resolver.SemanticVersion(1, 0, 0),
    tag_resolver.SemanticVersion(1, 0, 1),
    tag_resolver.SemanticVersion(1, 0, 0),
    tag_resolver.SemanticVersion(2, 3, 4),
  ]
  |> tag_resolver.get_lowest_semantic_version
  |> should.equal(Ok(tag_resolver.SemanticVersion(1, 0, 0)))

  [
    tag_resolver.SemanticVersion(1, 2, 0),
    tag_resolver.SemanticVersion(2, 3, 2),
    tag_resolver.SemanticVersion(1, 1, 9210),
  ]
  |> tag_resolver.get_lowest_semantic_version
  |> should.equal(Ok(tag_resolver.SemanticVersion(1, 1, 9210)))

  []
  |> tag_resolver.get_lowest_semantic_version
  |> should.equal(Error(Nil))
}

pub fn get_highest_semantic_version_test() {
  [
    tag_resolver.SemanticVersion(1, 1, 1),
    tag_resolver.SemanticVersion(1, 0, 0),
    tag_resolver.SemanticVersion(1, 0, 1),
    tag_resolver.SemanticVersion(2, 3, 4),
  ]
  |> tag_resolver.get_highest_semantic_version
  |> should.equal(Ok(tag_resolver.SemanticVersion(2, 3, 4)))

  []
  |> tag_resolver.get_highest_semantic_version
  |> should.equal(Error(Nil))
}

pub fn compare_semantic_versions_test() {
  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(1, 2, 3),
    tag_resolver.SemanticVersion(2, 2, 3),
  )
  |> should.equal(order.Lt)

  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(1, 2, 3),
    tag_resolver.SemanticVersion(1, 3, 3),
  )
  |> should.equal(order.Lt)

  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(1, 2, 3),
    tag_resolver.SemanticVersion(1, 2, 4),
  )
  |> should.equal(order.Lt)

  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(1, 2, 3),
    tag_resolver.SemanticVersion(1, 2, 3),
  )
  |> should.equal(order.Eq)

  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(2, 2, 3),
    tag_resolver.SemanticVersion(1, 2, 3),
  )
  |> should.equal(order.Gt)

  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(1, 3, 3),
    tag_resolver.SemanticVersion(1, 2, 3),
  )
  |> should.equal(order.Gt)

  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(1, 2, 4),
    tag_resolver.SemanticVersion(1, 2, 3),
  )
  |> should.equal(order.Gt)

  tag_resolver.compare_semantic_versions(
    tag_resolver.SemanticVersion(1, 2, 0),
    tag_resolver.SemanticVersion(1, 1, 9210),
  )
  |> should.equal(order.Gt)
}

pub fn decode_semantic_version_test() {
  "1.2.3"
  |> tag_resolver.decode_semantic_version
  |> should.equal(
    tag_resolver.SemanticVersion(1, 2, 3)
    |> Ok,
  )

  "1.2.3-f1"
  |> tag_resolver.decode_semantic_version
  |> should.equal(Error(Nil))

  "invalid"
  |> tag_resolver.decode_semantic_version
  |> should.equal(Error(Nil))
}
