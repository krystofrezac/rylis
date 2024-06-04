import gleam/list
import gleam/string
import nakai/attr
import nakai/html
import rylis/components
import rylis/min_tags/tags_resolver_service
import rylis/semver

pub fn render(resolve_result: tags_resolver_service.ResolveResult) {
  html.div([], [
    components.h2_text([], "Detail"),
    resolve_result
      |> list.map(render_ticket_url)
      |> html.Fragment,
  ])
}

fn render_ticket_url(ticket_url: tags_resolver_service.TicketUrl) {
  case ticket_url.result {
    Error(tags_resolver_service.InvalidTicketUrlError) ->
      level(
        components.link_text(
          [attr.href(ticket_url.url), attr.target("_blank")],
          ticket_url.url,
        ),
        components.error_alert_fit("Invalid url"),
      )
    Ok(ticket) -> {
      let rendered_sub_ticket = case ticket.result {
        Error(tags_resolver_service.TicketNotFoundError) ->
          components.error_alert_fit(
            "Ticket not found or you don't rights to see it (check your Jira token)",
          )
        Error(tags_resolver_service.TicketJiraError) ->
          components.error_alert_fit(
            "Jira error: something unexpected came from Jira",
          )
        Ok(sub_tickets) ->
          list.map(sub_tickets, render_sub_ticket) |> html.div([], _)
      }

      level(
        components.link_text(
          [attr.href(ticket_url.url), attr.target("_blank")],
          ticket.key,
        ),
        rendered_sub_ticket,
      )
    }
  }
}

fn render_sub_ticket(sub_ticket: tags_resolver_service.SubTicket) {
  let rendered_raw_merge_requests = case sub_ticket.result {
    Error(tags_resolver_service.SubTicketJiraError) ->
      components.error_alert_fit(
        "Jira error: something unexpected came from Jira",
      )
    Ok([]) -> html.span_text([], "Not linked with any merge request")
    Ok(merge_requests) ->
      list.map(merge_requests, render_raw_merge_request) |> html.div([], _)
  }

  let href = sub_ticket.base_url <> "/browse/" <> sub_ticket.key
  level(
    components.link_text(
      [attr.href(href), attr.target("_blank")],
      sub_ticket.key,
    ),
    rendered_raw_merge_requests,
  )
}

fn render_raw_merge_request(
  raw_merge_request: tags_resolver_service.RawMergeRequest,
) {
  case raw_merge_request.result {
    Error(tags_resolver_service.RawMergeRequestInvalidUrlError) -> {
      level(
        components.link_text(
          [attr.href(raw_merge_request.url), attr.target("_blank")],
          raw_merge_request.url,
        ),
        components.error_alert_fit("Invalid merge request error"),
      )
    }
    Ok(parsed_merge_request) -> {
      let rendered_merge_sha = case parsed_merge_request.result {
        Error(tags_resolver_service.ParsedMergeRequestNotFoundError) ->
          components.error_alert_fit("Merge request not found")
        Error(tags_resolver_service.ParsedMergeRequestUnathorizedError) ->
          components.error_alert_fit("Unauthorized to access merge request")
        Error(tags_resolver_service.ParsedMergeRequestGitlabError) ->
          components.error_alert_fit(
            "Gitlab error: something unexpected came from Gitlab",
          )
        Error(tags_resolver_service.ParsedMergeRequestOpen) ->
          components.warning_alert_fit("Merge request open")
        Error(tags_resolver_service.ParsedMergeRequestClosed) ->
          components.warning_alert_fit("Merge request closed")
        Ok(merge_sha) -> render_merge_sha(parsed_merge_request, merge_sha)
      }

      let href =
        parsed_merge_request.base_url
        <> "/"
        <> parsed_merge_request.project
        <> "/-/merge_requests/"
        <> parsed_merge_request.id

      level(
        components.link_text(
          [attr.href(href), attr.target("_blank")],
          parsed_merge_request.project <> "!" <> parsed_merge_request.id,
        ),
        rendered_merge_sha,
      )
    }
  }
}

fn render_merge_sha(
  merge_request: tags_resolver_service.ParsedMergeRequest,
  merge_sha: tags_resolver_service.MergeSha,
) {
  let rendered_lowest_tag = case merge_sha.lowest_tag {
    Error(tags_resolver_service.MergeShaNotFoundError) ->
      components.error_alert_fit("Commit not found")
    Error(tags_resolver_service.MergeShaUnathorizedError) ->
      components.error_alert_fit("Unauthorized to access commit")
    Error(tags_resolver_service.MergeShaGitlabError) ->
      components.error_alert_fit(
        "Gitlab error: something unexpected came from Gitlab",
      )
    Error(tags_resolver_service.MergeShaNoSemverTagError) ->
      components.warning_alert_fit("Commit isn't in any valid semver tag")
    Ok(lowest_tag) -> {
      let formatted_tag = semver.format(lowest_tag)
      let href =
        merge_request.base_url
        <> "/"
        <> merge_request.project
        <> "/-/tags/"
        <> formatted_tag

      components.link_text(
        [attr.href(href), attr.target("_blank")],
        formatted_tag,
      )
    }
  }

  let href =
    merge_request.base_url
    <> "/"
    <> merge_request.project
    <> "/-/commit/"
    <> merge_sha.sha

  level(
    components.link_text(
      [attr.href(href), attr.target("_blank")],
      merge_sha.sha |> string.slice(0, 8),
    ),
    rendered_lowest_tag,
  )
}

fn level(current: html.Node, next: html.Node) {
  html.div([attr.class("flex flex-col")], [
    current,
    html.div([attr.class("pl-4 border-l border-gray-200")], [next]),
  ])
}
