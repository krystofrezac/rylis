import gleam/http
import rylis/min_tags/min_tags_handlers
import rylis/web
import wisp

pub fn handle_request(req: wisp.Request, ctx: web.Context) {
  use req <- web.middleware(req, ctx)

  case req.method, wisp.path_segments(req) {
    http.Get, [] -> min_tags_handlers.home_handler(req)
    http.Post, ["login"] -> min_tags_handlers.login_handler(req)
    http.Post, ["logout"] -> min_tags_handlers.logout_handler(req)
    http.Post, ["resolve-tags-for-tickets"] ->
      min_tags_handlers.resolve_tags_for_tickets_handler(req)
    _, _ -> wisp.not_found()
  }
}
