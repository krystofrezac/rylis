import gleam/dynamic
import gleam/json

pub fn decode_errors_to_json(decode_err: List(dynamic.DecodeError)) {
  json.array(decode_err, fn(item) {
    json.object([
      #("expected", json.string(item.expected)),
      #("found", json.string(item.found)),
      #("path", json.array(item.path, fn(path_item) { json.string(path_item) })),
    ])
  })
  |> json.to_string_builder()
}
