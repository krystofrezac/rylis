import gleam/dict
import gleam/int
import gleam/list
import nakai/attr
import nakai/html
import rylis/components
import rylis/min_tags/tags_resolver_service

// TODO: finish links

pub fn render(resolve_result: tags_resolver_service.ResolveResult) {
  resolve_result
  |> list.map(render_ticket_url)
  |> html.Fragment
}

fn render_ticket_url(ticket_url: tags_resolver_service.TicketUrl) {
  let rendered_ticket = case ticket_url.result {
    Error(tags_resolver_service.InvalidTicketUrlError) ->
      html.span_text([], "Invalid url: " <> ticket_url.url)
    Ok(ticket) -> render_ticket(ticket)
  }

  level(components.link_text([], ticket_url.url), rendered_ticket)
}

fn render_ticket(ticket: tags_resolver_service.Ticket) {
  let rendered_sub_tickets = case ticket.result {
    Error(tags_resolver_service.TicketNotFoundError) ->
      html.span_text([], "Ticket not found")
    Error(tags_resolver_service.TicketJiraError) ->
      html.span_text([], "Jira error")
    Ok(sub_tickets) ->
      list.map(sub_tickets, render_sub_ticket) |> html.div([], _)
  }

  level(components.link_text([], ticket.key), rendered_sub_tickets)
}

fn render_sub_ticket(sub_ticket: tags_resolver_service.SubTicket) {
  let rendered_raw_merge_requests = case sub_ticket.result {
    Error(tags_resolver_service.SubTicketJiraError) ->
      html.span_text([], "Jira error")
    Ok(merge_requests) ->
      list.map(merge_requests, render_raw_merge_request) |> html.div([], _)
  }

  level(components.link_text([], sub_ticket.key), rendered_raw_merge_requests)
}

fn render_raw_merge_request(
  raw_merge_request: tags_resolver_service.RawMergeRequest,
) {
  case raw_merge_request.result {
    Error(tags_resolver_service.RawMergeRequestInvalidUrlError) ->
      level(
        components.link_text([], raw_merge_request.url),
        html.span_text([], "Invalid url"),
      )
    Ok(parsed_merge_request) -> {
      let rendered_merge_sha = case parsed_merge_request.result {
        Error(tags_resolver_service.ParsedMergeRequestNotFoundError) ->
          html.span_text([], "Merge request not found")
        Error(tags_resolver_service.ParsedMergeRequestUnathorizedError) ->
          html.span_text([], "Merge request unauthorized")
        Error(tags_resolver_service.ParsedMergeRequestGitlabError) ->
          html.span_text([], "Gitlab error")
        Error(tags_resolver_service.ParsedMergeRequestOpen) ->
          html.span_text([], "Merge request open")
        Error(tags_resolver_service.ParsedMergeRequestClosed) ->
          html.span_text([], "Merge request closed")
        Ok(merge_sha) -> render_merge_sha(merge_sha)
      }

      level(
        components.link_text([], parsed_merge_request.id),
        rendered_merge_sha,
      )
    }
  }
}

fn render_merge_sha(merge_sha: tags_resolver_service.MergeSha) {
  level(components.link_text([], merge_sha.sha), html.div([], []))
}

fn level(current: html.Node, next: html.Node) {
  html.div([attr.class("flex flex-col")], [
    current,
    html.div([attr.class("pl-4")], [next]),
  ])
}
