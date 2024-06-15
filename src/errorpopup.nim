import std/options
import fusion/matching
include karax/prelude


var errorPopupMsg: Option[tuple[title, msg: string]]

proc setErrorPopup*(title, msg: string) =
  errorPopupMsg = some((title, msg))

proc drawErrorPopup*: VNode =
  if Some(@error) ?= errorPopupMsg:
    buildHtml(tdiv(id = "error-popup")):
      tdiv(class = "backdrop"):
        proc onClick = errorPopupMsg = none((string, string))
      tdiv(class = "msg"):
        tdiv(class = "title"):
          text error.title
        tdiv(class = "content"):
          text error.msg
        button(class = "close"):
          proc onClick = errorPopupMsg = none((string, string))
  
  else: text ""