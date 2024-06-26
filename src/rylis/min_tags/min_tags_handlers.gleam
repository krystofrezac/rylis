import gleam/dynamic
import gleam/list
import gleam/result
import gleam/string
import nakai
import rylis/external/gitlab
import rylis/external/jira
import rylis/helpers
import rylis/min_tags/lowest_tags_service
import rylis/min_tags/min_tags_templates
import rylis/min_tags/tags_resolver_service
import rylis/web
import wisp

pub fn home_handler(req: wisp.Request) {
  let content = {
    let is_logged_in =
      web.get_auth(req)
      |> result.is_ok

    case is_logged_in {
      True -> min_tags_templates.render_logged_in_content()
      False -> min_tags_templates.render_login_form()
    }
  }

  let html =
    min_tags_templates.render_root(content)
    |> nakai.to_string_builder

  wisp.ok()
  |> wisp.html_body(html)
}

pub fn login_handler(req: wisp.Request) {
  use dynamic_body <- wisp.require_json(req)

  let maybe_body =
    dynamic.decode3(
      web.Auth,
      dynamic.field("jira_email", dynamic.string),
      dynamic.field("jira_token", dynamic.string),
      dynamic.field("gitlab_token", dynamic.string),
    )(dynamic_body)

  case maybe_body {
    Error(decode_err) -> {
      helpers.decode_errors_to_json(decode_err)
      |> wisp.json_response(400)
    }
    Ok(body) -> {
      let html =
        min_tags_templates.render_logged_in_content()
        |> nakai.to_string_builder

      wisp.ok()
      |> web.save_auth(req, _, body)
      |> wisp.html_body(html)
    }
  }
}

pub fn logout_handler(req: wisp.Request) {
  let html =
    min_tags_templates.render_login_form()
    |> nakai.to_string_builder

  wisp.ok()
  |> web.remove_auth(req, _)
  |> wisp.html_body(html)
}

pub fn resolve_tags_for_tickets_handler(req: wisp.Request) {
  use auth <- web.require_auth(req)
  use dynamic_body <- wisp.require_json(req)

  let maybe_ticket_urls_raw =
    dynamic.field("tickets", dynamic.string)(dynamic_body)

  case maybe_ticket_urls_raw {
    Error(decode_err) -> {
      helpers.decode_errors_to_json(decode_err)
      |> wisp.json_response(400)
    }
    Ok(ticket_urls_raw) -> {
      let tickets_urls =
        string.split(ticket_urls_raw, on: "\n")
        |> list.map(string.trim)
        |> list.filter(fn(row) { row != "" })

      let resolve_result =
        tags_resolver_service.resolve(
          tickets_urls: tickets_urls,
          get_sub_tickets: fn(ticket) {
            jira.get_ticket_and_sub_tickets_with_id(
              ticket: ticket,
              email: auth.jira_email,
              token: auth.jira_token,
            )
          },
          get_ticket_merge_requests_urls: fn(ticket) {
            jira.get_ticket_merge_requests(
              ticket: ticket,
              email: auth.jira_email,
              token: auth.jira_token,
            )
          },
          get_merge_request_merge_sha: fn(merge_request) {
            gitlab.get_merge_request_merge_sha(
              merge_request: merge_request,
              token: auth.gitlab_token,
            )
          },
          get_tags_where_commit_present: fn(params) {
            gitlab.get_tags_where_commit_present(
              sha: params.sha,
              base_url: params.base_url,
              project: params.project,
              token: auth.gitlab_token,
            )
          },
        )

      let lowest_tags_by_repository =
        lowest_tags_service.get_lowest_by_repository(resolve_result)

      let content =
        min_tags_templates.render_min_tags_result(
          resolve_result,
          lowest_tags_by_repository,
        )
      let html = nakai.to_string_builder(content)

      wisp.ok()
      |> wisp.html_body(html)
    }
  }
}
