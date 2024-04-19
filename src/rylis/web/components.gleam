import nakai/attr
import nakai/html

pub fn layout(children: List(html.Node)) {
  html.Html([], [
    html.Head([
      html.meta([attr.charset("utf-8")]),
      html.meta([
        attr.name("viewport"),
        attr.content("width=device-width, initial-scale=1.0"),
      ]),
      html.Element(
        "script",
        [attr.src("https://unpkg.com/htmx.org@1.9.12")],
        [],
      ),
      html.Element(
        "script",
        [attr.src("https://unpkg.com/htmx.org@1.9.12/dist/ext/json-enc.js")],
        [],
      ),
      html.title("Rylís"),
      html.link([
        attr.rel("icon"),
        attr.href("/static/favicon.ico"),
        attr.type_("image/x-icon"),
      ]),
      html.link([
        attr.rel("icon"),
        attr.href("/static/favicon.svg"),
        attr.type_("image/svg+xml"),
      ]),
    ]),
    html.Body([], [html.h1_text([], "Rylís"), ..children]),
  ])
}
