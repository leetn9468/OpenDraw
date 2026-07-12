# Public-format compatibility and loss matrix

| Construct | SVG import | SVG export | Behavior when unsupported |
|---|---|---|---|
| Root width/height | Supported, numeric/px | Supported | Invalid dimensions use controlled error/default only where documented |
| Rectangle | Supported | Exported as cubic path | Invalid rectangle skipped with warning |
| Cubic path | Deferred | Supported (`M/C/Z`) | Import warning; no partial path |
| Solid sRGB fill/stroke | Hex on rectangles | Supported | Unknown paint becomes none/warning |
| Stroke width | Supported on rectangles | Supported | Invalid value falls back safely |
| Point text | Deferred import | Supported | Import warning |
| Gradients | Deferred import/export | Fallback solid plus loss warning | `SVG-GRADIENT-DEFERRED` |
| Raster images | Deferred import/export | Omitted with loss warning | `SVG-IMAGE-DEFERRED` |
| Groups | Container accepted | Layer groups emitted | Unknown group attributes ignored |
| Scripts/foreign objects | Blocked | Never emitted | `SVG-UNSAFE-IGNORED` |
| External entities/network | Blocked | Never emitted | No external fetch |
| Unknown elements | Not imported | Not emitted | Structured `SVG-UNSUPPORTED-*` warning |

SVG input is capped at 10 MiB and parsed into an intermediate path collection before
a validated document is constructed. Export warnings are returned with the data so
the UI can require acknowledgment; loss is never represented as a successful
lossless round trip.
