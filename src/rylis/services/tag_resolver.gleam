import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/otp/task
import gleam/regex
import gleam/result
import rylis/external

pub type RepositoryData(data) {
  RepositoryData(base_url: String, project: String, data: data)
}

pub type SemanticVersion {
  SemanticVersion(major: Int, minor: Int, patch: Int)
}

/// 1. From tickets get merge requests
/// 1. Get tags where changes from merge requests are present
/// 1. Find the **lowest** tags for these merge request (the first tag where released)
/// 1. Group the **lowest** tags by project/repository
/// 1. Pick the **highest** tag from these groups (first tag where all the changes from merge requests are present)
pub fn get_min_tags_for_tickets(
  ticket_urls ticket_urls: List(String),
  get_ticket_merge_requests get_ticket_merge_requests: fn(external.Ticket) ->
    Result(List(external.MergeRequest), String),
  get_tags_where_merge_request get_tags_where_merge_request: fn(
    external.MergeRequest,
  ) ->
    Result(external.MergeRequestState(List(String), Nil, Nil), String),
) {
  use tickets <- result.try(
    ticket_urls
    |> list.map(fn(ticket_url) {
      ticket_url
      |> ticket_url_to_ticket()
      |> result.replace_error("Failed to parse url: " <> ticket_url)
    })
    |> result.all,
  )

  use merge_requests <- result.try(
    tickets
    |> list.map(fn(ticket) {
      use <- task.async
      get_ticket_merge_requests(ticket)
    })
    |> list.map(task.await(_, 60_000))
    |> result.all
    |> result.map(list.flatten),
  )

  use merge_requests_tags <- result.try(
    merge_requests
    |> list.map(fn(merge_request) {
      use <- task.async
      use tags <- result.map(get_tags_where_merge_request(merge_request))

      RepositoryData(
        base_url: merge_request.base_url,
        project: merge_request.project,
        data: tags,
      )
    })
    |> list.map(task.await(_, 60_000))
    |> result.all,
  )

  let merged_merge_requests_with_tags =
    merge_requests_tags
    |> list.filter_map(fn(merge_request_tags) {
      case merge_request_tags {
        RepositoryData(
          data: external.MergeRequestMerged(tags),
          base_url: base_url,
          project: project,
        ) ->
          Ok(RepositoryData(data: tags, base_url: base_url, project: project))
        _ -> Error(Nil)
      }
    })

  get_min_tags_for_merge_requests_with_tags(merged_merge_requests_with_tags)
  |> Ok
}

pub fn ticket_url_to_ticket(url: String) -> Result(external.Ticket, Nil) {
  let assert Ok(base_url_regex) =
    regex.compile(
      "^.*(?=\\/browse)",
      with: regex.Options(case_insensitive: True, multi_line: False),
    )

  let assert Ok(key_regex) =
    regex.compile(
      "(?<=browse\\/).*",
      with: regex.Options(case_insensitive: True, multi_line: False),
    )

  use regex.Match(content: base_url, ..) <- result.try(
    regex.scan(content: url, with: base_url_regex)
    |> list.first,
  )

  use regex.Match(content: key, ..) <- result.map(
    regex.scan(content: url, with: key_regex)
    |> list.first,
  )

  external.Ticket(base_url: base_url, key: key)
}

pub fn get_min_tags_for_merge_requests_with_tags(
  merged_merge_requests_with_tags: List(RepositoryData(List(String))),
) {
  let merged_merge_requests_with_lowest_tag =
    merged_merge_requests_with_tags
    |> list.filter_map(fn(merge_request_with_tags) {
      use lowest_tag <- result.try(
        list.filter_map(merge_request_with_tags.data, decode_semantic_version)
        |> get_lowest_semantic_version,
      )

      RepositoryData(
        base_url: merge_request_with_tags.base_url,
        project: merge_request_with_tags.project,
        data: lowest_tag,
      )
      |> Ok
    })

  let grouped_repositories_with_satisfied_tag =
    merged_merge_requests_with_lowest_tag
    |> list.group(fn(merge_request) {
      RepositoryData(
        base_url: merge_request.base_url,
        project: merge_request.project,
        data: Nil,
      )
    })
    |> dict.to_list
    |> list.map(fn(repository_group) {
      let #(repository, repositories_with_lowest_tags) = repository_group
      let lowest_tags =
        list.map(repositories_with_lowest_tags, fn(repository) {
          repository.data
        })

      // Asserting because the `list.group` ensures it's non-empty -> not Error
      let assert Ok(highest_tag) = get_highest_semantic_version(lowest_tags)

      highest_tag
      |> RepositoryData(
        base_url: repository.base_url,
        project: repository.project,
      )
    })

  grouped_repositories_with_satisfied_tag
}

pub fn get_lowest_semantic_version(versions: List(SemanticVersion)) {
  versions
  |> list.fold(from: Error(Nil), with: fn(maybe_lowest, version) {
    case maybe_lowest, version {
      Error(Nil), version -> Ok(version)
      Ok(lowest), version -> {
        case compare_semantic_versions(lowest, version) {
          order.Lt -> lowest
          _ -> version
        }
        |> Ok
      }
    }
  })
}

pub fn get_highest_semantic_version(versions: List(SemanticVersion)) {
  versions
  |> list.fold(from: Error(Nil), with: fn(maybe_highest, version) {
    case maybe_highest, version {
      Error(Nil), version -> Ok(version)
      Ok(highest), version -> {
        case compare_semantic_versions(highest, version) {
          order.Gt -> highest
          _ -> version
        }
        |> Ok
      }
    }
  })
}

pub fn compare_semantic_versions(a: SemanticVersion, b: SemanticVersion) {
  case a, b {
    SemanticVersion(a_major, ..), SemanticVersion(b_major, ..)
      if a_major < b_major
    -> {
      order.Lt
    }
    SemanticVersion(a_major, ..), SemanticVersion(b_major, ..) if a_major
      > b_major -> {
      order.Gt
    }
    SemanticVersion(minor: a_minor, ..), SemanticVersion(minor: b_minor, ..) if a_minor
      < b_minor -> {
      order.Lt
    }
    SemanticVersion(minor: a_minor, ..), SemanticVersion(minor: b_minor, ..) if a_minor
      > b_minor -> {
      order.Gt
    }
    SemanticVersion(patch: a_patch, ..), SemanticVersion(patch: b_patch, ..) if a_patch
      < b_patch -> {
      order.Lt
    }
    SemanticVersion(patch: a_patch, ..), SemanticVersion(patch: b_patch, ..) if a_patch
      > b_patch -> {
      order.Gt
    }
    _, _ -> order.Eq
  }
}

pub fn decode_semantic_version(value: String) {
  let assert Ok(semantic_regex) =
    regex.compile(
      "^(\\d+)\\.(\\d+)\\.(\\d+)$",
      with: regex.Options(case_insensitive: True, multi_line: False),
    )

  use regex.Match(submatches: submatches, ..) <- result.try(
    regex.scan(content: value, with: semantic_regex)
    |> list.first,
  )

  case submatches {
    [option.Some(major), option.Some(minor), option.Some(patch)] -> {
      // asserting because it's checked in regex
      let assert Ok(major_int) = int.parse(major)
      let assert Ok(minor_int) = int.parse(minor)
      let assert Ok(patch_int) = int.parse(patch)

      SemanticVersion(major: major_int, minor: minor_int, patch: patch_int)
      |> Ok
    }
    _ -> Error(Nil)
  }
}