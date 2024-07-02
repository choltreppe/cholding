import std/[strutils, strformat]
import karax/[vdom, karaxdsl]
import ./widgets

when isMainModule:
  let dom = drawPage do:
    tdiv(id = "logo")
  do:
    tdiv(class = "main-menu"):
      for title in ["Layout Editor", "Typing Practice"]:
        a(href = title.replace(" ").toLowerASCII & ".html"):
          text title

  dom.id = "ROOT"

  writeFile("build/index.html"): fmt"""
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />

        <title>Cholding</title>

        <link rel="stylesheet" href="common.css"/>
        <link rel="stylesheet" href="index.css"/>
      </head>

      <body>
        {dom}
      </body>
    </html>
  """.dedent