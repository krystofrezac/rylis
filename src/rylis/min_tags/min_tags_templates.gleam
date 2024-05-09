import gleam/dict
import gleam/int
import gleam/list
import nakai/attr
import nakai/html
import rylis/components
import rylis/external
import rylis/min_tags/min_tags_service

pub fn render_root(children) {
  components.layout([html.div([attr.id("content")], [children])])
}

pub fn render_login_form() {
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
}

pub fn render_logged_in_content() {
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
    html.div([attr.class("mt-4")], [
      html.form(
        [
          attr.Attr("hx-post", "/resolve-tags-for-tickets"),
          attr.Attr("hx-target", "#result"),
          attr.Attr("hx-ext", "json-enc"),
        ],
        [
          html.div([attr.class("flex min-h-80")], [
            components.textarea(
              [
                attr.class("grow resize-none"),
                attr.name("tickets"),
                attr.placeholder(
                  "Jira issue urls (epics, tasks, sub-tasks, ...). Put each issue on separate line",
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
    html.div([attr.id("result"), attr.class("mt-4")], []),
  ])
}

pub fn render_resolve_errors(error: String) {
  components.error_alert("Error occured", error)
}

pub fn render_resolve_result(
  merge_requests_min_tags: List(
    min_tags_service.MergeRequestWithTicketData(
      min_tags_service.MergeRequestMinTag,
    ),
  ),
  repositories_min_tags: List(
    min_tags_service.RepositoryData(min_tags_service.SemanticVersion),
  ),
) {
  html.div([attr.class("flex flex-col gap-8")], [
    render_repositories_min_tags(repositories_min_tags),
    render_merge_requests_detail(merge_requests_min_tags),
  ])
}

fn render_repositories_min_tags(
  repositories_min_tags: List(
    min_tags_service.RepositoryData(min_tags_service.SemanticVersion),
  ),
) {
  let mapped_repositories =
    repositories_min_tags
    |> list.map(fn(merge_requests_min_tag) {
      let version = format_semantic_version(merge_requests_min_tag.data)

      let repository_url =
        merge_requests_min_tag.base_url <> "/" <> merge_requests_min_tag.project

      let tag_url =
        merge_requests_min_tag.base_url
        <> "/"
        <> merge_requests_min_tag.project
        <> "/-/tags/"
        <> version

      html.Fragment([
        components.link_text(
          [attr.href(repository_url), attr.target("_blank")],
          merge_requests_min_tag.project,
        ),
        components.link_text(
          [attr.href(tag_url), attr.target("_blank")],
          version,
        ),
      ])
    })

  html.div([], [
    components.h2_text([attr.class("mb-2")], "Lowest versions of services"),
    html.div(
      [attr.class("grid gap-4"), attr.style("grid-template-columns: auto 1fr;")],
      mapped_repositories,
    ),
  ])
}

fn render_merge_requests_detail(
  merge_requests_min_tags: List(
    min_tags_service.MergeRequestWithTicketData(
      min_tags_service.MergeRequestMinTag,
    ),
  ),
) {
  let mapped_tickets =
    merge_requests_min_tags
    |> list.group(by: fn(merge_request_min_tag) { merge_request_min_tag.ticket })
    |> dict.values
    |> list.map(fn(merge_requests_min_tags_for_ticket) {
      // assert because of `dict.values` - it cannot be empty
      let assert Ok(first_merge_request_min_tag) =
        list.first(merge_requests_min_tags_for_ticket)

      let ticket_url =
        first_merge_request_min_tag.ticket.base_url
        <> "/browse/"
        <> first_merge_request_min_tag.ticket.key

      let mapped_merge_request =
        merge_requests_min_tags_for_ticket
        |> list.map(fn(merge_request_min_tag) {
          let merge_request_url =
            merge_request_min_tag.merge_request.base_url
            <> "/"
            <> merge_request_min_tag.merge_request.project
            <> "/-/merge_requests/"
            <> merge_request_min_tag.merge_request.id

          let merge_request_text =
            merge_request_min_tag.merge_request.project
            <> "!"
            <> merge_request_min_tag.merge_request.id

          let min_tag_rendered = case merge_request_min_tag.data {
            external.MergeRequestMerged(Ok(min_tag)) -> {
              let min_tag_text = format_semantic_version(min_tag)
              let tag_url =
                merge_request_min_tag.merge_request.base_url
                <> "/"
                <> merge_request_min_tag.merge_request.project
                <> "/-/tags/"
                <> min_tag_text

              components.link_text(
                [attr.href(tag_url), attr.target("_blank")],
                min_tag_text,
              )
            }
            external.MergeRequestMerged(Error(Nil)) ->
              html.Text("not in any tag")
            external.MergeRequestOpened(Nil) -> html.Text("opened")
            external.MergeRequestClosed(Nil) -> html.Text("closed")
          }

          html.Fragment([
            components.link_text(
              [attr.href(merge_request_url), attr.target("_blank")],
              merge_request_text,
            ),
            min_tag_rendered,
          ])
        })

      html.div([attr.class("mb-4")], [
        html.div([attr.class("mb-2")], [
          components.link_text(
            [attr.href(ticket_url), attr.target("_blank")],
            first_merge_request_min_tag.ticket.key,
          ),
        ]),
        html.div(
          [
            attr.class("ml-8 grid gap-4"),
            attr.style("grid-template-columns: auto 1fr;"),
          ],
          mapped_merge_request,
        ),
      ])
    })

  html.div([], [
    components.h2_text([attr.class("mb-2")], "Detail"),
    ..mapped_tickets
  ])
}

fn format_semantic_version(version: min_tags_service.SemanticVersion) {
  int.to_string(version.major)
  <> "."
  <> int.to_string(version.minor)
  <> "."
  <> int.to_string(version.patch)
}
