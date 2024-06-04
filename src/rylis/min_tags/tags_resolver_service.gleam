import gleam/list
import gleam/otp/task
import gleam/regex
import gleam/result
import rylis/external/gitlab
import rylis/external/jira
import rylis/semver

// PARAMS

pub type GetSubTickets =
  fn(jira.Ticket) -> jira.SubTicketsResult

pub type GetTicketMergeRequestsUrls =
  fn(jira.TicketWithId) -> jira.TicketMergeRequestsResult

pub type GetMergeRequestMergeSha =
  fn(gitlab.MergeRequest) -> gitlab.MergeRequestMergeShaResult

pub type GetTagsWhereCommitPresentParams {
  GetTagsWhereCommitPresentParams(
    sha: String,
    base_url: String,
    project: String,
  )
}

pub type GetTagsWhereCommitPresent =
  fn(GetTagsWhereCommitPresentParams) -> gitlab.TagsWhereCommitPresentResult

// RETURN

pub type MergeShaError {
  MergeShaNotFoundError
  MergeShaUnathorizedError
  MergeShaGitlabError
  MergeShaNoSemverTagError
}

pub type MergeSha {
  MergeSha(sha: String, lowest_tag: Result(semver.Semver, MergeShaError))
}

pub type ParsedMergeRequestError {
  ParsedMergeRequestNotFoundError
  ParsedMergeRequestUnathorizedError
  ParsedMergeRequestGitlabError
  ParsedMergeRequestOpen
  ParsedMergeRequestClosed
}

pub type ParsedMergeRequest {
  ParsedMergeRequest(
    base_url: String,
    project: String,
    id: String,
    result: Result(MergeSha, ParsedMergeRequestError),
  )
}

pub type RawMergeRequestError {
  RawMergeRequestInvalidUrlError
}

pub type RawMergeRequest {
  RawMergeRequest(
    url: String,
    result: Result(ParsedMergeRequest, RawMergeRequestError),
  )
}

pub type SubTicketError {
  SubTicketJiraError
}

pub type SubTicket {
  SubTicket(
    base_url: String,
    key: String,
    result: Result(List(RawMergeRequest), SubTicketError),
  )
}

pub type TicketError {
  TicketNotFoundError
  TicketJiraError
}

pub type Ticket {
  Ticket(
    base_url: String,
    key: String,
    result: Result(List(SubTicket), TicketError),
  )
}

pub type TicketUrlError {
  InvalidTicketUrlError
}

pub type TicketUrl {
  TicketUrl(url: String, result: Result(Ticket, TicketUrlError))
}

pub type ResolveResult =
  List(TicketUrl)

const task_timeout = 60_000

pub fn resolve(
  tickets_urls ticket_urls: List(String),
  get_sub_tickets get_sub_tickets: GetSubTickets,
  get_ticket_merge_requests_urls get_ticket_merge_requests_urls: GetTicketMergeRequestsUrls,
  get_merge_request_merge_sha get_merge_request_merge_sha: GetMergeRequestMergeSha,
  get_tags_where_commit_present get_tags_where_commit_present: GetTagsWhereCommitPresent,
) -> ResolveResult {
  ticket_urls
  |> list.map(fn(ticket_url) {
    use <- task.async

    TicketUrl(
      url: ticket_url,
      result: get_ticket_url_result(
        ticket_url,
        get_sub_tickets,
        get_ticket_merge_requests_urls,
        get_merge_request_merge_sha,
        get_tags_where_commit_present,
      ),
    )
  })
  |> list.map(task.await(_, task_timeout))
}

fn get_ticket_url_result(
  ticket_url: String,
  get_sub_tickets: GetSubTickets,
  get_ticket_merge_requests_urls: GetTicketMergeRequestsUrls,
  get_merge_request_merge_sha: GetMergeRequestMergeSha,
  get_tags_where_commit_present: GetTagsWhereCommitPresent,
) -> Result(Ticket, TicketUrlError) {
  use ticket <- result.try(
    ticket_url_to_ticket(ticket_url)
    |> result.replace_error(InvalidTicketUrlError),
  )

  Ticket(
    base_url: ticket.base_url,
    key: ticket.key,
    result: get_ticket_result(
      ticket,
      get_sub_tickets,
      get_ticket_merge_requests_urls,
      get_merge_request_merge_sha,
      get_tags_where_commit_present,
    ),
  )
  |> Ok
}

fn get_ticket_result(
  ticket: jira.Ticket,
  get_sub_tickets: GetSubTickets,
  get_ticket_merge_requests_urls: GetTicketMergeRequestsUrls,
  get_merge_request_merge_sha: GetMergeRequestMergeSha,
  get_tags_where_commit_present: GetTagsWhereCommitPresent,
) -> Result(List(SubTicket), TicketError) {
  use sub_tickets <- result.try(
    get_sub_tickets(ticket)
    |> result.map_error(fn(error) {
      case error {
        jira.NotFoundError -> TicketNotFoundError
        jira.InvalidResponseError -> TicketJiraError
      }
    }),
  )

  sub_tickets
  |> list.map(fn(sub_ticket) {
    use <- task.async

    SubTicket(
      base_url: sub_ticket.base_url,
      key: sub_ticket.key,
      result: get_sub_ticket_result(
        sub_ticket,
        get_ticket_merge_requests_urls,
        get_merge_request_merge_sha,
        get_tags_where_commit_present,
      ),
    )
  })
  |> list.map(task.await(_, task_timeout))
  |> Ok
}

fn get_sub_ticket_result(
  sub_ticket: jira.TicketWithId,
  get_ticket_merge_requests_urls: GetTicketMergeRequestsUrls,
  get_merge_request_merge_sha: GetMergeRequestMergeSha,
  get_tags_where_commit_present: GetTagsWhereCommitPresent,
) -> Result(List(RawMergeRequest), SubTicketError) {
  use merge_requests_urls <- result.try(
    get_ticket_merge_requests_urls(sub_ticket)
    |> result.replace_error(SubTicketJiraError),
  )

  merge_requests_urls
  |> list.map(fn(merge_request_url) {
    use <- task.async

    RawMergeRequest(
      url: merge_request_url,
      result: get_raw_merge_request_result(
        merge_request_url,
        get_merge_request_merge_sha,
        get_tags_where_commit_present,
      ),
    )
  })
  |> list.map(task.await(_, task_timeout))
  |> Ok
}

fn get_raw_merge_request_result(
  merge_request_url: String,
  get_merge_request_merge_sha: GetMergeRequestMergeSha,
  get_tags_where_commit_present: GetTagsWhereCommitPresent,
) -> Result(ParsedMergeRequest, RawMergeRequestError) {
  use merge_request <- result.try(
    parse_merge_request_from_url(merge_request_url)
    |> result.replace_error(RawMergeRequestInvalidUrlError),
  )

  ParsedMergeRequest(
    base_url: merge_request.base_url,
    project: merge_request.project,
    id: merge_request.id,
    result: get_parsed_merge_request_result(
      merge_request,
      get_merge_request_merge_sha,
      get_tags_where_commit_present,
    ),
  )
  |> Ok
}

fn get_parsed_merge_request_result(
  merge_request: gitlab.MergeRequest,
  get_merge_request_merge_sha: GetMergeRequestMergeSha,
  get_tags_where_commit_present: GetTagsWhereCommitPresent,
) -> Result(MergeSha, ParsedMergeRequestError) {
  use merge_sha <- result.try(
    get_merge_request_merge_sha(gitlab.MergeRequest(
      base_url: merge_request.base_url,
      project: merge_request.project,
      id: merge_request.id,
    ))
    |> result.map_error(fn(error) {
      case error {
        gitlab.NotFoundError -> ParsedMergeRequestNotFoundError
        gitlab.UnathorizedError -> ParsedMergeRequestUnathorizedError
        gitlab.InvalidResponseError -> ParsedMergeRequestGitlabError
      }
    }),
  )

  case merge_sha {
    gitlab.OpenedMergeRequestMergeSha -> ParsedMergeRequestOpen |> Error
    gitlab.ClosedMergeRequestMergeSha -> ParsedMergeRequestClosed |> Error
    gitlab.MergedMergeRequestMergeSha(sha) -> {
      MergeSha(
        sha: sha,
        lowest_tag: get_merge_sha_lowest_tag(
          merge_request,
          sha,
          get_tags_where_commit_present,
        ),
      )
      |> Ok
    }
  }
}

fn get_merge_sha_lowest_tag(
  merge_request: gitlab.MergeRequest,
  sha: String,
  get_tags_where_commit_present: GetTagsWhereCommitPresent,
) -> Result(semver.Semver, MergeShaError) {
  use tags <- result.try(
    get_tags_where_commit_present(GetTagsWhereCommitPresentParams(
      sha: sha,
      base_url: merge_request.base_url,
      project: merge_request.project,
    ))
    |> result.map_error(fn(error) {
      case error {
        gitlab.NotFoundError -> MergeShaNotFoundError
        gitlab.UnathorizedError -> MergeShaUnathorizedError
        gitlab.InvalidResponseError -> MergeShaGitlabError
      }
    }),
  )

  tags
  |> list.filter_map(semver.parse)
  |> semver.get_lowest
  |> result.replace_error(MergeShaNoSemverTagError)
}

pub fn ticket_url_to_ticket(url: String) -> Result(jira.Ticket, Nil) {
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

  jira.Ticket(base_url: base_url, key: key)
}

pub fn parse_merge_request_from_url(
  url: String,
) -> Result(gitlab.MergeRequest, Nil) {
  let regex_options = regex.Options(case_insensitive: True, multi_line: False)
  let assert Ok(base_url_regex) = regex.compile("^.*\\.[^\\/]*", regex_options)
  let assert Ok(project_regex) =
    regex.compile("(?<=[^:\\/]\\/).*(?=\\/-)", regex_options)
  let assert Ok(id_regex) =
    regex.compile("(?<=merge_requests\\/).*$", regex_options)

  use regex.Match(content: base_url, ..) <- result.try(
    regex.scan(content: url, with: base_url_regex)
    |> list.first,
  )
  use regex.Match(content: project, ..) <- result.try(
    regex.scan(content: url, with: project_regex)
    |> list.first,
  )
  use regex.Match(content: id, ..) <- result.map(
    regex.scan(content: url, with: id_regex)
    |> list.first,
  )

  gitlab.MergeRequest(base_url: base_url, project: project, id: id)
}
