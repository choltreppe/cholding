#
#    CholChording - A chorded keyboard layout configurator and typing trainer
#        (c) Copyright 2024 Joel Lienhard (choltreppe)
#
#    See the file "LICENSE.txt", included in this
#    distribution, for details about the copyright.
#

import std/[options, tables, strformat, strutils, sequtils, sugar, dom, algorithm]
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

  ThumbKeysCount* = range[1..3]

  InKeyId* = range[0 .. 7+2*high(ThumbKeysCount)]  # max keys for both hands

  Chord* = object
    inKeys*: set[InKeyId]
    outKey*: OutKey

  HandSetupKind* = enum leftHand="left", rightHand="right", bothHands="both"
  HandSetup* = object
    kind*: HandSetupKind
    thumbKeys*: ThumbKeysCount = 1

  Layout* = object
    handSetup*: HandSetup
    basicKeys*: Table[InKeyId, OutKey]
    chords*: seq[Chord]

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

func keyCount*(setup: HandSetup): int =
  result = 4 + setup.thumbKeys
  if setup.kind == bothHands:
    result *= 2

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
  result = buildHtml(tdiv(
    class = "key " & (
      if pressed: "pressed"
      else: "disabled"
    )
    .addClassIf(onClick == nil, "noclick")
  )):
    tdiv()
  if onClick != nil:
    result.addEventHandler(EventKind.onClick, onClick)

proc drawKey*(key: string): VNode =
  buildHtml(tdiv(class = "key labeled noclick")):
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
  setup: HandSetup,
  isSmall: bool,
  drawKey: proc(id: InKeyId): VNode
): VNode =
  type FingerKind = enum thumb, smallfinger, other=""
  let leftHandFingers =
    smallfinger &
    repeat(other, 3) &
    repeat(thumb, setup.thumbKeys)

  proc drawHand(hand: HandSetupKind, offset = 0): VNode =
    buildHtml(tdiv(
      class = ("hand " & $hand).addClassIf(isSmall, "small").kstring
    )):
      for i, finger in (
        if hand == leftHand: leftHandFingers
        else: reversed(leftHandFingers)
      ):
        let n = drawKey(InKeyId(i + offset))
        n.class = 
          if n.class == nil: $finger
          else: &"{n.class} {finger}"
        n

  case setup.kind
  of bothHands:
    buildHtml(tdiv(class = "hands")):
      drawHand(leftHand)
      drawHand(rightHand, 4 + setup.thumbKeys)
  else:
    drawHand(setup.kind)