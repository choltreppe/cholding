when defined(js):
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


else:
  import karax/[vdom, karaxdsl]
  proc drawPopup*: VNode = text ""

template drawPage*(head, content): VNode =
  buildHtml(tdiv):
    drawPopup()
    tdiv(id = "head"): head
    tdiv(id = "content-container"):
      tdiv(id = "content-footer"):
        tdiv(id = "content"): content
        tdiv(id = "footer"):
          tdiv(class = "links"):
            a(href = "https://github.com/choltreppe/cholding", target = "_blank"):
              text "source code"
            a(href = "https://chol.foo/imprint.html", target = "_blank"):
              text "imprint"
          tdiv(class = "copyright"):
            text "©2024 Joël Lienhard"

template drawPage*(content): VNode = drawPage((discard), content)