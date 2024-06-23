import std/[dom, tables, strutils, strformat, options]
import fusion/matching
import jsony
include karax/prelude


proc setCookie*(name, value: string) =
  document.cookie = &"{name}={value}"

proc getCookie*(name: string): Option[string] =
  for cookieStr in decodeURIComponent(document.cookie).`$`.split(';'):
    if ([@n, @v] ?= cookieStr.split("=")) and strip(n) == name:
      return some(v)


proc downloadFile*(name, kind, content: string) =
  let node = document.createElement("a")
  node.setAttribute("href", cstring &"data:{kind};charset=utf-8,{encodeURIComponent(content)}")
  node.setAttribute("download", cstring name)
  click node

proc uploadFile*(node: Node, cb: proc(content: string)) =
  let file = node.InputElement.files[0]
  let reader = newFileReader()
  reader.onload = proc(_: Event) =
    cb($reader.resultAsString)
    redraw()
  reader.readAsText(file)

proc drawOpenFileButton*(button: VNode, onUpload: proc(content: string)): VNode =
  buildHtml(tdiv(class = "open-file-button")):
    button
    input(`type` = "file", title = "open"):
      proc onChange(_: Event, n: VNode) =
        n.dom.uploadFile(onUpload)

proc drawOpenFileButton*(text: string, onUpload: proc(content: string)): VNode =
  drawOpenFileButton(buildHtml(button, text text), onUpload)


proc parseHook*[K: not string, V](s: string, i: var int, v: var SomeTable[K, V]) =
  when compiles(new(v)):
    new(v)
  eatChar(s, i, '{')
  while i < s.len:
    eatSpace(s, i)
    if i < s.len and s[i] == '}':
      break
    eatChar(s, i, '"')
    var key: K
    parseHook(s, i, key)
    eatChar(s, i, '"')
    eatChar(s, i, ':')
    var element: V
    parseHook(s, i, element)
    v[key] = element
    if i < s.len and s[i] == ',':
      inc i
    else:
      break
  eatChar(s, i, '}')

proc dumpHook*[K: not string, V](s: var string, v: Table[K, V]) =
  s.add '{'
  var i = 0
  for k, v in v:
    if i != 0:
      s.add ','
    s.add '"'
    dumpHook(s, k)
    s.add "\":"
    dumpHook(s, v)
    inc i
  s.add '}'


func toBinNum*[T](s: set[T]): string =
  result = "0b"
  for i in countdown(high(T), low(T)):
    result.add:
      if i in s: "1"
      else: "0"


func duplicates*[T](things: openarray[T]): seq[T] =
  var found: seq[T]
  for thing in things:
    if thing in found:
      result &= thing
    else:
      found &= thing


func addClassIf*(base: string, cond: bool, name: string): string =
  result = base
  if cond: result &= " " & name