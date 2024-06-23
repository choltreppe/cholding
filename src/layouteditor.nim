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
import ./utils, ./widgets, ./layouts


type
  VoltageLevel = enum voltageLow="LOW", voltageHigh="HIGH"

  Pin = object
    name: string   # string to allow "A0" and such
    connectedTo: VoltageLevel

  Config = object
    layout: Layout
    pins: seq[Pin]

  LayoutEditStage = enum
    handSetupSelect
    basicKeyConfig
    chordConfig
    pinConfig

  LayoutEditView = object
    case stage: LayoutEditStage
    of basicKeyConfig:
      selected: Option[InKeyId]
    of chordConfig:
      justAddedChord: bool
    of pinConfig:
      pins: seq[Pin]
      errorPinNames: seq[string]
    else: discard

  LayoutEdit* = object
    case isOpen: bool
    of true:
      layout: Layout
      view: LayoutEditView
    else: discard

var self: LayoutEdit

converter toView(stage: LayoutEditStage): LayoutEditView =
  LayoutEditView(stage: stage)

proc openLayout(json: string) =
  if Some(@layout) ?= parseLayout(json):
    self = LayoutEdit(
      isOpen: true,
      layout: layout,
      view: chordConfig
    )


proc generateArduino(layout: Layout, pins: seq[Pin]): string =
  func toArduinoKey(key: OutKey): string =
    if key.isSpecial:
      case key.key
      of keyEnter: "KEY_RETURN"
      of keyBackspace: "KEY_BACKSPACE"
      of keyTab: "KEY_TAB"
      of keyEscape: "KEY_ESC"
      of keyArrowUp: "KEY_UP_ARROW"
      of keyArrowDown: "KEY_DOWN_ARROW"
      of keyArrowLeft: "KEY_LEFT_ARROW"
      of keyArrowRight: "KEY_RIGHT_ARROW"
      of keyShift: "KEY_LEFT_SHIFT"
      of keyCapsLock: "KEY_CAPS_LOCK"
      of keyControl: "KEY_LEFT_CTRL"
      of keyAlt: "KEY_LEFT_ALT"
      of keyAltGraph: "KEY_ALT_GR"
    else:
      "'" & $key.c & "'"

  const templ = staticRead("template.ino")
  templ % [
    "key_count", $keyCount[layout.handSetup],
    "key_pins", "{" & pins.mapIt(it.name).join(", ") & "}",
    "key_levels", "{" & pins.mapIt($it.connectedTo).join(", ") & "}",
    "basic_keys", "{" & collect(
      for i in 0 ..< keyCount[layout.handSetup]:
        if i in layout.basicKeys:
          layout.basicKeys[i].toArduinoKey
        else: "0"
    ).join(", ") & "}",
    "chord_mask", layout.basicKeys.keys.toSet.complement.toBinNum,
    "init_chords",
      layout.chords
      .mapIt("chords[" & it.inKeys.toBinNum & "] = " & it.outKey.toArduinoKey & ";")
      .join("\n  ")
  ]

proc drawDom*: VNode =
  if not self.isOpen:
    drawPage(@[]):
      buildHtml(tdiv(class = "main-menu")):
        button:
          text "new layout"
          proc onClick =
            self = LayoutEdit(isOpen: true)
        drawOpenFileButton("open layout") do(content: string):
          openLayout(content)
  
  else:
    var actions: seq[VNode]

    if self.view.stage == chordConfig:
      actions.add: buildHtml(button):
        text "Export Arduino"
        proc onClick =
          self.view = pinConfig
          if Some(@pins) ?= getCookie("pins"):
            self.view.pins = pins.fromJson(seq[Pin])
          self.view.pins.setLen keyCount[self.layout.handSetup]

    if self.view.stage in basicKeyConfig .. chordConfig:
      actions.add: buildHtml(tdiv):
        button(class = "icon new-file", title = "new"):
          proc onCLick = self = LayoutEdit(isOpen: true)

        drawOpenFileButton(
          buildHtml(button(class = "icon open-file")),
          proc(content: string) = openLayout(content)
        ) 

        if self.view.stage == chordConfig:
          button(class = "icon save", title = "save"):
            proc onClick = save self.layout
        else:
          button(
            class = "icon save disabled",
            title = "not all steps done"
          )

    drawPage(actions):
      case self.view.stage
      of handSetupSelect:
        buildHtml(tdiv(class = "main-menu")):
          for setup in HandSetup:
            capture(setup, buildHtml(button) do:
              text $setup & " hand" & (if setup == bothHands: "s" else: "")
              proc onClick =
                self.layout.handSetup = setup
                self.view = basicKeyConfig
            )

      of basicKeyConfig:
        buildHtml(tdiv(id = "basic-key-config")):
          tdiv(class = "info-box"):
            text "Select the keys that should function like a normal keyboard."
            br()
            text "Click on the key and press the key, it should be."

          drawHands(self.layout.handSetup, isSmall=false) do(id: InKeyId) -> VNode:
            if id in self.layout.basicKeys:
              var node = drawKey(self.layout.basicKeys[id]) do(key: OutKey):
                self.layout.basicKeys[id] = key
              (node.addEventHandler(onClick) do(_: Event, n: VNode):
                if n.dom == document.activeElement:
                  self.layout.basicKeys.del(id)
              )
              node
            else:
              drawKey do(key: OutKey):
                self.layout.basicKeys[id] = key
          
          button:
            text "next"
            proc onClick =
              self.view = chordConfig
              self.layout.chords.setLen 1
              self.view.justAddedChord = true

      of chordConfig:
        let dupInKeys = self.layout.chords.mapIt(it.inKeys).duplicates
        let dupOutKeys = self.layout.chords.mapIt(it.outKey).duplicates
        buildHtml(tdiv(id = "chord-config")):
          tdiv(id = "chords"):
            for i, chord in self.layout.chords:
              let errInKeys = card(chord.inKeys) == 0 or chord.inKeys in dupInKeys
              let errOutKey = chord.outKey.isUndefined or chord.outKey in dupOutKeys
              capture(i, buildHtml(tdiv(
                class = "chord".addClassIf(i < high(self.layout.chords), ""
                  .addClassIf(errInKeys, "error-in-keys")
                  .addClassIf(errOutKey, "error-out-key")
                )
              )) do:
                input(
                  class = "out-key",
                  `type` = "text",
                  value = $chord.outKey,
                  onKeyDown = registerKeyHandler(proc(key: OutKey) =
                    self.layout.chords[i].outKey = key
                  )
                )
                drawHands(self.layout.handSetup, isSmall=true) do(id: InKeyId) -> VNode:
                  if id in self.layout.basicKeys:
                    drawKey(self.layout.basicKeys[id])
                  else:
                    drawKey(pressed = id in chord.inKeys) do (e: Event, n: VNode):
                      self.layout.chords[i].inKeys[id] = id notin self.layout.chords[i].inKeys
                button(class = "close"):
                  proc onClick =
                    self.layout.chords.del(i)
              )
            button(class = "small"):
              text "+ add Chord"
              proc onClick =
                self.layout.chords &= Chord()
                self.view.justAddedChord = true
      
      of pinConfig:
        buildHtml(tdiv(id = "pin-config")):
          tdiv:
            tdiv(class = "row-labels"):
              tdiv: text "pin:"
              tdiv: text "connected to:"
            drawHands(self.layout.handSetup, isSmall=false) do(id: InKeyId) -> VNode:
              buildHtml(tdiv):
                drawKey()
                tdiv(class = "line")
                input(
                  `type` = "text",
                  value = self.view.pins[id].name,
                  tabindex = $(id+1),
                  class =
                    if self.view.pins[id].name in self.view.errorPinNames:
                      " error"
                    else: ""
                ):
                  proc onInput(_: Event, n: Vnode) =
                    self.view.pins[id].name = strip($n.value)
                    self.view.errorPinNames = @[]
                    setCookie("pins", self.view.pins.toJson)
                tdiv(class = "pull-resistor"):
                  for level in VoltageLevel:
                    if level == self.view.pins[id].connectedTo:
                      button(class = "small selected"): text $level
                    else:
                      capture(level, buildHtml(button(class = "small")) do:
                        text $level
                        proc onClick =
                          self.view.pins[id].connectedTo = level
                          setCookie("pins", self.view.pins.toJson)
                      )
          tdiv(class = "buttons"):
            button(class = "secondary"):
              text "cancel"
              proc onClick = self.view = chordConfig
            if len(self.view.errorPinNames) == 0:
              button:
                text "export"
                proc onClick =
                  self.view.errorPinNames = self.view.pins.mapIt(it.name).duplicates
                  if self.view.pins.anyIt(it.name == ""):
                    self.view.errorPinNames &= ""
                  if len(self.view.errorPinNames) == 0:
                    downloadFile("code.ino", "text/arduino", generateArduino(self.layout, self.view.pins))
                    self.view = chordConfig
            else:
              button(class = "disabled"):
                text "export"

proc postDrawDom* =
  if self.isOpen and self.view.stage == chordConfig and self.view.justAddedChord:
    self.view.justAddedChord = false
    focus:
      document
      .querySelectorAll("#chords > .chord")[^1]
      .getElementsByClass("out-key")[0]
      .InputElement

setRenderer drawDom, clientPostRenderCallback = postDrawDom

window.addEventListener("keydown") do(e: Event):
  let e = e.KeyboardEvent
  if self.isOpen and e.ctrlKey and e.key == "s":
    e.preventDefault()
    if self.view.stage == chordConfig:
      save self.layout