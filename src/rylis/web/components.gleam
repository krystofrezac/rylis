import gleam/list
import nakai/attr
import nakai/html

fn add_class(orig_attrs: List(attr.Attr), class: String) -> List(attr.Attr) {
  let class_attr = list.find(orig_attrs, fn(attr) { attr.name == "class" })
  let new_class_attr = case class_attr {
    Ok(class_attr) ->
      attr.Attr(name: "class", value: class_attr.value <> " " <> class)
    Error(Nil) -> attr.class(class)
  }
  [new_class_attr, ..orig_attrs]
}

pub fn h1(attrs, children) {
  html.h1(add_class(attrs, "text-3xl"), children)
}

pub fn h1_text(attrs, text) {
  h1(attrs, [html.Text(text)])
}

pub fn h2(attrs, children) {
  html.h2(add_class(attrs, "text-2xl"), children)
}

pub fn h2_text(attrs, text) {
  h2(attrs, [html.Text(text)])
}

pub fn link(attrs, children) {
  html.a(add_class(attrs, "text-blue-600 hover:text-blue-500"), children)
}

pub fn link_text(attrs, text) {
  link(attrs, [html.Text(text)])
}

pub fn button(attrs, children) {
  html.button(
    add_class(
      attrs,
      "transition-colors
        bg-blue-500 rounded-md bg-blue-600 text-white px-3 py-1.5 text-sm
        hover:bg-blue-500
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600",
    ),
    children,
  )
}

pub fn button_text(attrs, text) {
  button(attrs, [html.Text(text)])
}

pub fn error_alert(title, content) {
  html.div([attr.class("rounded-md bg-red-100 p-4")], [
    html.p_text([attr.class("font-bold text-red-800")], title),
    html.p_text([attr.class("mt-2 text-red-700")], content),
  ])
}

pub fn textarea(attrs, children) {
  html.textarea(
    add_class(
      attrs,
      "rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 
        focus:ring-2 focus:ring-inset focus:ring-blue-600",
    ),
    children,
  )
}

pub fn input(attrs) {
  html.input(add_class(
    attrs,
    "rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 
      focus:ring-2 focus:ring-inset focus:ring-blue-600",
  ))
}

pub fn field(label, children) {
  html.div([], [
    html.label_text([attr.class("text-gray-900")], label),
    html.div([attr.class("mt-1 flex flex-col")], [children]),
  ])
}

pub fn code(attrs, children) {
  html.code(
    add_class(attrs, "text-sm bg-gray-100 rounded-md p-1 mx-1"),
    children,
  )
}

pub fn code_text(attrs, text) {
  code(attrs, [html.Text(text)])
}

pub fn layout(children: List(html.Node)) {
  html.Html([], [
    html.Head([
      html.meta([attr.charset("utf-8")]),
      html.meta([
        attr.name("viewport"),
        attr.content("width=device-width, initial-scale=1.0"),
      ]),
      // HTMX
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
      // FONTS
      html.link([
        attr.rel("preconnect"),
        attr.href("https://fonts.googleapis.com"),
      ]),
      html.link([
        attr.rel("preconnect"),
        attr.href("https://fonts.gstatic.com"),
        attr.crossorigin(),
      ]),
      html.link([
        attr.href(
          "https://fonts.googleapis.com/css2?family=Roboto:wght@400;500&display=swap",
        ),
        attr.rel("stylesheet"),
      ]),
      // APP SPECIFIC
      html.link([attr.rel("stylesheet"), attr.href("/static/css/app.css")]),
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
    html.Body([attr.class("mx-auto max-w-screen-lg")], [
      html.div([attr.class("mt-2")], [h1_text([], "Rylís")]),
      html.p([attr.class("mb-4 text-gray-500")], [
        html.Text(
          "Finds the lowest tags where changes from all of the issues are present. Code available at ",
        ),
        link_text(
          [attr.href("https://github.com/krystofrezac/rylis")],
          "Github",
        ),
        html.Text("."),
      ]),
      ..children
    ]),
  ])
}
