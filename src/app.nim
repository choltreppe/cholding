#
#    CholChording - A chorded keyboard layout configurator and typing trainer
#        (c) Copyright 2024 Joel Lienhard (choltreppe)
#
#    See the file "LICENSE.txt", included in this
#    distribution, for details about the copyright.
#

import std/[sugar, dom]
include karax/prelude
import jsony
import ./utils, ./errorpopup, ./layouts, ./layoutedit


type
  AppTab = enum layoutEditor="Layout Editor", typingPractise="Typing Practice"
  AppData = ref object
    layout: Layout
    layoutEditor: LayoutEditView
  App = object
    tab: AppTab
    data: AppData

var app: App

proc drawMainMenu: VNode =
  buildHtml(tdiv(class = "main-menu")):
    if app.tab == layoutEditor:
      button:
        text "new layout"
        proc onClick =
          app.data = AppData(layout: Layout())
    
    drawOpenFileButton("open layout") do(content: string):
      app.data = AppData()
      if not open(app.data.layoutEditor, app.data.layout, content):
        app.data = nil

proc drawDom: VNode =
  let (actions, content) =
    if app.data == nil:
      (@[], drawMainMenu())
    else:
      case app.tab
      of layoutEditor: draw(app.data.layoutEditor, app.data.layout)
      of typingPractise: (@[], text"not yet implemented :/")

  buildHtml(tdiv):
    drawErrorPopup()

    tdiv(id = "head"):
      tdiv(id = "logo"): text "CHOL CHORDING"  #TODO
      tdiv(id = "main-tabs"):
        for tab in AppTab:
          capture(tab,
            if tab == app.tab:
              buildHtml(tdiv(class = "selected")) do:
                tdiv(class = "morph left")
                tdiv(class = "center"): text $tab
                tdiv(class = "morph right")
            else:
              buildHtml(tdiv) do:
                text $tab
                proc onClick = app = App(tab: tab)
          )
      tdiv(id = "actions"):
        for action in actions: action

    tdiv(id = "content"): content

proc postDrawDom =
  if app.data != nil and app.tab == layoutEditor:
    app.data.layoutEditor.postDraw()

setRenderer drawDom, clientPostRenderCallback = postDrawDom

window.addEventListener("keydown") do(e: Event):
  let e = e.KeyboardEvent
  if app.data != nil and app.tab == layoutEditor:
    app.data.layoutEditor.globalOnKeyDown(e, app.data.layout)