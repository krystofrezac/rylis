import gleam/erlang/process
import gleam/result
import glenvy/dotenv
import glenvy/env
import mist
import rylis/web
import rylis/web/router
import wisp

pub fn main() {
  wisp.configure_logger()

  let dev =
    env.get_bool("DEV")
    |> result.replace_error(False)
    |> result.unwrap_both
  case dev {
    True -> {
      let assert Ok(_) = dotenv.load_from(".env.dev")
      Nil
    }
    False -> Nil
  }
  let assert Ok(secret_key_base) = env.get_string("SECRET_KEY_BASE")

  let ctx = {
    let assert Ok(priv_directory) = wisp.priv_directory("rylis")
    let static_directory = priv_directory <> "/static"
    web.Context(static_directory: static_directory)
  }
  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp.mist_handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
