# Phase 4 selected expansion review

Status: **Selected subset implemented and verified**  
Baseline date: 2026-07-12

The plan explicitly says to implement only an approved subset. Selection follows
the Phase 1 capability matrix and avoids treating each advanced area as a small task.

## Implemented subset

| Capability | Acceptance evidence |
|---|---|
| Alignment | Undoable two-object alignment test |
| Swatches and reusable color resources | Resource invariant/native round-trip tests |
| Linear/radial gradients, opacity, basic blend modes | Core Graphics expanded-render test |
| Dash style model/rendering | Native round trip and renderer coverage |
| Unicode point text and transforms | Core Text multilingual and expanded-render tests |
| Embedded/linked raster resources | Decode byte/pixel/path limits and placeholder rendering |
| Safe SVG rectangle import | Isolated parse, active-content block and malformed-input tests |
| SVG text/path export and loss reports | Determinism, escaping and feature-loss tests |
| Native v2 → v3 migration | Project-created migration fixture test |
| Spatial hit-test index | Near/far candidate tests |
| Cached panning | 1,000-object cache/invalidation frame-budget test |
| Parser robustness corpus | 128 deterministic malformed native inputs; 29-test combined suite |

## Explicitly deferred

Compound/Boolean/offset paths, clipping masks, transparency groups, distribution,
area/paragraph text, text-on-path, embedded-image SVG export, PDF, full SVG path
import, color management, process-isolated extensions and an external SDK. These
need separate designs and acceptance tests; unsupported adapters warn or reject.

## Exit review

| Criterion | Result |
|---|---|
| Selected capabilities have acceptance tests | Pass |
| Public-format failures are safe and diagnosable | Pass for implemented SVG subset |
| Native migration preserves older project data | Pass for v2 → v3 |
| Large representative interaction meets budget | Pass for cached pan; uncached rebuild documented separately |
| Unsupported cases are documented, not silently corrupted | Pass through compatibility/loss matrix |
| Dependency direction remains valid | Pass |

Manual VoiceOver, multi-display and memory-profiler gates from Phase 2 remain external
release gates, not silently converted into passes. Intel is out of scope per ADR-011.
