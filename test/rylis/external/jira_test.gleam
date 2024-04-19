import gleeunit/should
import rylis/external
import rylis/external/jira

pub fn parse_merge_request_from_url_test() {
  "https://gitlab.something.com/branka/be/notification/notification-exponea-client/-/merge_requests/46"
  |> jira.parse_merge_request_from_url
  |> should.equal(
    external.MergeRequest(
      base_url: "https://gitlab.something.com",
      project: "branka/be/notification/notification-exponea-client",
      id: "46",
    )
    |> Ok,
  )
}
