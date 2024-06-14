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


type
  OutKey* = object
    keyCode*: byte
    charCode*: string

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
  case key.charCode
  of " ": "␣"
  of "Shift": "⇧"
  of "CapsLock": "⇪"
  of "Enter": "↵"
  of "Backspace": "←"
  of "Tab": "⭾"
  of "Control": "Ctrl"
  of "Escape": "Esc"
  of "AltGraph": "AltGr"
  of "ArrowUp": "🞁"
  of "ArrowDown": "🞃"
  of "ArrowLeft": "🞀"
  of "ArrowRight": "🞂"
  else:
    if len(key.charCode) == 1:
      key.charCode.toUpperASCII
    else: key.charCode


proc registerKeyHandler*(cb: proc(key: OutKey)): auto =
  return proc(e: Event, n: VNode) =
    e.preventDefault()
    let e = e.KeyboardEvent
    cb(OutKey(
      keyCode: byte e.keyCode,
      charCode: $e.key
    ))
    blur n.dom.InputElement


proc drawKey*(pressed = false, onClick: EventHandler = nil): VNode =
  result = buildHtml(tdiv(class = "key " & (if pressed: "pressed" else: "disabled"))):
    tdiv()
  if onClick != nil:
    result.addEventHandler(EventKind.onClick, onClick)

proc drawKey*(key: OutKey): VNode =
  buildHtml(tdiv(class = "key labeled")):
    tdiv: text $key

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
    buildHtml(tdiv(class = kstring "hand " & $hand & (if isSmall: " small" else: ""))):
      for id in offset .. offset+4:
        drawKey(id)
  case handSetup
  of bothHands:
    buildHtml(tdiv(class = "hands")):
      drawHand(leftHand, 0)
      drawHand(rightHand, 5)
  else:
    drawHand(handSetup, 0)