import gleam/result
import gleam/string
import wisp

pub type Context {
  Context(static_directory: String)
}

pub type Auth {
  Auth(jira_email: String, jira_token: String, gitlab_token: String)
}

const auth_cookie_name = "auth"

const auth_cookie_separator = ";"

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)

  handle_request(req)
}

pub fn save_auth(req: wisp.Request, res: wisp.Response, auth: Auth) {
  let cookie_value =
    auth.jira_email
    <> auth_cookie_separator
    <> auth.jira_token
    <> auth_cookie_separator
    <> auth.gitlab_token

  wisp.set_cookie(
    name: auth_cookie_name,
    value: cookie_value,
    // 90 days
    max_age: 60 * 60 * 24 * 90,
    request: req,
    response: res,
    security: wisp.Signed,
  )
}

pub fn remove_auth(req: wisp.Request, res: wisp.Response) {
  wisp.set_cookie(
    name: auth_cookie_name,
    value: "",
    // This removes/invalidates the cookie
    max_age: 0,
    request: req,
    response: res,
    security: wisp.Signed,
  )
}

pub fn get_auth(req: wisp.Request) {
  use cookie <- result.try(
    req
    |> wisp.get_cookie(auth_cookie_name, wisp.Signed),
  )
  let cookie_segments = string.split(cookie, on: auth_cookie_separator)
  case cookie_segments {
    [jira_email, jira_token, gitlab_token] ->
      Auth(jira_email, jira_token, gitlab_token)
      |> Ok
    _ -> Error(Nil)
  }
}

pub fn require_auth(req: wisp.Request, next: fn(Auth) -> wisp.Response) {
  let maybe_auth = get_auth(req)

  case maybe_auth {
    Error(Nil) ->
      wisp.response(401)
      |> wisp.string_body("Unauthorized")
    Ok(auth) -> next(auth)
  }
}
