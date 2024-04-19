import gleam/order
import gleeunit/should
import rylis/external
import rylis/services/tag_resolver

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

pub fn get_min_tags_for_merge_requests_with_tags_test() {
  let unique_repositories_input = [
    tag_resolver.RepositoryData(base_url: "base", project: "a", data: [
      "1.2.0", "2.3.2", "1.1.9210",
    ]),
    tag_resolver.RepositoryData(base_url: "base", project: "b", data: [
      "5.5.5", "123.345.234", "234.123.345",
    ]),
  ]
  unique_repositories_input
  |> tag_resolver.get_min_tags_for_merge_requests_with_tags
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

  let non_unique_repositories_input = [
    tag_resolver.RepositoryData(base_url: "base", project: "a", data: [
      "1.2.0", "2.3.2", "1.1.9210",
    ]),
    tag_resolver.RepositoryData(base_url: "base", project: "a", data: [
      "0.2.3", "0.7.8", "1.1.9210",
    ]),
    tag_resolver.RepositoryData(base_url: "base", project: "b", data: [
      "5.5.5", "123.345.234", "234.123.345",
    ]),
    tag_resolver.RepositoryData(base_url: "base", project: "b", data: [
      "123.345.234", "234.123.345", "999.999.999",
    ]),
  ]
  non_unique_repositories_input
  |> tag_resolver.get_min_tags_for_merge_requests_with_tags
  |> should.equal([
    tag_resolver.RepositoryData(
      base_url: "base",
      project: "a",
      data: tag_resolver.SemanticVersion(1, 1, 9210),
    ),
    tag_resolver.RepositoryData(
      base_url: "base",
      project: "b",
      data: tag_resolver.SemanticVersion(123, 345, 234),
    ),
  ])
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
