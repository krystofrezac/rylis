import gleeunit/should
import rylis/pagination

pub fn get_all_pages_test() {
  let do_request = fn(page_number) {
    pagination.PaginatedResponse(data: [page_number], total_pages: 10)
    |> Ok
  }

  pagination.get_all_pages(do_request)
  |> should.equal(Ok([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
}

pub fn count_to_pages_test() {
  pagination.count_to_pages(count: 16, page_size: 2)
  |> should.equal(8)

  pagination.count_to_pages(count: 16, page_size: 2)
  |> should.equal(8)
}
