import std/[options, dom]
import fusion/matching
include karax/prelude
import ./utils


var popupMsg: Option[tuple[
  isError: bool,
  title: string,
  content: VNode
]]

proc setPopup*(title: string, content: VNode) =
  popupMsg = some((false, title, content))

proc setErrorPopup*(title, msg: string) =
  popupMsg = some((true, title, text msg))

proc closePopup* = popupMsg = none(typeof(popupMsg.get))

proc drawPopup*: VNode =
  if Some(@msg) ?= popupMsg:
    var content = msg.content
    if content.kind == VNodeKind.text:
      content = buildHtml(tdiv): content
    content.class = "content"

    buildHtml(tdiv(id = "popup")):
      tdiv(class = "backdrop"):
        proc onClick = closePopup()
      tdiv(class = "msg".addClassIf(msg.isError, "error")):
        tdiv(class = "title"):
          text msg.title
        content
        button(class = "close"):
          proc onClick = closePopup()
  
  else: text ""


proc drawPage*(actions: seq[VNode], content: VNode): VNode =
  buildHtml(tdiv):
    drawPopup()
    tdiv(id = "head"):
      tdiv(id = "logo"):
        text "CHOL CHORDING"  #TODO
        proc onClick =
          window.location.hash = ""
      tdiv(id = "actions"):
        for action in actions: action
    tdiv(id = "content"): content