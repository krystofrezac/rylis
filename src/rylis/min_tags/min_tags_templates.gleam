import gleam/list
import nakai/attr
import nakai/html
import rylis/components
import rylis/min_tags/lowest_tags_service
import rylis/min_tags/resolve_detail_templates
import rylis/min_tags/tags_resolver_service
import rylis/semver

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

pub fn render_min_tags_result(
  resolve_result: tags_resolver_service.ResolveResult,
  lowest_tags_by_repository: List(lowest_tags_service.RepositoryWithTag),
) {
  html.div([attr.class("flex flex-col gap-8")], [
    render_lowest_tags_by_repository(lowest_tags_by_repository),
    resolve_detail_templates.render(resolve_result),
  ])
}

pub fn render_lowest_tags_by_repository(
  lowest_tags_by_repository: List(lowest_tags_service.RepositoryWithTag),
) {
  html.div([], [
    components.h2_text([], "Lowest tags by repository"),
    html.div(
      [attr.class("grid grid-cols-[auto_1fr] gap-x-2")],
      lowest_tags_by_repository
        |> list.map(fn(repository) {
          let repository_href = repository.base_url <> "/" <> repository.name

          let formatted_tag = repository.tag |> semver.format
          let tag_href =
            repository.base_url
            <> "/"
            <> repository.name
            <> "/-/tags/"
            <> formatted_tag

          html.Fragment([
            components.link_text(
              [attr.href(repository_href), attr.target("_blank")],
              repository.name,
            ),
            components.link_text(
              [attr.href(tag_href), attr.target("_blank")],
              formatted_tag,
            ),
          ])
        }),
    ),
  ])
}
