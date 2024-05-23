// import gleam/order
// import gleeunit/should
// import rylis/external
// import rylis/min_tags/min_tags_service

// pub fn get_merge_requests_min_tags_for_tickets_test() {
//   min_tags_service.get_merge_requests_min_tags_for_tickets(
//     ticket_urls: ["https://jira.com/browse/AAA-111"],
//     get_sub_tickets: fn(_ticket) {
//       [external.TicketWithId(base_url: "", id: "", key: "")]
//       |> Ok
//     },
//     get_ticket_merge_requests: fn(_ticket) {
//       [external.MergeRequest(base_url: "", project: "", id: "")]
//       |> Ok
//     },
//     get_tags_where_merge_request: fn(_merge_request) {
//       external.MergeRequestMerged(["1.2.3", "1.2.4"])
//       |> Ok
//     },
//   )
//   |> should.equal(
//     [
//       min_tags_service.MergeRequestWithTicketData(
//         merge_request: external.MergeRequest(base_url: "", project: "", id: ""),
//         ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//         data: external.MergeRequestMerged(
//           Ok(min_tags_service.SemanticVersion(1, 2, 3)),
//         ),
//       ),
//     ]
//     |> Ok,
//   )
// }

// pub fn get_min_tags_by_repository() {
//   let unique_repositories_input = [
//     // project a
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "a", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestMerged(
//         Ok(min_tags_service.SemanticVersion(1, 2, 0)),
//       ),
//     ),
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "a", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestMerged(
//         Ok(min_tags_service.SemanticVersion(2, 3, 2)),
//       ),
//     ),
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "a", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestMerged(
//         Ok(min_tags_service.SemanticVersion(1, 1, 9210)),
//       ),
//     ),
//     // project b
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestMerged(
//         Ok(min_tags_service.SemanticVersion(5, 5, 5)),
//       ),
//     ),
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestMerged(
//         Ok(min_tags_service.SemanticVersion(123, 345, 234)),
//       ),
//     ),
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestMerged(
//         Ok(min_tags_service.SemanticVersion(234, 123, 345)),
//       ),
//     ),
//     // project c
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestOpened(Nil),
//     ),
//     min_tags_service.MergeRequestWithTicketData(
//       merge_request: external.MergeRequest(base_url: "a", project: "b", id: ""),
//       ticket: external.TicketWithId(base_url: "", key: "", id: ""),
//       data: external.MergeRequestMerged(Error(Nil)),
//     ),
//   ]

//   unique_repositories_input
//   |> min_tags_service.get_min_tags_by_repository
//   |> should.equal([
//     min_tags_service.RepositoryData(
//       base_url: "base",
//       project: "a",
//       data: min_tags_service.SemanticVersion(1, 1, 9210),
//     ),
//     min_tags_service.RepositoryData(
//       base_url: "base",
//       project: "b",
//       data: min_tags_service.SemanticVersion(5, 5, 5),
//     ),
//   ])
// }

// pub fn ticket_url_to_get_params_test() {
//   "https://projektpb.atlassian.net/browse/KLS-1392"
//   |> min_tags_service.ticket_url_to_ticket
//   |> should.equal(
//     external.Ticket(
//       base_url: "https://projektpb.atlassian.net",
//       key: "KLS-1392",
//     )
//     |> Ok,
//   )

//   "https://projektpb.atlassian.net/KLS-1392"
//   |> min_tags_service.ticket_url_to_ticket
//   |> should.equal(Error(Nil))
// }

// pub fn get_lowest_semantic_version_test() {
//   [
//     min_tags_service.SemanticVersion(1, 1, 1),
//     min_tags_service.SemanticVersion(1, 0, 0),
//     min_tags_service.SemanticVersion(1, 0, 1),
//     min_tags_service.SemanticVersion(1, 0, 0),
//     min_tags_service.SemanticVersion(2, 3, 4),
//   ]
//   |> min_tags_service.get_lowest_semantic_version
//   |> should.equal(Ok(min_tags_service.SemanticVersion(1, 0, 0)))

//   [
//     min_tags_service.SemanticVersion(1, 2, 0),
//     min_tags_service.SemanticVersion(2, 3, 2),
//     min_tags_service.SemanticVersion(1, 1, 9210),
//   ]
//   |> min_tags_service.get_lowest_semantic_version
//   |> should.equal(Ok(min_tags_service.SemanticVersion(1, 1, 9210)))

//   []
//   |> min_tags_service.get_lowest_semantic_version
//   |> should.equal(Error(Nil))
// }

// pub fn get_highest_semantic_version_test() {
//   [
//     min_tags_service.SemanticVersion(1, 1, 1),
//     min_tags_service.SemanticVersion(1, 0, 0),
//     min_tags_service.SemanticVersion(1, 0, 1),
//     min_tags_service.SemanticVersion(2, 3, 4),
//   ]
//   |> min_tags_service.get_highest_semantic_version
//   |> should.equal(Ok(min_tags_service.SemanticVersion(2, 3, 4)))

//   []
//   |> min_tags_service.get_highest_semantic_version
//   |> should.equal(Error(Nil))
// }

// pub fn compare_semantic_versions_test() {
//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(1, 2, 3),
//     min_tags_service.SemanticVersion(2, 2, 3),
//   )
//   |> should.equal(order.Lt)

//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(1, 2, 3),
//     min_tags_service.SemanticVersion(1, 3, 3),
//   )
//   |> should.equal(order.Lt)

//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(1, 2, 3),
//     min_tags_service.SemanticVersion(1, 2, 4),
//   )
//   |> should.equal(order.Lt)

//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(1, 2, 3),
//     min_tags_service.SemanticVersion(1, 2, 3),
//   )
//   |> should.equal(order.Eq)

//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(2, 2, 3),
//     min_tags_service.SemanticVersion(1, 2, 3),
//   )
//   |> should.equal(order.Gt)

//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(1, 3, 3),
//     min_tags_service.SemanticVersion(1, 2, 3),
//   )
//   |> should.equal(order.Gt)

//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(1, 2, 4),
//     min_tags_service.SemanticVersion(1, 2, 3),
//   )
//   |> should.equal(order.Gt)

//   min_tags_service.compare_semantic_versions(
//     min_tags_service.SemanticVersion(1, 2, 0),
//     min_tags_service.SemanticVersion(1, 1, 9210),
//   )
//   |> should.equal(order.Gt)
// }

// pub fn decode_semantic_version_test() {
//   "1.2.3"
//   |> min_tags_service.decode_semantic_version
//   |> should.equal(
//     min_tags_service.SemanticVersion(1, 2, 3)
//     |> Ok,
//   )

//   "1.2.3-f1"
//   |> min_tags_service.decode_semantic_version
//   |> should.equal(Error(Nil))

//   "invalid"
//   |> min_tags_service.decode_semantic_version
//   |> should.equal(Error(Nil))
// }
