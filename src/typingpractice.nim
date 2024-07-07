#
#    CholChording - A chorded keyboard layout configurator and typing trainer
#        (c) Copyright 2024 Joel Lienhard (choltreppe)
#
#    See the file "LICENSE.txt", included in this
#    distribution, for details about the copyright.
#

import std/[options, tables, strutils, strformat, setutils, sequtils, unicode, sugar, dom, enumerate, random]
import fusion/matching
include karax/prelude
import jsony
import ./utils, ./widgets, ./layouts


const
  letterOrder = "eariotnslcudpmhgbfywkvxzjq".utf8.toSeq
  words = static(staticRead("words.txt").split('\n'))
  newSymbolsPerLesson = 2
  wordsPerText = 16
  lettersPerWord = 2 .. 7
  specialLessonSymbols = 128


type
  KeyLookup = Table[string, set[InKeyId]]

  LessonKind = enum
    practiceJust="just",
    practiceUpto="upto",
    practiceSpecial

  LessonConfig = object
    symbols: seq[string]
    case kind: LessonKind
    of practiceUpto: newSymbols: seq[string]
    of practiceSpecial: title: string
    else: discard

  TypingPracticeViewKind = enum lessonSelect, lesson, lessonStats
  TypingPracticeView = object
    case kind: TypingPracticeViewKind
    of lessonSelect: discard
    of lesson:
      id: int
      text: string
      pos: int
      fails: seq[int]
    of lessonStats:
      lessonId: int
      percent: int

  TypingPractice* = object
    case isOpen: bool
    of true:
      handSetup: HandSetup
      basicKeys: Table[InKeyId, OutKey]
      keyLookup: KeyLookup
      lessons: seq[LessonConfig]
      view: TypingPracticeView
    else: discard

var self: TypingPractice


func getKeyLookup(basicKeys: Table[InKeyId, OutKey], chords: seq[Chord]): KeyLookup =
  for inKey, outKey in basicKeys:
    if not outKey.isSpecial:
      result[$outKey.c] = {inKey}
  for chord in chords:
    if not chord.outKey.isSpecial:
      result[$chord.outKey.c] = chord.inKeys

func getLessonConfigs(keyLookup: KeyLookup): seq[LessonConfig] =
  let oneKeySymbols = collect:
    for s, k in keyLookup:
      if len(k) == 1: s
  let letters =
    letterOrder.filterIt(it in oneKeySymbols) &
    letterOrder.filterIt(it in keyLookup and it notin oneKeySymbols)
  var i = 0
  while i < len(letters):
    let upto = min(i + newSymbolsPerLesson, len(letters))
    result &= LessonConfig(
      kind: practiceJust,
      symbols: letters[i ..< upto]
    )
    if i > 0:
      result &= LessonConfig(
        kind: practiceUpto,
        symbols: letters[0 ..< upto],
        newSymbols: letters[i ..< upto]
      )
    i += newSymbolsPerLesson

  const numbers = "1234567890".map do(it: char) -> string: $it
  let coveredNumbers = numbers.filterIt(it in keyLookup)
  if len(coveredNumbers) > 0:
    result &= LessonConfig(
      kind: practiceSpecial,
      title: "numbers",
      symbols: coveredNumbers
    )

  let otherSymbols = collect:
    for symbol in keyLookup.keys:
      if symbol notin numbers & letters & " ":
        symbol
  if len(otherSymbols) > 0:
    result &= LessonConfig(
      kind: practiceSpecial,
      title: "special symbols",
      symbols: otherSymbols
    )

proc openLayout =
  uploadFile do(content: string):
    if Some(@layout) ?= parseLayout(content):
      self = TypingPractice(
        isOpen: true,
        handSetup: layout.handSetup,
        basicKeys: layout.basicKeys,
        keyLookup: getKeyLookup(layout.basicKeys, layout.chords),
        view: TypingPracticeView(kind: lessonSelect)
      )
      self.lessons = getLessonConfigs(self.keyLookup)

proc gotoLesson(id: int) =
  window.location.hash = &"lesson{id}"

proc loadLesson(id: int) =
  let config = self.lessons[id]
  self.view = TypingPracticeView(kind: lesson, id: id)
  if config.kind == practiceSpecial:
    for _ in 0 ..< specialLessonSymbols:
      self.view.text &= sample(config.symbols)
  else:
    let words = words.filterIt(it.allIt($it in config.symbols))
    let realWordProb =
      if len(words) == 0: 0.0
      elif len(words) < 10: 0.06
      elif len(words) < 40: 0.3
      else: 0.6
    debugEcho realWordProb
    for i in 0 ..< wordsPerText:
      if i > 0:
        if "," in self.keyLookup and randProb(0.16):
          self.view.text &= ','
        self.view.text &= ' '
      if randProb(realWordProb):
        debugEcho "word"
        self.view.text &= sample(words)
      else:
        for _ in 0 ..< rand(lettersPerWord):
          self.view.text &= sample(config.symbols)
    if "." in self.keyLookup:
      self.view.text &= '.'

proc drawDom*: VNode =
  if not self.isOpen:
    drawPage:
      tdiv(id = "typing-practice-main-menu"):
        button:
          text "open layout"
          proc onClick = openLayout()
        tdiv(class = "info-box"):
          text "if you haven't created a layout with the layout editor yet,"
          br()
          text "you should do that first"
          a(class = "button", href = "layouteditor.html", target = "_blank"):
            text "create layout"

  else:
    drawPage do:
      if self.view.kind == lessonSelect:
        drawHomeButton()
      else:
        tdiv(id = "open-lesson-select"):
          proc onClick = window.location.hash = ""

      tdiv(id = "actions"):
        tdiv:
          button(class = "icon open-file"):
            proc onClick = openLayout()
    
    do:
      case self.view.kind
      of lessonSelect:
        buildHtml(tdiv(id = "typing-practice-select")):
          for i, config in self.lessons:
            capture(i, buildHtml(tdiv) do:
              proc onClick = gotoLesson(i)
              tdiv(class = "title"):
                text if config.kind == practiceSpecial: config.title
                     else: $config.kind
              if config.kind != practiceSpecial:
                tdiv(class = "hand"):
                  for symbol in (if config.kind == practiceUpto: config.newSymbols else: config.symbols):
                    drawKey(symbol)
            )

      of lesson:
        buildHtml(tdiv(class = "practice-text")):
          tdiv(class = "text"):
            var word = newVNode(tdiv)
            for i, symbol in enumerate(self.view.text.utf8):
              (word.add(buildHtml(pre(class =
                "symbol"
                .addClassIf(i == self.view.pos, "cursor")
                .addClassIf(i in self.view.fails, "failed")
              )) do:
                text symbol
              ))
              if symbol == " ":
                word
                (word = newVNode(tdiv))
            word
          
          let keys = self.keyLookup[self.view.text.runeStrAtPos(self.view.pos)]
          drawHands(self.handSetup, isSmall=false) do(id: InKeyId) -> VNode:
            if id in keys:
              drawKey(pressed=true)
            elif id in self.basicKeys:
              drawKey(self.basicKeys[id])
            else:
              drawKey()

      of lessonStats:
        buildHtml(tdiv(id = "lesson-stats")):
          text &"{self.view.percent}% correct"
          tdiv(class = "buttons"):
            button(class = "secondary"):
              text "redo"
              proc onClick = loadLesson(self.view.lessonId)
            button(class = "secondary"):
              text "menu"
              proc onClick = window.location.hash = ""
            if self.view.lessonId < high(self.lessons):
              button:
                text "next"
                proc onClick =
                  let id = self.view.lessonId
                  gotoLesson(id+1)

setRenderer drawDom

setRouter do(route: string):
  if route == "":
    if self.isOpen:
      self.view = TypingPracticeView(kind: lessonSelect)
  elif not self.isOpen:
    window.location.hash = ""
  elif route.startsWith("lesson"):
    loadLesson(parseInt(route[6..^1]))

window.addEventListener("keydown") do(e: Event):
  let e = e.KeyboardEvent
  if self.isOpen:
    case self.view.kind
    of lesson:
      if $e.key != self.view.text.runeStrAtPos(self.view.pos):
        self.view.fails &= self.view.pos
      inc self.view.pos
      let l = runeLen(self.view.text)
      if self.view.pos >= l:
        self.view = TypingPracticeView(
          kind: lessonStats,
          lessonId: self.view.id,
          percent: (l-len(self.view.fails))*100 div l
        )
      redraw()
    
    of lessonStats:
      if $e.key == " " or e.keyCode == 13:
        [@buttons] := document.getElementsByClass("buttons")
        click buttons.childNodes[^1].Element

    else: discard