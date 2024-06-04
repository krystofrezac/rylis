import gleam/bit_array
import gleam/bool
import gleam/dynamic
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import rylis/pagination

pub type Error {
  /// Not found or unauthorized
  NotFoundError
  InvalidResponseError
}

pub type Ticket {
  Ticket(base_url: String, key: String)
}

pub type TicketWithId {
  TicketWithId(base_url: String, key: String, id: String)
}

pub type SubTicketsResult =
  Result(List(TicketWithId), Error)

pub type TicketMergeRequestsResult =
  Result(List(String), Error)

pub fn get_ticket_and_sub_tickets_with_id(
  ticket ticket: Ticket,
  email email: String,
  token token: String,
) -> SubTicketsResult {
  pagination.get_all_pages(get_id_and_sub_ids_page(
    page_number: _,
    ticket: ticket,
    email: email,
    token: token,
  ))
}

fn get_id_and_sub_ids_page(
  page_number page_number: Int,
  ticket ticket: Ticket,
  email email: String,
  token token: String,
) -> Result(pagination.PaginatedResponse(TicketWithId), Error) {
  let url = ticket.base_url <> "/rest/api/3/search"
  // 100 is max that Jira can handle
  let page_size = 100

  use req_base <- result.try(
    request.to(url)
    |> result.replace_error(NotFoundError),
  )

  let jql = "parentEpic = " <> ticket.key
  let start_at = { page_number - 1 } * page_size

  use res <- result.try(
    req_base
    |> request.set_header("Authorization", get_auth(email: email, token: token))
    |> request.set_query([
      #("jql", jql),
      #("maxResults", int.to_string(page_size)),
      #("startAt", int.to_string(start_at)),
    ])
    |> httpc.send
    |> result.replace_error(InvalidResponseError),
  )

  use <- bool.guard(when: res.status == 404, return: Error(NotFoundError))
  use <- bool.guard(
    when: res.status != 200,
    return: Error(InvalidResponseError),
  )

  let decoder =
    dynamic.decode2(
      fn(total, tasks) { #(total, tasks) },
      dynamic.field("total", dynamic.int),
      dynamic.field(
        "issues",
        dynamic.list(dynamic.decode2(
          fn(key, id) {
            TicketWithId(base_url: ticket.base_url, key: key, id: id)
          },
          dynamic.field("key", dynamic.string),
          dynamic.field("id", dynamic.string),
        )),
      ),
    )

  use #(total, ticket_ids) <- result.map(
    json.decode(from: res.body, using: decoder)
    |> result.replace_error(InvalidResponseError),
  )

  let total_pages =
    pagination.count_to_pages(count: total, page_size: page_size)
  pagination.PaginatedResponse(data: ticket_ids, total_pages: total_pages)
}

pub fn get_ticket_merge_requests(
  ticket ticket: TicketWithId,
  email email: String,
  token token: String,
) -> TicketMergeRequestsResult {
  use req <- result.try({
    use req <- result.map(
      request.to(ticket.base_url <> "/rest/dev-status/latest/issue/details")
      |> result.replace_error(NotFoundError),
    )

    req
    |> request.set_query([#("issueId", ticket.id)])
    |> request.set_header("Authorization", get_auth(email: email, token: token))
  })

  use res <- result.try(
    req
    |> httpc.send
    |> result.replace_error(InvalidResponseError),
  )

  use <- bool.guard(when: res.status == 404, return: Error(NotFoundError))
  use <- bool.guard(
    when: res.status != 200,
    return: Error(InvalidResponseError),
  )

  let decoder =
    dynamic.field(
      "detail",
      dynamic.list(dynamic.optional_field(
        "pullRequests",
        dynamic.list(dynamic.field("url", dynamic.string)),
      )),
    )

  use decoded_merge_request_urls <- result.try(
    json.decode(from: res.body, using: decoder)
    |> result.replace_error(InvalidResponseError),
  )

  decoded_merge_request_urls
  |> option.values
  |> list.flatten
  |> Ok
}

fn get_auth(email email: String, token token: String) {
  let encoded_token =
    { email <> ":" <> token }
    |> bit_array.from_string
    |> bit_array.base64_encode(False)

  "Basic " <> encoded_token
}
