import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/regex
import gleam/result

pub type Semver {
  SemanticVersion(major: Int, minor: Int, patch: Int)
}

pub fn get_lowest(versions: List(Semver)) {
  versions
  |> list.fold(from: Error(Nil), with: fn(maybe_lowest, version) {
    case maybe_lowest, version {
      Error(Nil), version -> Ok(version)
      Ok(lowest), version -> {
        case compare(lowest, version) {
          order.Lt -> lowest
          _ -> version
        }
        |> Ok
      }
    }
  })
}

pub fn get_highest(versions: List(Semver)) {
  versions
  |> list.fold(from: Error(Nil), with: fn(maybe_highest, version) {
    case maybe_highest, version {
      Error(Nil), version -> Ok(version)
      Ok(highest), version -> {
        case compare(highest, version) {
          order.Gt -> highest
          _ -> version
        }
        |> Ok
      }
    }
  })
}

pub fn compare(a: Semver, b: Semver) {
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

pub fn decode(value: String) {
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
