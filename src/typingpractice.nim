#
#    CholChording - A chorded keyboard layout configurator and typing trainer
#        (c) Copyright 2024 Joel Lienhard (choltreppe)
#
#    See the file "LICENSE.txt", included in this
#    distribution, for details about the copyright.
#

import std/[options, tables, setutils, sequtils, strutils, unicode, sugar, dom, enumerate]
import fusion/matching
include karax/prelude
import jsony
import ./utils, ./widgets, ./layouts


type
  KeyLookup = Table[string, set[InKeyId]]

  PracticeText = object
    text: string
    pos: int
    fails: seq[int]

  Config = object
    handSetup: HandSetup
    basicKeys: Table[InKeyId, OutKey]
    keyLookup: KeyLookup

  TypingPracticeViewKind = enum practiceSelect, practiceText
  TypingPracticeView = object
    case kind: TypingPracticeViewKind
    of practiceSelect: discard
    of practiceText: ptext: PracticeText

  TypingPractice* = object
    case isOpen: bool
    of true:
      config: Config
      view: TypingPracticeView
    else: discard

const symbolOrder = "eariotnslcudpmhgbfywkvxzjq"

var self: TypingPractice


func getKeyLookup(basicKeys: Table[InKeyId, OutKey], chords: seq[Chord]): KeyLookup =
  for inKey, outKey in basicKeys:
    result[$outKey] = {inKey}
  for chord in chords:
    result[$chord.outKey] = chord.inKeys

func getConfig(layout: Layout): Config =
  Config(
    handSetup: layout.handSetup,
    basicKeys: layout.basicKeys,
    keyLookup: getKeyLookup(layout.basicKeys, layout.chords)
  )

proc openLayout(json: string) =
  if Some(@layout) ?= parseLayout(json):
    self = TypingPractice(
      isOpen: true,
      config: getConfig(layout),
      view: TypingPracticeView(kind: practiceSelect)
      #PracticeText(text: "ass,ea eee")
    )


proc input(ptext: var PracticeText, symbol: string) =
  if symbol != ptext.text.runeStrAtPos(ptext.pos):
    ptext.fails &= ptext.pos
  inc ptext.pos


proc draw(ptext: PracticeText, config: Config): VNode =
  buildHtml(tdiv(class = "practice-text")):
    tdiv(class = "text"):
      for i, symbol in enumerate(ptext.text.utf8):
        tdiv(class =
          "symbol"
          .addClassIf(i == ptext.pos, "cursor")
          .addClassIf(i in ptext.fails, "failed")
        ):
          text symbol
    
    let keys = config.keyLookup[ptext.text.runeStrAtPos(ptext.pos)]
    drawHands(config.handSetup, isSmall=false) do(id: InKeyId) -> VNode:
      if id in keys:
        drawKey(pressed=true)
      elif id in config.basicKeys:
        drawKey(config.basicKeys[id])
      else:
        drawKey()

proc drawDom*: VNode =
  drawPage(@[]):
    if not self.isOpen:
      buildHtml(tdiv(class = "main-menu")):
        drawOpenFileButton("open layout") do(content: string):
          openLayout(content)

    else:
      text "todo"
      #draw(self.ptext, self.config)

setRenderer drawDom

window.addEventListener("keydown") do(e: Event):
  let e = e.KeyboardEvent
  if self.isOpen and self.view.kind == practiceText:
    self.view.ptext.input($e.key)
    redraw()