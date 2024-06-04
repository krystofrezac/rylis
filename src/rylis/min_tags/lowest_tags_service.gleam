import gleam/dict
import gleam/list
import gleam/result
import rylis/min_tags/tags_resolver_service
import rylis/semver

pub type RepositoryWithTag {
  RepositoryWithTag(base_url: String, name: String, tag: semver.Semver)
}

pub fn get_lowest_by_repository(
  resolve_result: tags_resolver_service.ResolveResult,
) -> List(RepositoryWithTag) {
  let repositories_with_min_tags =
    resolve_result
    |> list.filter_map(fn(ticket_url) {
      use ticket <- result.try(ticket_url.result |> result.replace_error(Nil))
      use sub_tickets <- result.try(ticket.result |> result.replace_error(Nil))

      sub_tickets
      |> list.filter_map(fn(sub_ticket) {
        use raw_merge_requests <- result.try(
          sub_ticket.result |> result.replace_error(Nil),
        )

        raw_merge_requests
        |> list.filter_map(fn(raw_merge_request) {
          use parsed_merge_request <- result.try(
            raw_merge_request.result |> result.replace_error(Nil),
          )
          use merge_sha <- result.try(
            parsed_merge_request.result |> result.replace_error(Nil),
          )
          use lowest_tag <- result.try(
            merge_sha.lowest_tag |> result.replace_error(Nil),
          )

          RepositoryWithTag(
            base_url: parsed_merge_request.base_url,
            name: parsed_merge_request.project,
            tag: lowest_tag,
          )
          |> Ok
        })
        |> Ok
      })
      |> Ok
    })
    |> list.flatten
    |> list.flatten

  repositories_with_min_tags
  |> list.group(fn(repository) { #(repository.base_url, repository.name) })
  |> dict.to_list
  |> list.filter_map(fn(group) {
    let #(#(base_url, name), repositories) = group

    let highest_tag =
      repositories
      |> list.map(fn(repository) { repository.tag })
      |> semver.get_highest

    use highest_tag <- result.map(highest_tag)

    RepositoryWithTag(base_url: base_url, name: name, tag: highest_tag)
  })
}
