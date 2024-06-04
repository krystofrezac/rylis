import gleeunit/should
import rylis/external/gitlab
import rylis/external/jira
import rylis/min_tags/tags_resolver_service

pub fn ticket_url_to_ticket_text() {
  "https://projektpb.atlassian.net/browse/KLS-1392"
  |> tags_resolver_service.ticket_url_to_ticket
  |> should.equal(
    jira.Ticket(base_url: "https://projektpb.atlassian.net", key: "KLS-1392")
    |> Ok,
  )

  "https://projektpb.atlassian.net/KLS-1392"
  |> tags_resolver_service.ticket_url_to_ticket
  |> should.equal(Error(Nil))
}

pub fn parse_merge_request_from_url_test() {
  "https://gitlab.something.com/branka/be/notification/notification-exponea-client/-/merge_requests/46"
  |> tags_resolver_service.parse_merge_request_from_url
  |> should.equal(
    gitlab.MergeRequest(
      base_url: "https://gitlab.something.com",
      project: "branka/be/notification/notification-exponea-client",
      id: "46",
    )
    |> Ok,
  )
}
