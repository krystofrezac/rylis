import gleam/dynamic
import gleam/http
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import nakai
import nakai/attr
import nakai/html
import rylis/external/gitlab
import rylis/external/jira
import rylis/helpers
import rylis/services/tag_resolver
import rylis/web
import rylis/web/components
import wisp

pub fn handle_request(req: wisp.Request, ctx: web.Context) {
  use req <- web.middleware(req, ctx)

  case req.method, wisp.path_segments(req) {
    http.Get, [] -> home_handler(req)
    http.Post, ["login"] -> login_handler(req)
    http.Post, ["logout"] -> logout_handler(req)
    http.Post, ["resolve-tags-for-issues"] ->
      resolve_tags_for_tasks_handler(req)
    _, _ -> wisp.not_found()
  }
}

fn home_handler(req: wisp.Request) {
  let content =
    web.get_auth(req)
    |> result.is_ok
    |> get_content()

  let html =
    components.layout([html.div([attr.id("content")], [content])])
    |> nakai.to_string_builder

  wisp.ok()
  |> wisp.html_body(html)
}

fn login_handler(req: wisp.Request) {
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
        get_content(True)
        |> nakai.to_string_builder

      wisp.ok()
      |> web.save_auth(req, _, body)
      |> wisp.html_body(html)
    }
  }
}

fn logout_handler(req: wisp.Request) {
  let html =
    get_content(False)
    |> nakai.to_string_builder

  wisp.ok()
  |> web.remove_auth(req, _)
  |> wisp.html_body(html)
}

fn resolve_tags_for_tasks_handler(req: wisp.Request) {
  use auth <- web.require_auth(req)
  use dynamic_body <- wisp.require_json(req)

  let maybe_ticket_urls_raw =
    dynamic.field("tasks", dynamic.string)(dynamic_body)

  case maybe_ticket_urls_raw {
    Error(decode_err) -> {
      helpers.decode_errors_to_json(decode_err)
      |> wisp.json_response(400)
    }
    Ok(ticket_urls_raw) -> {
      let ticket_urls =
        string.split(ticket_urls_raw, on: "\n")
        |> list.map(string.trim)
        |> list.filter(fn(row) { row != "" })

      let min_tags_result =
        tag_resolver.get_min_tags_for_tickets(
          ticket_urls: ticket_urls,
          get_ticket_merge_requests: fn(ticket) {
            jira.get_ticket_merge_requests(
              ticket: ticket,
              email: auth.jira_email,
              token: auth.jira_token,
            )
          },
          get_tags_where_merge_request: fn(merge_request) {
            gitlab.get_tags_where_merge_request(
              merge_request: merge_request,
              token: auth.gitlab_token,
            )
          },
        )

      let content = case min_tags_result {
        Error(err) -> components.error_alert("Error occured", err)
        Ok(min_tags) -> {
          let mapped_repositories =
            list.map(min_tags, fn(repository) {
              html.p_text(
                [],
                repository.project
                  <> ": "
                  <> format_semantic_version(repository.data),
              )
            })
          html.div([], [html.p_text([], "Min versions:"), ..mapped_repositories])
        }
      }
      let html = nakai.to_string_builder(content)

      wisp.ok()
      |> wisp.html_body(html)
    }
  }
}

fn format_semantic_version(version: tag_resolver.SemanticVersion) {
  int.to_string(version.major)
  <> "."
  <> int.to_string(version.minor)
  <> "."
  <> int.to_string(version.patch)
}

fn get_content(logged_in: Bool) {
  case logged_in {
    False ->
      html.div([attr.class("mt-8 flex justify-center")], [
        html.div([attr.class("max-w-sm")], [
          components.h2_text(
            [attr.class("text-center font-medium")],
            "Fill in credentials first",
          ),
          html.p_text(
            [attr.class("mb-4 text-center")],
            "Don't worry, all of the information is stored only in your browser using secured cookies.",
          ),
          html.form(
            [
              attr.Attr("hx-post", "/login"),
              attr.Attr("hx-target", "#content"),
              attr.Attr("hx-ext", "json-enc"),
            ],
            [
              html.div([attr.class("flex flex-col gap-2")], [
                components.field(
                  "Jira email",
                  components.input([
                    attr.name("jira_email"),
                    attr.required("true"),
                    attr.type_("email"),
                  ]),
                ),
                components.field(
                  "Jira token",
                  components.input([
                    attr.name("jira_token"),
                    attr.required("true"),
                    attr.type_("password"),
                  ]),
                ),
                components.field(
                  "Gitlab token",
                  components.input([
                    attr.name("gitlab_token"),
                    attr.required("true"),
                    attr.type_("password"),
                  ]),
                ),
                html.p([], [
                  components.link(
                    [
                      attr.href(
                        "https://id.atlassian.com/manage-profile/security/api-tokens",
                      ),
                      attr.target("_blank"),
                    ],
                    [html.Text("Get jira token")],
                  ),
                ]),
                html.p([], [
                  html.Text("Get gitlab token at"),
                  components.code_text(
                    [],
                    "<your-gitlab-url>/-/user_settings/personal_access_tokens",
                  ),
                  html.Text(" (read_api scope is enough)"),
                ]),
                components.button_text([attr.class("w-full")], "Log in"),
              ]),
            ],
          ),
        ]),
      ])
    True ->
      html.Fragment([
        html.div([attr.class("flex items-center")], [
          html.Text("You are logged in"),
          components.button_text(
            [
              attr.class("ml-2"),
              attr.Attr("hx-post", "/logout"),
              attr.Attr("hx-target", "#content"),
            ],
            "Log out",
          ),
        ]),
        html.div([attr.id("form-or-result"), attr.class("mt-4")], [
          html.form(
            [
              attr.Attr("hx-post", "/resolve-tags-for-issues"),
              attr.Attr("hx-target", "#form-or-result"),
              attr.Attr("hx-ext", "json-enc"),
            ],
            [
              html.div([attr.class("flex min-h-80")], [
                components.textarea(
                  [
                    attr.class("grow"),
                    attr.name("tasks"),
                    attr.placeholder(
                      "Jira issue urls. Put each issue on separate line",
                    ),
                  ],
                  [],
                ),
              ]),
              html.div([attr.class("mt-2 flex justify-end")], [
                components.button_text([], "Find tags"),
              ]),
            ],
          ),
        ]),
      ])
  }
}
