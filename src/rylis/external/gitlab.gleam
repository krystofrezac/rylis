import gleam/bool
import gleam/dynamic
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/uri
import rylis/external
import rylis/pagination

/// Returns list of tags where the changes from MR are present
pub fn get_tags_where_merge_request(
  merge_request merge_request: external.MergeRequest,
  token token: String,
) -> Result(external.MergeRequestState(List(String), Nil, Nil), String) {
  use maybe_sha <- result.try(get_merge_request_merge_sha(merge_request, token))

  case maybe_sha {
    external.MergeRequestMerged(sha) -> {
      use tags <- result.try(get_tags_where_commit_present(
        sha: sha,
        base_url: merge_request.base_url,
        project: merge_request.project,
        token: token,
      ))
      tags
      |> external.MergeRequestMerged
      |> Ok
    }
    external.MergeRequestOpened(Nil) ->
      Nil
      |> external.MergeRequestOpened
      |> Ok
    external.MergeRequestClosed(Nil) ->
      Nil
      |> external.MergeRequestClosed
      |> Ok
  }
}

fn get_merge_request_merge_sha(
  merge_request merge_request: external.MergeRequest,
  token token: String,
) -> Result(external.MergeRequestState(String, Nil, Nil), String) {
  use req <- result.try(
    {
      let encoded_project = uri.percent_encode(merge_request.project)

      use req <- result.map(request.to(
        merge_request.base_url
        <> "/api/v4/projects/"
        <> encoded_project
        <> "/merge_requests/"
        <> merge_request.id,
      ))

      req
      |> request.set_header("Authorization", get_authorization(token))
    }
    |> result.replace_error(
      "Failed to compose gitlab merge request url (something is wrong in Jira)",
    ),
  )

  use res <- result.try(
    req
    |> httpc.send
    |> result.replace_error("httpc error when merge request"),
  )

  use <- bool.guard(
    when: res.status != 200,
    return: Error("Gitlab merge request failed (check token)"),
  )

  let state_decoder = dynamic.field("state", dynamic.string)
  use state <- result.try(
    json.decode(from: res.body, using: state_decoder)
    |> result.replace_error("Failed to decode state from Gitlab merge request"),
  )

  case state {
    "opened" ->
      external.MergeRequestOpened(Nil)
      |> Ok
    "merged" -> {
      let sha_decoder =
        dynamic.any([
          dynamic.field("merge_commit_sha", dynamic.string),
          dynamic.field("squash_commit_sha", dynamic.string),
          dynamic.field("sha", dynamic.string),
        ])

      json.decode(from: res.body, using: sha_decoder)
      |> result.map(external.MergeRequestMerged)
      |> result.replace_error("Gitlab merge response validation failed")
    }
    _ ->
      external.MergeRequestClosed(Nil)
      |> Ok
  }
}

fn get_tags_where_commit_present(
  sha sha: String,
  base_url base_url: String,
  project project: String,
  token token: String,
) -> Result(List(String), String) {
  pagination.get_all_pages(fn(page_number) {
    get_tags_where_commit_present_page(
      page_number: page_number,
      sha: sha,
      base_url: base_url,
      project: project,
      token: token,
    )
  })
}

fn get_tags_where_commit_present_page(
  page_number page_number: Int,
  sha sha: String,
  base_url base_url: String,
  project project: String,
  token token: String,
) {
  use req <- result.try(
    {
      let encoded_project = uri.percent_encode(project)
      use req <- result.map(request.to(
        base_url
        <> "/api/v4/projects/"
        <> encoded_project
        <> "/repository/commits/"
        <> sha
        <> "/refs",
      ))

      req
      |> request.set_header("Authorization", get_authorization(token))
      |> request.set_query([
        #("type", "tag"),
        // 100 is max that Gitlab can handle
        #("per_page", "100"),
        #("page", int.to_string(page_number)),
      ])
    }
    |> result.replace_error("Failed to compose gitlab ref url"),
  )

  use res <- result.try(
    req
    |> httpc.send
    |> result.replace_error("httpc error when gitlab refs"),
  )

  use <- bool.guard(
    when: res.status != 200,
    return: Error("Gitlab refs request failed (check token)"),
  )

  let decoder = dynamic.list(dynamic.field("name", dynamic.string))
  use decoded <- result.try(
    json.decode(from: res.body, using: decoder)
    |> result.replace_error("Gitlab refs response validation failed"),
  )

  use total_pages <- result.try({
    use total_pages_string <- result.try(
      res.headers
      |> list.key_find("x-total-pages")
      |> result.replace_error(
        "Gitlab refs response missing x-total-pages header",
      ),
    )

    total_pages_string
    |> int.parse()
    |> result.replace_error("Gitlab refs response invalid x-total-pages header")
  })

  pagination.PaginatedResponse(data: decoded, total_pages: total_pages)
  |> Ok
}

fn get_authorization(token) {
  "Bearer " <> token
}
