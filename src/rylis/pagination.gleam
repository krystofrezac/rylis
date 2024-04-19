import gleam/bool
import gleam/list
import gleam/otp/task
import gleam/result

pub type PaginatedResponse(item) {
  PaginatedResponse(data: List(item), total_pages: Int)
}

pub fn get_all_pages(
  do_request: fn(Int) -> Result(PaginatedResponse(data), error),
) {
  use first_page <- result.try(do_request(1))

  get_rest_of_pages(first_page, do_request)
}

fn get_rest_of_pages(
  first_page: PaginatedResponse(data),
  do_request: fn(Int) -> Result(PaginatedResponse(data), error),
) {
  use <- bool.guard(
    when: first_page.total_pages <= 1,
    return: Ok(first_page.data),
  )

  use rest_of_pages <- result.try(
    list.range(2, first_page.total_pages)
    |> list.map(fn(page_number) {
      use <- task.async
      do_request(page_number)
    })
    |> list.map(task.await(_, 30_000))
    |> result.all,
  )

  [first_page, ..rest_of_pages]
  |> list.map(fn(page) { page.data })
  |> list.concat
  |> Ok
}

pub fn count_to_pages(count count: Int, page_size page_size: Int) {
  let floored_pages = count / page_size
  let rest = count - floored_pages * page_size
  case rest {
    0 -> floored_pages
    _ -> floored_pages + 1
  }
}
