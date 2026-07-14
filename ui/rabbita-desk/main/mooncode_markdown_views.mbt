// Safe CommonMark rendering adapted from OpenSeek's transcript renderer.
// Model output is mapped to Rabbita nodes; raw HTML is always shown as text.

///|
fn mooncode_markdown_nodes(
  dispatch : Dispatch[Msg],
  copied_item_id : String,
  source : String,
) -> Array[@rabbita.Html] {
  @js.Error_::wrap(() => {
    @js.Value::cast_from(
      mooncode_parsed_markdown_nodes(dispatch, copied_item_id, source),
    )
  }) catch {
    _ => [pre(class="mooncode-markdown-fallback", source)]
  }
}

///|
fn mooncode_parsed_markdown_nodes(
  dispatch : Dispatch[Msg],
  copied_item_id : String,
  source : String,
) -> Array[@rabbita.Html] {
  let doc = @cmark.Doc::from_string(source, strict=false)
  let render = MoonCodeMarkdownRender::{
    defs: doc.defs,
    dispatch,
    copied_item_id,
  }
  render.block_nodes(doc.block)
}

///|
priv struct MoonCodeMarkdownRender {
  defs : Map[String, @cmark.LabelDef]
  dispatch : Dispatch[Msg]
  copied_item_id : String
}

///|
fn MoonCodeMarkdownRender::block_nodes(
  self : MoonCodeMarkdownRender,
  block : @cmark.Block,
) -> Array[@rabbita.Html] {
  let out : Array[@rabbita.Html] = []
  self.push_block(out, block)
  out
}

///|
fn MoonCodeMarkdownRender::push_block(
  self : MoonCodeMarkdownRender,
  out : Array[@rabbita.Html],
  block : @cmark.Block,
) -> Unit {
  match block {
    BlankLine(_) | LinkRefDefinition(_) => ()
    Blocks(node) =>
      for child in node.v.iter() {
        self.push_block(out, child)
      }
    Paragraph(node) => out.push(p(self.inline_nodes(node.v.inline)))
    Heading(node) => out.push(self.heading(node.v))
    BlockQuote(node) =>
      out.push(@html.blockquote(self.block_nodes(node.v.block)))
    CodeBlock(node) | ExtMathBlock(node) => out.push(self.code_block(node.v))
    HtmlBlock(node) =>
      out.push(
        pre(class="mooncode-raw-html", mooncode_markdown_lines(node.v.0)),
      )
    List(node) => out.push(self.list(node.v))
    ThematicBreak(_) => out.push(@html.hr())
    ExtTable(node) => out.push(self.table(node.v))
    ExtFootnoteDefinition(node) => {
      let children : Array[@rabbita.Html] = [
        span(class="mooncode-footnote-label", node.v.label.key),
      ]
      for child in self.block_nodes(node.v.block) {
        children.push(child)
      }
      out.push(div(class="mooncode-footnote", children))
    }
  }
}

///|
fn MoonCodeMarkdownRender::heading(
  self : MoonCodeMarkdownRender,
  heading : @cmark.BlockHeading,
) -> @rabbita.Html {
  let children = self.inline_nodes(heading.inline)
  match heading.level {
    1 => h1(children)
    2 => h2(children)
    3 => h3(children)
    4 => @html.h4(children)
    5 => @html.h5(children)
    _ => @html.h6(children)
  }
}

///|
fn mooncode_markdown_lines(lines : @cmark.Seq[@cmark.Node[String]]) -> String {
  let buffer = StringBuilder::new()
  let mut first = true
  for line in lines.iter() {
    if !first {
      buffer.write_char('\n')
    }
    buffer.write_string(line.v)
    first = false
  }
  buffer.to_string()
}

///|
fn MoonCodeMarkdownRender::code_block(
  self : MoonCodeMarkdownRender,
  block : @cmark.CodeBlock,
) -> @rabbita.Html {
  let language = match block.info_string {
    Some(info) =>
      match @cmark.CodeBlock::language_of_info_string(info.v) {
        Some((language, _)) => language
        None => ""
      }
    None => ""
  }
  let content = mooncode_markdown_lines(block.code)
  let item_id = @desk.stable_id("mooncode-code", language + ":" + content)
  div(
    class="mooncode-code-block",
    attrs=@html.Attrs::build().data_set("testid", "mooncode-code-block"),
    [
      div(class="mooncode-code-toolbar", [
        span(if language == "" { "Code" } else { language }),
        button(
          class="mooncode-copy-button",
          attrs=@html.Attrs::build()
            .aria_label(
              if self.copied_item_id == item_id {
                "Copied code"
              } else {
                "Copy code"
              },
            )
            .data_set("testid", "mooncode-copy-code"),
          on_click=(self.dispatch)(CopyMoonCodeText(item_id, content)),
          if self.copied_item_id == item_id {
            "Copied"
          } else {
            "Copy"
          },
        ),
      ]),
      pre([
        code(
          class=if language == "" { "" } else { "language-" + language },
          content,
        ),
      ]),
    ],
  )
}

///|
fn MoonCodeMarkdownRender::list(
  self : MoonCodeMarkdownRender,
  list : @cmark.BlockList,
) -> @rabbita.Html {
  let items : Array[@rabbita.Html] = []
  for item_node in list.items.iter() {
    let item = item_node.v
    let children : Array[@rabbita.Html] = []
    if item.ext_task_marker is Some(marker) {
      let symbol = match @cmark.ListTaskStatus::from_marker(marker.v) {
        Checked => "[x]"
        Cancelled => "[-]"
        Unchecked | Other(_) => "[ ]"
      }
      children.push(span(class="mooncode-task-marker", symbol + " "))
    }
    for child in self.block_nodes(item.block) {
      children.push(child)
    }
    items.push(@html.li(children))
  }
  let class = if list.tight { "tight" } else { "" }
  match list.ty {
    Ordered(start, _) => @html.ol(class~, start~, items)
    Unordered(_) => @html.ul(class~, items)
  }
}

///|
fn MoonCodeMarkdownRender::table(
  self : MoonCodeMarkdownRender,
  markdown_table : @cmark.Table,
) -> @rabbita.Html {
  let head : Array[@rabbita.Html] = []
  let body : Array[@rabbita.Html] = []
  for row in markdown_table.rows.iter() {
    let (row_node, _) = row
    match row_node.v {
      Header(cells) => {
        let cell_nodes : Array[@rabbita.Html] = []
        for cell in cells.iter() {
          cell_nodes.push(@html.th(self.inline_nodes(cell.0)))
        }
        head.push(@html.tr(cell_nodes))
      }
      Data(cells) => {
        let cell_nodes : Array[@rabbita.Html] = []
        for cell in cells.iter() {
          cell_nodes.push(@html.td(self.inline_nodes(cell.0)))
        }
        body.push(@html.tr(cell_nodes))
      }
      Sep(_) => ()
    }
  }
  @html.table([@html.thead(head), @html.tbody(body)])
}

///|
fn MoonCodeMarkdownRender::inline_nodes(
  self : MoonCodeMarkdownRender,
  inline : @cmark.Inline,
) -> Array[@rabbita.Html] {
  let out : Array[@rabbita.Html] = []
  self.push_inline(out, inline)
  out
}

///|
fn MoonCodeMarkdownRender::push_inline(
  self : MoonCodeMarkdownRender,
  out : Array[@rabbita.Html],
  inline : @cmark.Inline,
) -> Unit {
  match inline {
    Text(node) => out.push(@html.text(node.v))
    Inlines(node) =>
      for child in node.v.iter() {
        self.push_inline(out, child)
      }
    Break(node) =>
      match node.v.ty {
        Hard => out.push(@html.br())
        Soft => out.push(@html.text(" "))
      }
    CodeSpan(node) =>
      out.push(code(class="mooncode-inline-code", node.v.code()))
    Emphasis(node) => out.push(@html.em(self.inline_nodes(node.v.inline)))
    StrongEmphasis(node) => out.push(strong(self.inline_nodes(node.v.inline)))
    ExtStrikethrough(node) => out.push(@html.del(self.inline_nodes(node.v.0)))
    ExtMathSpan(node) =>
      out.push(code(class="mooncode-inline-code", node.v.tex()))
    Autolink(node) => {
      let url = node.v.link.v
      if node.v.is_email {
        out.push(mooncode_markdown_link("mailto:" + url, [@html.text(url)]))
      } else if @cmark.InlineLink::is_unsafe(url) {
        out.push(@html.text(url))
      } else {
        out.push(mooncode_markdown_link(url, [@html.text(url)]))
      }
    }
    Link(node) => {
      let children = self.inline_nodes(node.v.text)
      match self.link_destination(node.v) {
        Some(url) => out.push(mooncode_markdown_link(url, children))
        None => out.push(span(children))
      }
    }
    Image(node) =>
      out.push(@html.text(mooncode_markdown_plain_text(node.v.text)))
    RawHtml(node) => out.push(@html.text(mooncode_markdown_tights(node.v.0)))
  }
}

///|
fn MoonCodeMarkdownRender::link_destination(
  self : MoonCodeMarkdownRender,
  link : @cmark.InlineLink,
) -> String? {
  let definition = match link.reference {
    Inline(node) => Some(node.v)
    Ref(_, _, _) =>
      match link.reference_definition(self.defs) {
        Some(LinkDef(node)) => Some(node.v)
        _ => None
      }
  }
  match definition {
    Some(definition) =>
      match definition.dest {
        Some(dest) if !@cmark.InlineLink::is_unsafe(dest.v) => Some(dest.v)
        _ => None
      }
    None => None
  }
}

///|
fn mooncode_markdown_link(
  href : String,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  @html.a(href~, target=Blank, rel="noopener noreferrer", children)
}

///|
fn mooncode_markdown_plain_text(inline : @cmark.Inline) -> String {
  let buffer = StringBuilder::new()
  for line in inline.to_plain_text(break_on_soft=false) {
    for segment in line {
      buffer.write_string(segment)
    }
  }
  buffer.to_string()
}

///|
fn mooncode_markdown_tights(tights : @cmark.Seq[@cmark.Tight]) -> String {
  let buffer = StringBuilder::new()
  for tight in tights.iter() {
    buffer.write_string(tight.to_string())
  }
  buffer.to_string()
}
