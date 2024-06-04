import gleam/bool
import gleam/dynamic
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/uri
import rylis/pagination

pub type Error {
  NotFoundError
  UnathorizedError
  InvalidResponseError
}

pub type MergeRequest {
  MergeRequest(base_url: String, project: String, id: String)
}

pub type MergeRequestMergeSha {
  MergedMergeRequestMergeSha(String)
  OpenedMergeRequestMergeSha
  ClosedMergeRequestMergeSha
}

pub type MergeRequestMergeShaResult =
  Result(MergeRequestMergeSha, Error)

pub type TagsWhereCommitPresentResult =
  Result(List(String), Error)

pub fn get_merge_request_merge_sha(
  merge_request merge_request: MergeRequest,
  token token: String,
) -> MergeRequestMergeShaResult {
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
    |> result.replace_error(NotFoundError),
  )

  use res <- result.try(
    req
    |> httpc.send
    |> result.replace_error(InvalidResponseError),
  )

  use <- bool.guard(when: res.status == 401, return: Error(UnathorizedError))
  use <- bool.guard(when: res.status == 404, return: Error(NotFoundError))
  use <- bool.guard(
    when: res.status != 200,
    return: Error(InvalidResponseError),
  )

  let state_decoder = dynamic.field("state", dynamic.string)
  use state <- result.try(
    json.decode(from: res.body, using: state_decoder)
    |> result.replace_error(InvalidResponseError),
  )

  case state {
    "opened" ->
      OpenedMergeRequestMergeSha
      |> Ok
    "merged" -> {
      let sha_decoder =
        dynamic.any([
          dynamic.field("merge_commit_sha", dynamic.string),
          dynamic.field("squash_commit_sha", dynamic.string),
          dynamic.field("sha", dynamic.string),
        ])

      json.decode(from: res.body, using: sha_decoder)
      |> result.map(MergedMergeRequestMergeSha)
      |> result.replace_error(InvalidResponseError)
    }
    _ ->
      ClosedMergeRequestMergeSha
      |> Ok
  }
}

pub fn get_tags_where_commit_present(
  sha sha: String,
  base_url base_url: String,
  project project: String,
  token token: String,
) -> TagsWhereCommitPresentResult {
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
) -> Result(pagination.PaginatedResponse(String), Error) {
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
    |> result.replace_error(NotFoundError),
  )

  use res <- result.try(
    req
    |> httpc.send
    |> result.replace_error(InvalidResponseError),
  )

  use <- bool.guard(when: res.status == 404, return: Error(NotFoundError))
  use <- bool.guard(when: res.status == 401, return: Error(UnathorizedError))
  use <- bool.guard(
    when: res.status != 200,
    return: Error(InvalidResponseError),
  )

  let decoder = dynamic.list(dynamic.field("name", dynamic.string))
  use decoded <- result.try(
    json.decode(from: res.body, using: decoder)
    |> result.replace_error(InvalidResponseError),
  )

  use total_pages <- result.try({
    use total_pages_string <- result.try(
      res.headers
      |> list.key_find("x-total-pages")
      |> result.replace_error(InvalidResponseError),
    )

    total_pages_string
    |> int.parse()
    |> result.replace_error(InvalidResponseError)
  })

  pagination.PaginatedResponse(data: decoded, total_pages: total_pages)
  |> Ok
}

fn get_authorization(token) {
  "Bearer " <> token
}
