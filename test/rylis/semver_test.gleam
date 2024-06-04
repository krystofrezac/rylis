import gleam/order
import gleeunit/should
import rylis/semver

pub fn get_lowest_test() {
  [
    semver.Semver(1, 1, 1),
    semver.Semver(1, 0, 0),
    semver.Semver(1, 0, 1),
    semver.Semver(1, 0, 0),
    semver.Semver(2, 3, 4),
  ]
  |> semver.get_lowest
  |> should.equal(Ok(semver.Semver(1, 0, 0)))

  [semver.Semver(1, 2, 0), semver.Semver(2, 3, 2), semver.Semver(1, 1, 9210)]
  |> semver.get_lowest
  |> should.equal(Ok(semver.Semver(1, 1, 9210)))

  []
  |> semver.get_lowest
  |> should.equal(Error(Nil))
}

pub fn get_highest_test() {
  [
    semver.Semver(1, 1, 1),
    semver.Semver(1, 0, 0),
    semver.Semver(1, 0, 1),
    semver.Semver(2, 3, 4),
  ]
  |> semver.get_highest
  |> should.equal(Ok(semver.Semver(2, 3, 4)))

  []
  |> semver.get_highest
  |> should.equal(Error(Nil))
}

pub fn compare_test() {
  semver.compare(semver.Semver(1, 2, 3), semver.Semver(2, 2, 3))
  |> should.equal(order.Lt)

  semver.compare(semver.Semver(1, 2, 3), semver.Semver(1, 3, 3))
  |> should.equal(order.Lt)

  semver.compare(semver.Semver(1, 2, 3), semver.Semver(1, 2, 4))
  |> should.equal(order.Lt)

  semver.compare(semver.Semver(1, 2, 3), semver.Semver(1, 2, 3))
  |> should.equal(order.Eq)

  semver.compare(semver.Semver(2, 2, 3), semver.Semver(1, 2, 3))
  |> should.equal(order.Gt)

  semver.compare(semver.Semver(1, 3, 3), semver.Semver(1, 2, 3))
  |> should.equal(order.Gt)

  semver.compare(semver.Semver(1, 2, 4), semver.Semver(1, 2, 3))
  |> should.equal(order.Gt)

  semver.compare(semver.Semver(1, 2, 0), semver.Semver(1, 1, 9210))
  |> should.equal(order.Gt)
}

pub fn parse_test() {
  "1.2.3"
  |> semver.parse
  |> should.equal(
    semver.Semver(1, 2, 3)
    |> Ok,
  )

  "1.2.3-f1"
  |> semver.parse
  |> should.equal(Error(Nil))

  "invalid"
  |> semver.parse
  |> should.equal(Error(Nil))
}
