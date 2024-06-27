#
#    CholChording - A chorded keyboard layout configurator and typing trainer
#        (c) Copyright 2024 Joel Lienhard (choltreppe)
#
#    See the file "LICENSE.txt", included in this
#    distribution, for details about the copyright.
#

import std/[options, tables, strutils, sugar, dom]
import fusion/matching
include karax/prelude
import jsony
import ./utils, ./widgets


type
  SpecialKey* = enum
    keyEnter
    keyBackspace
    keyTab
    keyEscape
    keyArrowUp
    keyArrowDown
    keyArrowLeft
    keyArrowRight

    keyShift
    keyCapsLock
    keyControl
    keyAlt
    keyAltGraph

  OutKey* = object
    case isSpecial*: bool
    of false: c*: char
    of true: key*: SpecialKey

  InKeyId* = range[0..9]  # max 10 keys (both hands)

  Chord* = object
    inKeys*: set[InKeyId]
    outKey*: OutKey

  HandSetup* = enum leftHand="left", rightHand="right", bothHands="both"

  Layout* = object
    handSetup*: HandSetup
    basicKeys*: Table[InKeyId, OutKey]
    chords*: seq[Chord]

const keyCount*: array[HandSetup, int] = [5, 5, 10]

func `$`*(key: OutKey): string =
  if key.isSpecial:
    case key.key
    of keyEnter: "↵"
    of keyBackspace: "←"
    of keyTab: "⭾"
    of keyEscape: "Esc"
    of keyArrowUp: "🞁"
    of keyArrowDown: "🞃"
    of keyArrowLeft: "🞀"
    of keyArrowRight: "🞂"
    of keyShift: "⇧"
    of keyCapsLock: "⇪"
    of keyControl: "Ctrl"
    of keyAlt: "Alt"
    of keyAltGraph: "AltGr"
  elif key.c == ' ': "␣"
  elif key.c == char(0): ""
  else: $key.c

func `==`*(a, b: OutKey): bool {.inline.} =
  if a.isSpecial != b.isSpecial: false
  elif a.isSpecial: a.key == b.key
  else: a.c == b.c

func isUndefined*(key: OutKey): bool {.inline.} =
  not key.isSpecial and key.c == char(0)

proc parseLayout*(content: string): Option[Layout] =
  try: return some(content.fromJson(Layout))
  except JsonError as e:
    setErrorPopup(
      title = "Failed to open layout",
      msg = e.msg
    )

proc save*(layout: Layout) {.inline.} =
  downloadFile("layout.json", "text/json", layout.toJson)


proc registerKeyHandler*(cb: proc(key: OutKey)): auto =
  return proc(e: Event, n: VNode) =
    e.preventDefault()
    let key = e.KeyboardEvent.key
    cb:
      if len(key) == 1:
        OutKey(isSpecial: false, c: key[0])
      else:
        OutKey(isSpecial: true, key: parseEnum[SpecialKey]("key" & $key))
    blur n.dom.InputElement


proc drawKey*(pressed = false, onClick: EventHandler = nil): VNode =
  result = buildHtml(tdiv(class = "key " & (if pressed: "pressed" else: "disabled"))):
    tdiv()
  if onClick != nil:
    result.addEventHandler(EventKind.onClick, onClick)

proc drawKey*(key: string): VNode =
  buildHtml(tdiv(class = "key labeled")):
    tdiv: text key

proc drawKey*(key: OutKey): VNode =
  drawKey($key)

proc drawKeyWithCb(key, class: string, cb: proc(key: OutKey)): VNode {.inline.} =
  buildHtml(tdiv(
    class = "key " & class,
    tabindex = "0",
    onKeyDown = registerKeyHandler(cb)
  )):
    tdiv: text key

proc drawKey*(cb: proc(key: OutKey)): VNode =
  drawKeyWithCb("", "disabled", cb)

proc drawKey*(key: OutKey, cb: proc(key: OutKey)): VNode =
  drawKeyWithCb($key, "labeled", cb)

proc drawHands*(
  handSetup: HandSetup,
  isSmall: bool,
  drawKey: proc(id: InKeyId): VNode
): VNode =
  proc drawHand(hand: HandSetup, offset: InKeyId): VNode =
    buildHtml(tdiv(class = kstring ("hand " & $hand).addClassIf(isSmall, "small"))):
      for id in offset .. offset+4:
        drawKey(id)
  case handSetup
  of bothHands:
    buildHtml(tdiv(class = "hands")):
      drawHand(leftHand, 0)
      drawHand(rightHand, 5)
  else:
    drawHand(handSetup, 0)