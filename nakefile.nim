import std/[strformat, os]
import nake

const pages = @["layouteditor", "typingpractice"]


task "buildJs", "compile nim code to js":
  for page in pages:
    direShell &"nim js -o:build/{page}.js src/{page}.nim"

task "buildCss", "compile sass":
  for page in "common" & pages:
    direShell &"sassc sass/{page}.sass build/{page}.css"

task "buildHtml", "generate html index pages":
  const templ = readFile("index.html")
  for page in pages:
    writeFile(&"build/{page}.html", templ % ["page", $page])

task "build", "build all":
  runTask "buildJs"
  runTask "buildCss"
  runTask "buildHtml"