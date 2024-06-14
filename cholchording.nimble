# Package

version       = "0.1.0"
author        = "Joel Lienhard"
description   = "A chorded keyboard layout configurator and typing trainer"
license       = "MIT"
backend       = "js"
srcDir        = "src"
binDir        = "build"
bin           = @["app"]


# Dependencies

requires "nim >= 2.0.4"
requires "fusion"
requires "karax ~= 1.3.0"
requires "jsony ~= 1.1.0"