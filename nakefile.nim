import std/[strformat, os]
import nake

const pages = @["layouteditor", "typingpractice"]

var release = false

task "buildJs", "compile nim code to js":
  for page in pages:
    let inPath = &"src/{page}.nim"
    let outPath = &"build/{page}.js"
    direShell "nim js",
      (if release: "-d:release" else: ""),
      "-o:" & outPath,
      inPath
    if release:
      let outPathMin = outPath.changeFileExt("min.js")
      direShell "terser",
        outPath,
        "-o", outPathMin,
        "-c -m"
      direShell "mv", outPathMin, outPath

task "buildCss", "compile sass":
  for page in "common" & pages:
    direShell &"sassc sass/{page}.sass build/{page}.css"

task "buildHtml", "generate html index pages":
  const templ = readFile("template.html")
  for page in pages:
    writeFile(&"build/{page}.html", templ % ["page", $page])

task "build", "build all":
  runTask "buildJs"
  runTask "buildCss"
  runTask "buildHtml"

task "release", "build release version":
  release = true
  runTask "build"