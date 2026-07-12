# Critical technical spike report

Environment: Apple Silicon `arm64`, macOS 15.7.5, Swift 6.1.2 command-line tools.
Commands and raw pass/fail results are reproducible from the repository; timings are
not release benchmarks until baseline hardware is nominated.

| Question | Evidence | Result / interpretation |
|---|---|---|
| Can cubic paths render at multiple zooms? | `bezierRendersAtMultipleScales` at 0.25×, 1×, 2×, 8×; shell canvas | Pass; Core Graphics boundary is viable |
| Can anchors/curve segments be hit-tested? | Geometry hit tests with zoom-converted tolerance | Pass for foundation sampling algorithm; analytic/adaptive accuracy is future work |
| Are high-DPI coordinates expressible? | `MacPlatform.BackingScale`, scale rendering | API boundary proven; physical Retina/non-Retina visual check pending |
| Can representative Unicode shape? | Latin, Arabic, Devanagari, CJK, combining mark, emoji Core Text suite | Pass for nonempty shaping/metrics; detailed bidi/IME visual fixtures pending |
| Can a large synthetic document render without blocking UI? | 1,000-object render benchmark | Render completes under generous 5 s guard; async scheduling and p95 16.7 ms target not yet proven |
| Does renderer support clip/AA/gradient/alpha? | Core Graphics compositing primitive test | Pass at framework boundary; gradients/transparency remain post-MVP model features |
| Is Swift geometry initially adequate? | 20,000 curve hit tests with 32 subdivisions under 5 s guard | Pass as architecture gate; collect release-mode baseline before optimization/C++ discussion |
| Can AppKit represent required events/scaling? | Native `NSView` shell and backing-scale adapter compile/run boundary | Mouse/key/modifier APIs available; trackpad, pressure, VoiceOver and physical scaling manual checks pending |

## External validation checklist

- Run debug/release build and tests on macOS 13 Apple Silicon hardware.
- Record release benchmark medians/p95 on nominated 8 GB baseline machines.
- Exercise mouse, trackpad scroll/magnify, keyboard modifiers, IME, and window moves
  between 1×/2× displays; pressure input is only required if later product scope says so.
- Complete VoiceOver keyboard journey and capture defects without proprietary assets.

No C++ need is demonstrated. Current timing guards detect catastrophic regressions,
not compliance with the Phase 1 release performance budget.
