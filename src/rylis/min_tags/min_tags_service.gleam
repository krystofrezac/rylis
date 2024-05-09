import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/otp/task
import gleam/regex
import gleam/result
import rylis/external

pub type MergeRequestMinTag =
  external.MergeRequestState(Result(SemanticVersion, Nil), Nil, Nil)

pub type MergeRequestWithTicketData(data) {
  MergeRequestWithTicketData(
    ticket: external.TicketWithId,
    merge_request: external.MergeRequest,
    data: data,
  )
}

pub type SemanticVersion {
  SemanticVersion(major: Int, minor: Int, patch: Int)
}

pub type RepositoryData(data) {
  RepositoryData(base_url: String, project: String, data: data)
}

pub fn get_merge_requests_min_tags_for_tickets(
  ticket_urls ticket_urls: List(String),
  get_sub_tickets get_sub_tickets: fn(external.Ticket) ->
    Result(List(external.TicketWithId), String),
  get_ticket_merge_requests get_ticket_merge_requests: fn(external.TicketWithId) ->
    Result(List(external.MergeRequest), String),
  get_tags_where_merge_request get_tags_where_merge_request: fn(
    external.MergeRequest,
  ) ->
    Result(external.MergeRequestState(List(String), Nil, Nil), String),
) -> Result(List(MergeRequestWithTicketData(MergeRequestMinTag)), String) {
  use tickets <- result.try(
    ticket_urls
    |> list.map(fn(ticket_url) {
      ticket_url
      |> ticket_url_to_ticket()
      |> result.replace_error("Failed to parse url: " <> ticket_url)
    })
    |> result.all,
  )

  use merge_requests_min_tags <- result.try(
    tickets
    |> list.map(fn(ticket) {
      use <- task.async

      use sub_tickets <- result.try(get_sub_tickets(ticket))
      sub_tickets
      |> list.map(fn(sub_ticket) {
        use <- task.async
        use merge_requests <- result.try(get_ticket_merge_requests(sub_ticket))

        merge_requests
        |> list.map(fn(merge_request) {
          use <- task.async
          use merge_request_tags <- result.try(get_tags_where_merge_request(
            merge_request,
          ))

          let merge_request_min_tag = case merge_request_tags {
            external.MergeRequestMerged(tags) ->
              tags
              |> get_min_tag
              |> external.MergeRequestMerged
            external.MergeRequestOpened(Nil) -> external.MergeRequestOpened(Nil)
            external.MergeRequestClosed(Nil) -> external.MergeRequestClosed(Nil)
          }

          MergeRequestWithTicketData(
            ticket: sub_ticket,
            merge_request: merge_request,
            data: merge_request_min_tag,
          )
          |> Ok
        })
        |> list.map(task.await(_, 60_000))
        |> result.all
      })
      |> list.map(task.await(_, 60_000))
      |> result.all
      |> result.map(list.flatten)
    })
    |> list.map(task.await(_, 60_000))
    |> result.all
    |> result.map(list.flatten),
  )

  merge_requests_min_tags
  |> Ok
}

pub fn get_min_tags_by_repository(
  merge_requests_min_tags: List(MergeRequestWithTicketData(MergeRequestMinTag)),
) -> List(RepositoryData(SemanticVersion)) {
  let merged_merge_request_min_tags =
    merge_requests_min_tags
    |> list.filter_map(fn(merge_request_min_tag) {
      case merge_request_min_tag.data {
        external.MergeRequestMerged(min_tag) ->
          MergeRequestWithTicketData(
            merge_request: merge_request_min_tag.merge_request,
            ticket: merge_request_min_tag.ticket,
            data: min_tag,
          )
          |> Ok
        _ -> Error(Nil)
      }
    })

  let grouped_repositories_with_lowest_common_tag =
    merged_merge_request_min_tags
    |> list.group(fn(merge_request) {
      #(
        merge_request.merge_request.project,
        merge_request.merge_request.base_url,
      )
    })
    |> dict.values
    |> list.filter_map(fn(merge_requests_min_tags_for_project) {
      // Assert because of `dict.valuse` - cannot be empty
      let assert Ok(first_merge_request_min_tags) =
        list.first(merge_requests_min_tags_for_project)

      let lowest_tags =
        list.filter_map(merge_requests_min_tags_for_project, fn(repository) {
          repository.data
        })

      // Asserting because the `list.group` ensures it's non-empty -> not Error
      use highest_tag <- result.try(get_highest_semantic_version(lowest_tags))

      RepositoryData(
        base_url: first_merge_request_min_tags.merge_request.base_url,
        project: first_merge_request_min_tags.merge_request.project,
        data: highest_tag,
      )
      |> Ok
    })

  grouped_repositories_with_lowest_common_tag
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

pub fn get_min_tag(tags: List(String)) {
  list.filter_map(tags, decode_semantic_version)
  |> get_lowest_semantic_version
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
