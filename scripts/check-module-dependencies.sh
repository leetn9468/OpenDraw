#!/bin/sh
set -eu

fail=0
reject_import() {
  directory="$1"
  pattern="$2"
  if grep -Ern "^import (${pattern})$" "$directory"; then
    echo "Forbidden dependency in $directory" >&2
    fail=1
  fi
}

reject_import Sources/EditorCore 'AppKit|CoreGraphics|DocumentModel|CanvasRender'
reject_import Sources/Geometry 'AppKit|CoreGraphics|DocumentModel|CanvasRender'
reject_import Sources/DocumentModel 'AppKit|CoreGraphics|CanvasRender|MacPlatform'
reject_import Sources/EditorCommands 'AppKit|CoreGraphics|CanvasRender|MacPlatform'
exit "$fail"
