#
#    CholChording - A chorded keyboard layout configurator and typing trainer
#        (c) Copyright 2024 Joel Lienhard (choltreppe)
#
#    See the file "LICENSE.txt", included in this
#    distribution, for details about the copyright.
#

import std/[options, tables, setutils, sequtils, strutils, sugar, dom]
import fusion/matching
include karax/prelude
import jsony
import ./utils, ./errorpopup, ./layouts


type
  PullResistorKind = enum pullUp="HIGH", pullDown="LOW"

  Pin = object
    name: string   # string to allow "A0" and such
    pullResistor: PullResistorKind

  Config = object
    layout: Layout
    pins: seq[Pin]

  LayoutEditStage* = enum
    handSetupSelect
    basicKeyConfig
    chordConfig
    pinConfig

  LayoutEditView* = object
    case stage: LayoutEditStage
    of basicKeyConfig:
      selected: Option[InKeyId]
    of chordConfig:
      justAddedChord: bool
    of pinConfig:
      pins: seq[Pin]
      errorPinNames: seq[string]
    else: discard

converter toView*(stage: LayoutEditStage): LayoutEditView =
  LayoutEditView(stage: stage)


proc new(view: var LayoutEditView, layout: var Layout) =
  layout = Layout()
  view = LayoutEditView()

proc open*(
  view: var LayoutEditView,
  layout: var Layout,
  content: string
): bool {.discardable.} =
  try:
    layout = content.fromJson(Layout)
    view = chordConfig
    result = true
  except JsonError as e:
    setErrorPopup(
      title = "Failed to open layout",
      msg = e.msg
    )

proc save(layout: Layout) {.inline.} =
  downloadFile("layout.json", "text/json", layout.toJson)


proc generateArduino(layout: Layout, pins: seq[Pin]): string =
  const templ = staticRead("template.ino")
  templ % [
    "key_count", $keyCount[layout.handSetup],
    "key_pins", "{" & pins.mapIt(it.name).join(", ") & "}",
    "key_pulls", "{" & pins.mapIt($it.pullResistor).join(", ") & "}",
    "basic_keys", "{" & collect(
      for i in 0 ..< keyCount[layout.handSetup]:
        if i in layout.basicKeys:
          "'" & $layout.basicKeys[i].charCode & "'"
        else: "0"
    ).join(", ") & "}",
    "chord_mask", layout.basicKeys.keys.toSet.toBinNum,
    "init_chords",
      layout.chords
      .mapIt("chord[" & it.inKeys.toBinNum & "] = '" & $it.outKey.charCode & "';")
      .join("\n  ")
  ]


proc draw*(
  view: var LayoutEditView,
  layout: var Layout
): tuple[
  actions: seq[VNode],
  content: VNode
] =

  result.content =
    case view.stage
    of handSetupSelect:
      buildHtml(tdiv(class = "main-menu")):
        for setup in HandSetup:
          capture(setup, buildHtml(button) do:
            text $setup & " hand" & (if setup == bothHands: "s" else: "")
            proc onClick =
              layout.handSetup = setup
              view = basicKeyConfig
          )

    of basicKeyConfig:
      buildHtml(tdiv(id = "basic-key-config")):
        drawHands(layout.handSetup, isSmall=false) do(id: InKeyId) -> VNode:
          if id in layout.basicKeys:
            var node = drawKey(layout.basicKeys[id]) do(key: OutKey):
              layout.basicKeys[id] = key
            (node.addEventHandler(onClick) do(_: Event, n: VNode):
              if n.dom == document.activeElement:
                layout.basicKeys.del(id)
                blur n.dom.Element
            )
            node
          else:
            drawKey do(key: OutKey):
              layout.basicKeys[id] = key
        
        button:
          text "next"
          proc onClick =
            view = chordConfig
            layout.chords.setLen 1
            view.justAddedChord = true

    of chordConfig:
      let dupInKeys = layout.chords.mapIt(it.inKeys).duplicates
      let dupOutKeys = layout.chords.mapIt(it.outKey).duplicates
      buildHtml(tdiv(id = "chord-config")):
        tdiv(id = "chords"):
          for i, chord in layout.chords:
            let errInKeys = card(chord.inKeys) == 0 or chord.inKeys in dupInKeys
            let errOutKey = chord.outKey.keyCode == 0 or chord.outKey in dupOutKeys
            capture(i, buildHtml(tdiv(
              class = "chord".addClassIf(i < high(layout.chords), ""
                .addClassIf(errInKeys, "error-in-keys")
                .addClassIf(errOutKey, "error-out-key")
              )
            )) do:
              input(
                class = "out-key",
                `type` = "text",
                value = $chord.outKey,
                onKeyDown = registerKeyHandler(proc(key: OutKey) =
                  layout.chords[i].outKey = key
                )
              )
              drawHands(layout.handSetup, isSmall=true) do(id: InKeyId) -> VNode:
                if id in layout.basicKeys:
                  drawKey(layout.basicKeys[id])
                else:
                  drawKey(pressed = id in chord.inKeys) do (e: Event, n: VNode):
                    layout.chords[i].inKeys[id] = id notin layout.chords[i].inKeys
              button(class = "close"):
                proc onClick =
                  layout.chords.del(i)
            )
          button(class = "small"):
            text "+ add Chord"
            proc onClick =
              layout.chords &= Chord()
              view.justAddedChord = true
    
    of pinConfig:
      buildHtml(tdiv(id = "pin-config")):
        tdiv:
          tdiv(class = "row-labels"):
            tdiv: text "pin:"
            tdiv: text "pull resistor:"
          drawHands(layout.handSetup, isSmall=false) do(id: InKeyId) -> VNode:
            buildHtml(tdiv):
              drawKey()
              tdiv(class = "line")
              input(
                `type` = "text",
                value = view.pins[id].name,
                tabindex = $(id+1),
                class =
                  if view.pins[id].name in view.errorPinNames:
                    " error"
                  else: ""
              ):
                proc onInput(_: Event, n: Vnode) =
                  view.pins[id].name = strip($n.value)
                  view.errorPinNames = @[]
              tdiv(class = "pull-resistor"):
                for kind in PullResistorKind:
                  if kind == view.pins[id].pullResistor:
                    button(class = "small selected"): text $kind
                  else:
                    capture(kind, buildHtml(button(class = "small")) do:
                      text $kind
                      proc onClick =
                        view.pins[id].pullResistor = kind
                    )
        tdiv(class = "buttons"):
          button(class = "secondary"):
            text "cancel"
            proc onClick = view = chordConfig
          if len(view.errorPinNames) == 0:
            button:
              text "export"
              proc onClick =
                view.errorPinNames = view.pins.mapIt(it.name).duplicates
                if view.pins.anyIt(it.name == ""):
                  view.errorPinNames &= ""
                if len(view.errorPinNames) == 0:
                  downloadFile("code.ino", "text/arduino", generateArduino(layout, view.pins))
                  view = chordConfig
          else:
            button(class = "disabled"):
              text "export"

  if view.stage == chordConfig:
    result.actions.add: buildHtml(button):
      text "Export Arduino"
      proc onClick =
        view = pinConfig
        view.pins.setLen keyCount[layout.handSetup]

  if view.stage in basicKeyConfig .. chordConfig:
    result.actions.add: buildHtml(tdiv):
      button(class = "icon new-file", title = "new"):
        proc onCLick = new view, layout

      drawOpenFileButton(
        buildHtml(button(class = "icon open-file")),
        proc(content: string) = open(view, layout, content)
      ) 

      if view.stage == chordConfig:
        button(class = "icon save", title = "save"):
          proc onClick = save layout
      else:
        button(
          class = "icon save disabled",
          title = "not all steps done"
        )

proc postDraw*(view: var LayoutEditView) =
  if view.stage == chordConfig and view.justAddedChord:
    view.justAddedChord = false
    focus:
      document
      .querySelectorAll("#chords > .chord")[^1]
      .getElementsByClass("out-key")[0]
      .InputElement

proc globalOnKeyDown*(
  view: var LayoutEditView,
  e: KeyboardEvent,
  layout: var Layout
) =
  if e.ctrlKey and e.key == "s":
    e.preventDefault()
    if view.stage == chordConfig:
      save layout